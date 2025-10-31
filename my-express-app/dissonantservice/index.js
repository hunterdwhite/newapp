const express = require('express');
const app = express();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const bodyParser = require('body-parser');
const serverless = require('serverless-http');
const fetch = require('node-fetch');
const nodemailer = require('nodemailer');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
let firebaseApp;
try {
  if (admin.apps.length === 0) {
    // Try to initialize Firebase with different credential methods
    let credential;
    
    if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
      // Use service account key if provided
      console.log('Using Firebase service account key from environment');
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
      credential = admin.credential.cert(serviceAccount);
    } else {
      // Fallback to application default (works in Google Cloud, may fail in AWS)
      console.log('Using Firebase application default credentials');
      credential = admin.credential.applicationDefault();
    }
    
    firebaseApp = admin.initializeApp({
      credential: credential,
      projectId: process.env.FIREBASE_PROJECT_ID || 'dissonantapp2',
    });
    console.log('✅ Firebase initialized successfully');
  } else {
    firebaseApp = admin.app();
    console.log('✅ Using existing Firebase app');
  }
} catch (error) {
  console.error('❌ Firebase initialization error:', error);
  console.error('This will prevent fallback order record creation, but shipping labels will still work');
  firebaseApp = null;
}

let db;
try {
  db = admin.firestore();
  console.log('✅ Firestore database initialized');
} catch (error) {
  console.error('❌ Firestore initialization failed:', error);
  db = null;
}

app.use(bodyParser.json());

// Configure email transporter with multiple fallback options
let transporter;

// Prioritize SendGrid first (no verification restrictions)
if (process.env.SENDGRID_API_KEY) {
  console.log('Using SendGrid for email transport (primary)');
  const sgMail = require('@sendgrid/mail');
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
  
  // Create a custom transporter for SendGrid
  transporter = {
    sendMail: async (mailOptions) => {
      const msg = {
        to: mailOptions.to,
        from: mailOptions.from,
        subject: mailOptions.subject,
        text: mailOptions.text,
        html: mailOptions.html,
      };
      return await sgMail.send(msg);
    },
    verify: async () => {
      return true; // SendGrid doesn't need verification
    }
  };
  console.log('✅ SendGrid transporter configured');
} else {
  // Fallback to Gmail with better configuration
  console.log('Using Gmail for email transport (last resort)');
  transporter = nodemailer.createTransport({
    service: 'gmail',
    host: 'smtp.gmail.com',
    port: 587,
    secure: false, // true for 465, false for other ports
    auth: {
      user: process.env.EMAIL_USER || 'your-email@gmail.com',
      pass: process.env.EMAIL_PASSWORD || 'your-app-password',
    },
    tls: {
      rejectUnauthorized: false
    },
    debug: true, // Enable debug output
    logger: true // Log to console
  });
}

app.post('/create-payment-intent', async (req, res) => {
  const { amount } = req.body;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: 'usd',
    });

    res.send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    res.status(500).send(error.message);
  }
});

// New endpoint: Shippo address validation
app.post('/validate-address', async (req, res) => {
  try {
    const { name, street1, street2, city, state, zip, country = 'US' } = req.body || {};
    if (!street1 || !city || !state || !zip) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const shippoResp = await fetch('https://api.goshippo.com/addresses/?validate=true', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        ...(name ? { name } : {}),
        street1,
        ...(street2 ? { street2 } : {}),
        city,
        state,
        zip,
        country,
        validate: true,
      }),
    });

    const data = await shippoResp.json();
    if (!shippoResp.ok) {
      return res.status(shippoResp.status).json({ error: 'Shippo error', details: data?.detail || data });
    }

    const isValid = data?.validation_results?.is_valid === true;
    if (!isValid) return res.json({ isValid: false });

    const zipRaw = String(data.zip || '');
    const [zip5, zip4] = zipRaw.split('-');

    return res.json({
      isValid: true,
      address: {
        street: [data.street1, data.street2].filter(Boolean).join(' ').trim(),
        city: data.city,
        state: data.state,
        zip5,
        zip4: zip4 || null,
      },
    });

  } catch (err) {
    console.error('Shippo validate-address error', err);
    return res.status(500).json({ error: 'Internal error' });
  }
});

// NEW: Calculate shipping rates using GoShippo API
app.post('/calculate-shipping', async (req, res) => {
  try {
    const { address_from, address_to, parcel } = req.body || {};
    
    if (!address_to || !parcel) {
      return res.status(400).json({ error: 'Missing required address_to or parcel info' });
    }

    console.log('Calculating shipping rates...');
    console.log('From:', address_from);
    console.log('To:', address_to);
    console.log('Parcel:', parcel);

    // Use provided from address or default to your warehouse
    const fromAddress = address_from || {
      name: 'Dissonant Music',
      street1: '789 9th Ave',
      city: 'New York',
      state: 'NY',
      zip: '10019',
      country: 'US',
    };

    // Create shipment to get rates
    const shipmentPayload = {
      address_to: address_to,
      address_from: fromAddress,
      parcels: [parcel],
      async: false,
    };
    
    console.log('Creating shipment for rate calculation...');
    const shipmentResponse = await fetch('https://api.goshippo.com/shipments/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify(shipmentPayload),
    });

    if (!shipmentResponse.ok) {
      const errorData = await shipmentResponse.json();
      console.error('Shipment creation failed:', errorData);
      return res.status(shipmentResponse.status).json({ 
        error: 'Failed to create shipment for rate calculation',
        details: errorData 
      });
    }

    const shipmentData = await shipmentResponse.json();
    console.log('Shipment created:', shipmentData.object_id);

    // Get rates for the shipment
    const ratesResponse = await fetch(`https://api.goshippo.com/shipments/${shipmentData.object_id}/rates/`, {
      headers: {
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
    });

    if (!ratesResponse.ok) {
      const errorData = await ratesResponse.json();
      console.error('Failed to get rates:', errorData);
      return res.status(ratesResponse.status).json({ 
        error: 'Failed to get shipping rates',
        details: errorData 
      });
    }

    const ratesData = await ratesResponse.json();
    console.log('Available rates:', ratesData.results.map(r => `${r.servicelevel.name} (${r.provider}) - $${r.amount}`));
    
    // Filter for USPS Ground Advantage only
    const groundAdvantageRate = ratesData.results.find(rate => 
      rate.provider === 'USPS' && 
      rate.servicelevel.name === 'Ground Advantage' &&
      rate.amount && 
      parseFloat(rate.amount) > 0
    );

    if (!groundAdvantageRate) {
      console.log('❌ No USPS Ground Advantage rate found, checking for alternatives...');
      
      // Fallback to other USPS services if Ground Advantage not available
      const fallbackRate = ratesData.results.find(rate => 
        rate.provider === 'USPS' && 
        (rate.servicelevel.name === 'First Class' || 
         rate.servicelevel.name === 'Priority Mail') &&
        rate.amount && 
        parseFloat(rate.amount) > 0
      );
      
      if (fallbackRate) {
        console.log(`⚠️ Using fallback USPS service: ${fallbackRate.servicelevel.name} - $${fallbackRate.amount}`);
        const formattedRate = {
          serviceName: fallbackRate.servicelevel.name,
          amount: parseFloat(fallbackRate.amount),
          estimatedDays: fallbackRate.estimated_days || 5,
          carrier: fallbackRate.provider,
          serviceLevel: fallbackRate.servicelevel.token,
          rateId: fallbackRate.object_id
        };
        
        return res.json({
          success: true,
          rates: [formattedRate],
          shipment_id: shipmentData.object_id,
          note: 'Using fallback USPS service'
        });
      }
      
      return res.status(400).json({ 
        error: 'No USPS Ground Advantage rate available',
        available_rates: ratesData.results.map(r => `${r.servicelevel.name} (${r.provider}) - $${r.amount}`)
      });
    }

    const formattedRate = {
      serviceName: groundAdvantageRate.servicelevel.name,
      amount: parseFloat(groundAdvantageRate.amount),
      estimatedDays: groundAdvantageRate.estimated_days || 5,
      carrier: groundAdvantageRate.provider,
      serviceLevel: groundAdvantageRate.servicelevel.token,
      rateId: groundAdvantageRate.object_id
    };

    console.log(`✅ Using USPS Ground Advantage: $${formattedRate.amount}`);

    return res.json({
      success: true,
      rates: [formattedRate],
      shipment_id: shipmentData.object_id
    });

  } catch (err) {
    console.error('Shipping calculation error:', err);
    return res.status(500).json({ 
      error: 'Internal error calculating shipping rates',
      details: err.message 
    });
  }
});

// PayPal SDK setup
const { Client, Environment, OrdersController } = require('@paypal/paypal-server-sdk');

// PayPal client setup
function getPayPalClient() {
  const clientId = process.env.PAYPAL_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
  const mode = process.env.PAYPAL_MODE || 'sandbox';
  
  const environment = mode === 'live' ? Environment.Production : Environment.Sandbox;
  
  return new Client({
    clientCredentialsAuthCredentials: {
      oAuthClientId: clientId,
      oAuthClientSecret: clientSecret,
    },
    environment: environment,
  });
}

// Create PayPal order endpoint
app.post('/create-paypal-payment', async (req, res) => {
  try {
    const { amount, currency = 'USD', return_url, cancel_url } = req.body || {};
    
    if (!amount) {
      return res.status(400).json({ error: 'Missing amount' });
    }

    if (!process.env.PAYPAL_CLIENT_ID || !process.env.PAYPAL_CLIENT_SECRET) {
      return res.status(500).json({ error: 'PayPal credentials not configured' });
    }

    const client = getPayPalClient();
    const ordersController = new OrdersController(client);
    
    // Create PayPal order request body
    const orderRequest = {
      intent: 'CAPTURE',
      purchaseUnits: [{
        amount: {
          currencyCode: currency,
          value: amount.toFixed(2)
        },
        description: 'Dissonant Music Curation Order'
      }],
      applicationContext: {
        returnUrl: return_url || 'https://dissonanthq.com/payment/success',
        cancelUrl: cancel_url || 'https://dissonanthq.com/payment/cancel',
        brandName: 'Dissonant',
        landingPage: 'BILLING',
        userAction: 'PAY_NOW'
      }
    };

    // Create the order
    const { result, statusCode } = await ordersController.createOrder({
      body: orderRequest,
      prefer: 'return=representation'
    });

    if (statusCode !== 201) {
      throw new Error(`PayPal order creation failed with status: ${statusCode}`);
    }
    
    // Find approval URL
    const approvalUrl = result.links?.find(link => link.rel === 'approve')?.href;
    
    console.log(`PayPal order created: ${result.id} for $${amount} ${currency}`);
    
    return res.json({
      order_id: result.id,
      approval_url: approvalUrl,
      amount: parseFloat(amount),
      currency,
      status: result.status
    });

  } catch (err) {
    console.error('PayPal payment error:', err);
    return res.status(500).json({ 
      error: 'Internal error creating PayPal payment',
      details: err.message 
    });
  }
});

// Capture PayPal payment endpoint
app.post('/capture-paypal-payment', async (req, res) => {
  try {
    const { order_id } = req.body || {};
    
    if (!order_id) {
      return res.status(400).json({ error: 'Missing order_id' });
    }

    const client = getPayPalClient();
    const ordersController = new OrdersController(client);

    // Capture the order
    const { result, statusCode } = await ordersController.captureOrder({
      id: order_id,
      body: {},
      prefer: 'return=representation'
    });

    if (statusCode !== 201) {
      throw new Error(`PayPal capture failed with status: ${statusCode}`);
    }
    
    console.log(`PayPal payment captured: ${order_id}`);
    
    return res.json({
      order_id: result.id,
      status: result.status,
      payer: result.payer,
      purchase_units: result.purchaseUnits
    });

  } catch (err) {
    console.error('PayPal capture error:', err);
    return res.status(500).json({ 
      error: 'Internal error capturing PayPal payment',
      details: err.message 
    });
  }
});

// Create shipping labels (outbound + return) via Shippo
app.post('/create-shipping-labels', async (req, res) => {
  try {
    const { to_address, parcel, order_id, customer_name, customer_email } = req.body || {};
    
    if (!to_address || !parcel) {
      return res.status(400).json({ error: 'Missing required address or parcel info' });
    }

    console.log(`Creating shipping labels for order ${order_id}`);

    // Warehouse address (from environment variables)
    const from_address = {
      name: process.env.WAREHOUSE_NAME || 'Dissonant',
      street1: process.env.WAREHOUSE_STREET || '789 9th St APT 4C',
      city: process.env.WAREHOUSE_CITY || 'New York',
      state: process.env.WAREHOUSE_STATE || 'NY',
      zip: process.env.WAREHOUSE_ZIP || '10019',
      country: process.env.WAREHOUSE_COUNTRY || 'US',
      company: 'Dissonant', // Add company name
    };

    // Create outbound shipment
    console.log('Creating outbound shipment...');
    const outboundShipmentPayload = {
      address_to: to_address,
      address_from: from_address,
      parcels: [parcel],
      async: false,
    };
    
    console.log('🔍 Outbound shipment payload:', JSON.stringify(outboundShipmentPayload, null, 2));
    
    // Retry mechanism for Shippo API calls
    let outboundShipment;
    let shipmentAttempt = 0;
    const maxShipmentRetries = 3;
    
    while (shipmentAttempt < maxShipmentRetries) {
      shipmentAttempt++;
      console.log(`🔄 Shipment creation attempt ${shipmentAttempt}/${maxShipmentRetries}`);
      
      try {
        outboundShipment = await fetch('https://api.goshippo.com/shipments/', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
          },
          body: JSON.stringify(outboundShipmentPayload),
        });
        
        if (outboundShipment.ok) {
          console.log(`✅ Shipment creation succeeded on attempt ${shipmentAttempt}`);
          break;
        } else {
          console.log(`⚠️ Shipment creation failed on attempt ${shipmentAttempt}, status: ${outboundShipment.status}`);
        }
      } catch (fetchError) {
        console.error(`❌ Network error on shipment attempt ${shipmentAttempt}:`, fetchError);
      }
      
      // Wait before retrying (exponential backoff)
      if (shipmentAttempt < maxShipmentRetries) {
        const waitTime = Math.pow(2, shipmentAttempt) * 1000; // 2s, 4s, 8s
        console.log(`⏳ Waiting ${waitTime}ms before retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }

    console.log('📡 Outbound shipment response status:', outboundShipment.status);

    if (!outboundShipment.ok) {
      const errorText = await outboundShipment.text();
      console.error('❌ Outbound shipment failed - Raw response:', errorText);
      
      let errorData;
      try {
        errorData = JSON.parse(errorText);
      } catch (parseError) {
        console.error('❌ Could not parse shipment error response as JSON:', parseError);
        errorData = { detail: errorText, raw_response: errorText };
      }
      
      console.error('❌ Outbound shipment creation failed:', errorData);
      throw new Error(`Failed to create outbound shipment: ${errorData.detail || errorData.message || errorText}`);
    }

    const outboundShipmentData = await outboundShipment.json();
    console.log('Outbound shipment created:', outboundShipmentData.object_id);

    // Get rates for outbound shipment
    console.log('Getting outbound rates...');
    const outboundRates = await fetch(`https://api.goshippo.com/shipments/${outboundShipmentData.object_id}/rates/`, {
      headers: {
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
    });

    if (!outboundRates.ok) {
      const errorData = await outboundRates.json();
      console.error('Failed to get outbound rates:', errorData);
      throw new Error(`Failed to get outbound rates: ${errorData.detail || errorData.message}`);
    }

    const outboundRatesData = await outboundRates.json();
    console.log('Available outbound rates:', outboundRatesData.results.map(r => `${r.servicelevel.name} (${r.provider}) - $${r.amount}`));
    
    // Prioritize USPS Ground Advantage for outbound (cheapest option)
    const outboundRate = outboundRatesData.results.find(rate => 
      rate.provider === 'USPS' && rate.servicelevel.name === 'Ground Advantage'
    ) || outboundRatesData.results.find(rate => 
      rate.provider === 'USPS' && rate.servicelevel.name === 'First Class'
    ) || outboundRatesData.results.find(rate => rate.provider === 'USPS') || outboundRatesData.results[0];

    if (!outboundRate) {
      throw new Error('No suitable outbound rate found');
    }
    
    console.log(`Selected outbound rate: ${outboundRate.servicelevel.name} (${outboundRate.provider}) - $${outboundRate.amount}`);
    console.log('Creating 4x6 inch Ground Advantage outbound label...');
    console.log('Selected outbound rate:', outboundRate.object_id);

    // Create outbound transaction (label)
    console.log('Creating outbound label...');
    const outboundPayload = {
      rate: outboundRate.object_id,
      async: false,
      label_file_type: 'PDF_4X6', // 4x6 inch label for easy printing
    };
    
    console.log('🔍 Outbound transaction payload:', JSON.stringify(outboundPayload, null, 2));
    console.log('🔍 Using Shippo token:', process.env.SHIPPO_TOKEN ? `${process.env.SHIPPO_TOKEN.substring(0, 20)}...` : 'NOT SET');
    
    const outboundTransaction = await fetch('https://api.goshippo.com/transactions/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify(outboundPayload),
    });

    console.log('📡 Outbound transaction response status:', outboundTransaction.status);
    console.log('📡 Outbound transaction response headers:', JSON.stringify([...outboundTransaction.headers.entries()]));

    if (!outboundTransaction.ok) {
      const errorText = await outboundTransaction.text();
      console.error('❌ Outbound transaction failed - Raw response:', errorText);
      
      let errorData;
      try {
        errorData = JSON.parse(errorText);
      } catch (parseError) {
        console.error('❌ Could not parse error response as JSON:', parseError);
        errorData = { detail: errorText, raw_response: errorText };
      }
      
      console.error('❌ Outbound transaction creation failed:', errorData);
      console.error('❌ Rate used:', outboundRate.object_id);
      console.error('❌ Rate details:', JSON.stringify(outboundRate, null, 2));
      
      throw new Error(`Failed to create outbound transaction: ${errorData.detail || errorData.message || errorText}`);
    }

    const outboundTransactionData = await outboundTransaction.json();
    console.log('Outbound label created:', outboundTransactionData.object_id);
    
    // Wait a moment for the label to be fully generated
    if (outboundTransactionData.status === 'SUCCESS') {
      console.log('Outbound label status:', outboundTransactionData.status);
      console.log('Outbound label URL:', outboundTransactionData.label_url);
      console.log('Outbound tracking:', outboundTransactionData.tracking_number);
    } else {
      console.log('Outbound label status:', outboundTransactionData.status);
      console.log('Outbound label message:', outboundTransactionData.messages);
    }

    // Create scan-based return shipment using Shippo's proper return API
    console.log('🔄 Creating scan-based return shipment with is_return=true...');
    const returnShipment = await fetch('https://api.goshippo.com/shipments/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        // For returns, DON'T swap addresses - Shippo does this automatically
        address_from: from_address, // Warehouse (same as outbound)
        address_to: to_address,     // Customer (same as outbound)
        parcels: [parcel],
        extra: { 
          is_return: true  // This makes it scan-based automatically!
        },
        async: false,
      }),
    });

    if (!returnShipment.ok) {
      const errorData = await returnShipment.json();
      console.error('Return shipment creation failed:', errorData);
      throw new Error(`Failed to create return shipment: ${errorData.detail || errorData.message}`);
    }

    const returnShipmentData = await returnShipment.json();
    console.log('✅ Return shipment created:', returnShipmentData.object_id);
    console.log('🔍 Return shipment response:', JSON.stringify(returnShipmentData, null, 2));

    // Get rates for return shipment
    console.log('Getting return rates...');
    const returnRates = await fetch(`https://api.goshippo.com/shipments/${returnShipmentData.object_id}/rates/`, {
      headers: {
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
    });

    if (!returnRates.ok) {
      const errorData = await returnRates.json();
      console.error('Failed to get return rates:', errorData);
      throw new Error(`Failed to get return rates: ${errorData.detail || errorData.message}`);
    }

    const returnRatesData = await returnRates.json();
    console.log('Available return rates:', returnRatesData.results.map(r => `${r.servicelevel.name} (${r.provider}) - $${r.amount}`));
    
    // Prioritize USPS Ground Advantage for returns (cheapest option)
    const returnRate = returnRatesData.results.find(rate => 
      rate.provider === 'USPS' && rate.servicelevel.name === 'Ground Advantage'
    ) || returnRatesData.results.find(rate => 
      rate.provider === 'USPS' && rate.servicelevel.name === 'First Class'
    ) || returnRatesData.results.find(rate => rate.provider === 'USPS') || returnRatesData.results[0];

    if (!returnRate) {
      throw new Error('No suitable return rate found');
    }
    
    console.log(`Selected return rate: ${returnRate.servicelevel.name} (${returnRate.provider}) - $${returnRate.amount}`);
    console.log('Creating scan-based return label...');

    // Create return transaction (this should be scan-based automatically)
    const returnTransaction = await fetch('https://api.goshippo.com/transactions/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        rate: returnRate.object_id,
        async: false,
        label_file_type: 'PDF_4X6',
        metadata: 'Scan-based return label via is_return=true',
      }),
    });

    if (!returnTransaction.ok) {
      const errorData = await returnTransaction.json();
      console.error('Return transaction creation failed:', errorData);
      throw new Error(`Failed to create return transaction: ${errorData.detail || errorData.message}`);
    }

    const returnTransactionData = await returnTransaction.json();
    console.log('✅ Return label created:', returnTransactionData.object_id);
    console.log('🔍 Return transaction response:', JSON.stringify(returnTransactionData, null, 2));
    
    // Check if it's truly scan-based
    if (returnTransactionData.status === 'SUCCESS') {
      console.log('✅ Return label status: SUCCESS');
      console.log('📄 Return label URL:', returnTransactionData.label_url);
      console.log('📦 Return tracking:', returnTransactionData.tracking_number);
      console.log('💰 Should be scan-based (only charged when used)');
    } else {
      console.log('⚠️ Return label status:', returnTransactionData.status);
      console.log('📝 Return label messages:', returnTransactionData.messages);
    }

    // Prepare label data for emails
    console.log('Preparing label data...');
    console.log('Outbound transaction data keys:', Object.keys(outboundTransactionData));
    console.log('Return transaction data keys:', Object.keys(returnTransactionData));
    
    // Check if labels were successfully generated
    const outboundLabel = {
      label_url: outboundTransactionData.status === 'SUCCESS' ? outboundTransactionData.label_url : 'Label generation failed - check Shippo dashboard',
      tracking_number: outboundTransactionData.status === 'SUCCESS' ? outboundTransactionData.tracking_number : 'Tracking generation failed - check Shippo dashboard',
      rate: outboundRate.amount,
      service: `${outboundRate.servicelevel.name} (${outboundRate.provider})`,
      status: outboundTransactionData.status,
      transaction_id: outboundTransactionData.object_id,
    };

    const returnLabel = {
      label_url: returnTransactionData.status === 'SUCCESS' ? returnTransactionData.label_url : 'Label generation failed - check Shippo dashboard',
      tracking_number: returnTransactionData.status === 'SUCCESS' ? returnTransactionData.tracking_number : 'Tracking generation failed - check Shippo dashboard',
      rate: returnRate.amount,
      service: `${returnRate.servicelevel.name} (${returnRate.provider})`,
      status: returnTransactionData.status,
      transaction_id: returnTransactionData.object_id,
      billing_method: 'SCAN_BASED' // All Shippo return labels with is_return=true are scan-based
    };

    // Send emails with robust error handling and retry logic
    const sendEmails = async () => {
      const maxRetries = 3;
      let attempt = 0;
      let warehouseEmailSent = false;
      let customerEmailSent = false;
      
      console.log('Starting email sending process...');
      console.log('Email function variables:', {
        order_id,
        customer_name,
        customer_email: !!customer_email,
        outboundLabel: !!outboundLabel,
        returnLabel: !!returnLabel,
        transporterType: transporter.service || transporter.constructor.name || 'Custom'
      });

      // Function to send email with retries
      const sendEmailWithRetry = async (mailOptions, description) => {
        for (let i = 0; i < maxRetries; i++) {
          try {
            console.log(`Attempt ${i + 1}/${maxRetries} - Sending ${description}...`);
            console.log('Mail options:', {
              from: mailOptions.from,
              to: mailOptions.to,
              subject: mailOptions.subject,
              textLength: mailOptions.text?.length || 0
            });
            
            const result = await transporter.sendMail(mailOptions);
            console.log(`✅ ${description} sent successfully on attempt ${i + 1}`);
            console.log('Email result:', {
              messageId: result.messageId || result.response || 'No message ID',
              response: result.response || 'No response'
            });
            return result;
          } catch (error) {
            console.error(`❌ Attempt ${i + 1} failed for ${description}:`, {
              message: error.message,
              code: error.code,
              command: error.command,
              response: error.response,
              stack: error.stack?.split('\n')[0] // Just first line of stack
            });
            
            if (i === maxRetries - 1) {
              throw error; // Re-throw on final attempt
            }
            
            // Wait before retry (exponential backoff)
            const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
            console.log(`Waiting ${delay}ms before retry...`);
            await new Promise(resolve => setTimeout(resolve, delay));
          }
        }
      };
      
      try {
        // Send detailed shipping label email to warehouse staff
        const warehouseEmailContent = `🎵 New Dissonant Order - Shipping Labels Ready!

📦 ORDER DETAILS:
Order ID: ${order_id}
Customer: ${customer_name}
Shipping Address: ${to_address.street1}, ${to_address.city}, ${to_address.state} ${to_address.zip}

📫 OUTBOUND SHIPMENT (To Customer):
• Label: ${outboundLabel.label_url}
• Tracking: ${outboundLabel.tracking_number}
• Service: ${outboundLabel.service}
• Cost: $${outboundLabel.rate}

🔄 RETURN SHIPMENT (Back to Warehouse):
• Label: ${returnLabel.label_url}
• Tracking: ${returnLabel.tracking_number}
• Service: ${returnLabel.service}
• Cost: $${returnLabel.rate}
• Billing: ${returnLabel.billing_method === 'SCAN_BASED' ? 'Only charged if used ✅' : 'Charged immediately ⚠️'}

⏰ Generated: ${new Date().toLocaleString('en-US', { 
  timeZone: 'America/New_York',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit'
})} EST

🚀 Ready to ship! Print labels and fulfill this musical discovery.

--
Dissonant Team`;

        const warehouseMailOptions = {
          from: process.env.EMAIL_USER || 'noreply@dissonant.com',
          to: 'dissonant.helpdesk@gmail.com',
          subject: `🎵 New Dissonant Order ${order_id} - Labels Ready!`,
          text: warehouseEmailContent,
        };

        await sendEmailWithRetry(warehouseMailOptions, 'warehouse shipping label email');
        warehouseEmailSent = true;
        console.log('✅ Warehouse email sent successfully');
        
      } catch (emailError) {
        console.error('❌ Final failure sending warehouse shipping label email:', emailError);
        
        // Store failed email to database for manual retry
        try {
          if (db) {
            await db.collection('failed_emails').add({
            type: 'warehouse_shipping_labels',
            order_id,
            error: emailError.message,
            timestamp: new Date().toISOString(),
            email_data: {
              to: 'dissonant.helpdesk@gmail.com',
              subject: `Shipping Labels for Order ${order_id}`,
              outbound_tracking: outboundLabel.tracking_number,
              return_tracking: returnLabel.tracking_number
            }
            });
            console.log('Failed email logged to database for manual retry');
          } else {
            console.log('⚠️ Database not available - cannot log failed email');
          }
        } catch (dbError) {
          console.error('Failed to log email failure to database:', dbError);
        }
      }

      // Send tracking information only to customer
      if (customer_email) {
        try {
          const customerEmailContent = `

Hello!

Your order has been receieved. A curator will select an album for you and ship it soon!
TRACKING #: ${outboundLabel.tracking_number}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT
`;

          const customerMailOptions = {
            from: process.env.EMAIL_USER || 'noreply@dissonant.com',
            to: customer_email,
            subject: `We've receieved your order!`,
            text: customerEmailContent,
          };

          await sendEmailWithRetry(customerMailOptions, 'customer tracking email');
          customerEmailSent = true;
          console.log('✅ Customer email sent successfully');
          
        } catch (emailError) {
          console.error('❌ Final failure sending customer tracking email:', emailError);
          
          // Store failed customer email to database for manual retry
          try {
            if (db) {
              await db.collection('failed_emails').add({
              type: 'customer_tracking',
              order_id,
              customer_email,
              error: emailError.message,
              timestamp: new Date().toISOString(),
              email_data: {
                to: customer_email,
                subject: `Order Tracking Information - ${order_id}`,
                outbound_tracking: outboundLabel.tracking_number,
                return_tracking: returnLabel.tracking_number
              }
              });
              console.log('Failed customer email logged to database for manual retry');
            } else {
              console.log('⚠️ Database not available - cannot log failed customer email');
            }
          } catch (dbError) {
            console.error('Failed to log customer email failure to database:', dbError);
          }
        }
      } else {
        console.log('No customer email provided, skipping customer notification');
      }
      
      console.log('Email sending process completed');
      
      // Update order record to indicate emails were sent successfully
      if (order_id && (warehouseEmailSent || customerEmailSent) && db) {
        try {
          console.log('Updating order record with email status...');
          await db.collection('orders').doc(order_id).update({
            emailStatus: 'sent',
            warehouseEmailSent: warehouseEmailSent,
            customerEmailSent: customerEmailSent,
            emailSentAt: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log('✅ Order email status updated successfully');
        } catch (emailStatusError) {
          console.error('❌ Failed to update order email status:', emailStatusError);
          // Don't fail the request - emails were sent successfully
        }
      }
    };

    // Test email transporter and send emails immediately (not in background)
    console.log('Testing email transporter...');
    
    let transporterVerified = false;
    try {
      // Different verification approaches for different transporters
      if (transporter.verify) {
        console.log('Verifying transporter with verify() method...');
        await transporter.verify();
        transporterVerified = true;
        console.log('✅ Email transporter verified successfully');
      } else {
        console.log('Transporter does not support verify(), assuming ready');
        transporterVerified = true;
      }
      
      console.log('Transporter details:', {
        hasVerify: !!transporter.verify,
        hasSendMail: !!transporter.sendMail,
        transporterType: transporter.service || transporter.constructor.name || 'Custom',
        options: transporter.options ? {
          service: transporter.options.service,
          host: transporter.options.host,
          port: transporter.options.port,
          secure: transporter.options.secure,
          user: transporter.options.auth?.user,
          passwordSet: !!transporter.options.auth?.pass
        } : 'No options available'
      });
      
    } catch (verifyError) {
      console.error('❌ Email transporter verification failed:', verifyError);
      console.error('Transporter error details:', {
        message: verifyError.message,
        code: verifyError.code,
        errno: verifyError.errno,
        syscall: verifyError.syscall,
        address: verifyError.address,
        port: verifyError.port
      });
      
      // Log to database for debugging
      try {
        if (db) {
          await db.collection('email_debug').add({
          type: 'transporter_verification_failed',
          error: verifyError.message,
          error_code: verifyError.code,
          timestamp: new Date().toISOString(),
          order_id
        });
        } else {
          console.log('⚠️ Database not available - cannot log debug info');
        }
      } catch (dbError) {
        console.error('Failed to log verification error to database:', dbError);
      }
    }
    
    // Send emails immediately (in foreground) to ensure they complete
    console.log('Starting immediate email sending...');
    try {
      await sendEmails();
      console.log('✅ Email sending completed successfully');
    } catch (emailError) {
      console.error('❌ Email sending failed completely:', emailError);
      console.error('Complete email error details:', {
        message: emailError.message,
        stack: emailError.stack,
        code: emailError.code,
        errno: emailError.errno,
        syscall: emailError.syscall
      });
      console.log('📧 Continuing with order creation despite email failure...');
      // Don't throw - we'll create the fallback order anyway
    }

    // Create fallback order record in Firebase to ensure customer gets their order
    // even if email sending fails completely
    let orderCreated = false;
    try {
      if (order_id && customer_email && db) {
        console.log('Creating fallback order record in Firebase...');
        await db.collection('orders').doc(order_id).set({
          orderId: order_id,
          customerEmail: customer_email,
          customerName: customer_name || 'Customer',
          status: 'labelCreated',
          statusDescription: 'Shipping labels created successfully',
          trackingNumber: outboundLabel.tracking_number,
          outboundTrackingNumber: outboundLabel.tracking_number,
          returnTrackingNumber: returnLabel.tracking_number,
          shippingAddress: to_address,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          emailStatus: 'pending', // Will be updated if emails succeed
          fallbackOrder: true, // Flag to indicate this was created as fallback
          labelUrls: {
            outbound: outboundLabel.label_url,
            return: returnLabel.label_url
          }
        }, { merge: true }); // Use merge to not overwrite existing data
        
        orderCreated = true;
        console.log('✅ Fallback order record created successfully');
      } else if (!db) {
        console.log('⚠️ Skipping fallback order record - Firebase not available');
      } else {
        console.log('⚠️ Skipping fallback order record - missing order_id or customer_email');
      }
    } catch (orderError) {
      console.error('❌ Failed to create fallback order record:', orderError);
      // Don't fail the entire request - labels were created successfully
    }

    return res.json({
      success: true,
      order_id,
      message: 'Real shipping labels created and emails sent successfully',
      outbound_label: outboundLabel,
      return_label: returnLabel,
      order_created: orderCreated,
    });

  } catch (err) {
    console.error('Shipping label creation error', err);
    return res.status(500).json({ error: `Internal error creating shipping labels: ${err.message}` });
  }
});

// Enhanced webhook endpoint for Shippo tracking updates
app.post('/shippo-webhook', async (req, res) => {
  try {
    const { event, data } = req.body;
    
    console.log('🔔 Received Shippo webhook:', {
      event,
      trackingNumber: data?.tracking_number,
      status: data?.tracking_status?.status,
      substatus: data?.tracking_status?.substatus,
      objectId: data?.object_id
    });
    
    // Handle different webhook events - EXPANDED to catch more delivery events
    if ((event === 'track_updated' || event === 'tracking_updated' || event === 'shipment_updated') && data?.tracking_number) {
      console.log('📦 Processing tracking update for:', data.tracking_number);
      console.log('🔍 Full tracking data received:', JSON.stringify(data, null, 2));
      
      // Update order status and send appropriate email
      const updateResult = await updateOrderStatusFromTracking(
        data.tracking_number, 
        data.tracking_status
      );
      
      console.log('✅ Tracking update processed:', updateResult);
      
      res.json({ 
        success: true, 
        processed: updateResult,
        message: 'Tracking update processed and customer notified'
      });
    } else if (event === 'transaction_created') {
      console.log('📄 Transaction created:', data?.object_id);
      res.json({ success: true, message: 'Transaction event received' });
    } else if (event === 'transaction_updated') {
      console.log('📄 Transaction updated:', data?.object_id);
      res.json({ success: true, message: 'Transaction update received' });
    } else {
      console.log('ℹ️ Unhandled webhook event:', event);
      console.log('🔍 Full webhook data:', JSON.stringify(req.body, null, 2));
      res.json({ success: true, message: 'Event received but not processed' });
    }
    
  } catch (err) {
    console.error('❌ Webhook processing error:', err);
    console.error('Webhook error details:', {
      message: err.message,
      stack: err.stack,
      event: req.body?.event,
      trackingNumber: req.body?.data?.tracking_number
    });
    res.status(500).json({ 
      error: 'Webhook processing failed', 
      details: err.message 
    });
  }
});

// Manual endpoint to check and update order status
app.post('/check-order-status', async (req, res) => {
  try {
    const { tracking_number, order_id } = req.body;
    
    if (!tracking_number) {
      return res.status(400).json({ error: 'Tracking number required' });
    }
    
    console.log(`Checking status for tracking: ${tracking_number}`);
    
    // Get tracking info from Shippo
    const trackingResponse = await fetch(`https://api.goshippo.com/tracks/${tracking_number}/`, {
      headers: {
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
    });
    
    if (!trackingResponse.ok) {
      const errorData = await trackingResponse.json();
      console.error('Failed to get tracking info:', errorData);
      return res.status(400).json({ error: 'Failed to get tracking info' });
    }
    
    const trackingData = await trackingResponse.json();
    console.log('Tracking data received:', trackingData.tracking_status);
    
    // Update order status in Firestore
    const updatedStatus = await updateOrderStatusFromTracking(tracking_number, trackingData.tracking_status, order_id);
    
    res.json({
      success: true,
      tracking_number,
      status: trackingData.tracking_status,
      updated: updatedStatus
    });
    
  } catch (err) {
    console.error('Order status check error:', err);
    res.status(500).json({ error: `Status check failed: ${err.message}` });
  }
});

// ENHANCED Test endpoint to simulate webhook events and debug delivery issues
app.post('/test-webhook', async (req, res) => {
  try {
    const { tracking_number, status, force_delivery_test } = req.body;
    
    if (!tracking_number) {
      return res.status(400).json({ 
        error: 'tracking_number is required',
        example: {
          tracking_number: "1Z999AA1234567890",
          status: "delivered", // or "transit", "in_transit", "returned", etc.
          force_delivery_test: true // optional - test with various delivery formats
        }
      });
    }
    
    console.log(`🧪 ENHANCED webhook testing for tracking: ${tracking_number}`);
    
    // If force_delivery_test is true, test multiple delivery scenarios
    if (force_delivery_test) {
      console.log('🎯 Testing multiple delivery detection scenarios...');
      
      const deliveryScenarios = [
        {
          name: 'Standard Delivered',
          trackingStatus: {
            status: 'delivered',
            status_detail: 'Delivered to recipient',
            substatus: 'delivered'
          }
        },
        {
          name: 'Delivered with different format',
          trackingStatus: {
            status: 'DELIVERED',
            status_detail: 'Package delivered to front door',
            substatus: 'delivered_to_recipient'
          }
        },
        {
          name: 'Available for pickup',
          trackingStatus: {
            status: 'delivered',
            status_detail: 'Available for pickup at location',
            substatus: 'available_for_pickup'
          }
        },
        {
          name: 'Shippo webhook format',
          trackingStatus: {
            tracking_status: {
              status: 'delivered',
              status_detail: 'Delivered - Left with individual at address',
              substatus: 'delivered'
            }
          }
        }
      ];
      
      const testResults = [];
      
      for (const scenario of deliveryScenarios) {
        console.log(`\n🧪 Testing scenario: ${scenario.name}`);
        try {
          const result = await updateOrderStatusFromTracking(tracking_number, scenario.trackingStatus);
          testResults.push({
            scenario: scenario.name,
            success: true,
            result: result
          });
        } catch (error) {
          testResults.push({
            scenario: scenario.name,
            success: false,
            error: error.message
          });
        }
      }
      
      return res.json({
        success: true,
        message: 'Delivery test scenarios completed',
        tracking_number,
        test_results: testResults,
        timestamp: new Date().toISOString()
      });
    }
    
    // Single status test (original behavior)
    const testStatus = status || 'delivered';
    console.log(`🧪 Testing single webhook simulation for tracking: ${tracking_number} with status: ${testStatus}`);
    
    // Create a mock tracking status object with various formats to test robustness
    const mockTrackingStatus = {
      status: testStatus,
      status_detail: `Simulated ${testStatus} status for testing - ${new Date().toISOString()}`,
      substatus: testStatus === 'delivered' ? 'delivered' : 'in_transit',
      // Also include nested format that Shippo sometimes sends
      tracking_status: {
        status: testStatus,
        status_detail: `Nested format - Simulated ${testStatus}`,
        substatus: testStatus === 'delivered' ? 'delivered_to_recipient' : 'in_transit'
      }
    };
    
    // Update order status using the same function as the real webhook
    const updatedStatus = await updateOrderStatusFromTracking(tracking_number, mockTrackingStatus);
    
    res.json({
      success: true,
      message: 'Webhook simulation completed',
      tracking_number,
      simulated_status: testStatus,
      mock_tracking_status: mockTrackingStatus,
      updated: updatedStatus,
      timestamp: new Date().toISOString()
    });
    
  } catch (err) {
    console.error('Webhook simulation error:', err);
    res.status(500).json({ error: `Webhook simulation failed: ${err.message}` });
  }
});

// NEW: Debug endpoint to check current status of orders by tracking number
app.post('/debug-order-status', async (req, res) => {
  try {
    const { tracking_number } = req.body;
    
    if (!tracking_number) {
      return res.status(400).json({ error: 'tracking_number is required' });
    }
    
    console.log(`🔍 DEBUG: Checking current status for tracking: ${tracking_number}`);
    
    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }
    
    // Search for orders with this tracking number using the same logic as the webhook
    const searchQueries = [
      db.collection('orders').where('trackingNumber', '==', tracking_number),
      db.collection('orders').where('outboundTrackingNumber', '==', tracking_number),
      db.collection('orders').where('tracking_number', '==', tracking_number),
      db.collection('orders').where('shipment_tracking', '==', tracking_number),
    ];
    
    const queryResults = await Promise.all(
      searchQueries.map(query => query.get().catch(err => {
        return { docs: [] };
      }))
    );
    
    const allOrders = new Map();
    queryResults.forEach(result => {
      result.docs.forEach(doc => allOrders.set(doc.id, doc));
    });
    
    const orderDetails = [];
    allOrders.forEach((doc, docId) => {
      const data = doc.data();
      orderDetails.push({
        orderId: docId,
        status: data.status,
        statusDescription: data.statusDescription,
        trackingNumber: data.trackingNumber,
        outboundTrackingNumber: data.outboundTrackingNumber,
        updatedAt: data.updatedAt,
        lastTrackingUpdate: data.lastTrackingUpdate,
        customerEmail: data.customerEmail
      });
    });
    
    res.json({
      success: true,
      tracking_number,
      orders_found: orderDetails.length,
      orders: orderDetails,
      timestamp: new Date().toISOString()
    });
    
  } catch (err) {
    console.error('Debug order status error:', err);
    res.status(500).json({ error: `Debug failed: ${err.message}` });
  }
});

// Function to update order status in Firestore based on tracking
async function updateOrderStatusFromTracking(trackingNumber, trackingStatus, orderId = null) {
  try {
    console.log(`Updating order status for tracking ${trackingNumber}: ${trackingStatus}`);
    
    // ENHANCED mapping of Shippo tracking status to our order status - FIXED for delivery detection
    let orderStatus = 'unknown';
    let statusDescription = '';
    let shouldSendEmail = false;
    
    // Get status from multiple possible fields (Shippo can send different formats)
    const state = (trackingStatus?.status?.toLowerCase() || 
                   trackingStatus?.state?.toLowerCase() || 
                   trackingStatus?.tracking_status?.status?.toLowerCase() ||
                   '').trim();
    
    const substatus = (trackingStatus?.substatus?.toLowerCase() || 
                      trackingStatus?.tracking_status?.substatus?.toLowerCase() ||
                      '').trim();
    
    const statusDetail = trackingStatus?.status_detail || 
                        trackingStatus?.tracking_status?.status_detail || 
                        trackingStatus?.status_details || '';
    
    console.log('📊 Processing tracking status (ENHANCED):', { 
      state, 
      substatus, 
      statusDetail,
      originalTrackingStatus: trackingStatus 
    });
    
    // CRITICAL: Check for delivery first with multiple possible indicators
    const deliveredIndicators = [
      'delivered',
      'delivery',
      'delivered_to_recipient',
      'available_for_pickup',
      'delivered_pickup'
    ];
    
    const transitIndicators = [
      'transit',
      'in_transit',
      'accepted',
      'in_transit_to_destination',
      'out_for_delivery'
    ];
    
    const returnedIndicators = [
      'returned',
      'return_to_sender',
      'returned_to_sender',
      'return'
    ];
    
    // Check if any field contains delivery indicators
    const isDelivered = deliveredIndicators.some(indicator => 
      state.includes(indicator) || 
      substatus.includes(indicator) || 
      statusDetail.toLowerCase().includes(indicator)
    );
    
    const isInTransit = transitIndicators.some(indicator => 
      state.includes(indicator) || 
      substatus.includes(indicator) || 
      statusDetail.toLowerCase().includes(indicator)
    );
    
    const isReturned = returnedIndicators.some(indicator => 
      state.includes(indicator) || 
      substatus.includes(indicator) || 
      statusDetail.toLowerCase().includes(indicator)
    );
    
    if (isDelivered) {
      orderStatus = 'delivered';
      statusDescription = 'Package delivered';
      shouldSendEmail = true;
      console.log('🎯 DELIVERY DETECTED: Package marked as delivered');
    } else if (isReturned) {
      orderStatus = 'returned';
      statusDescription = 'Package returned';
      shouldSendEmail = true;
      console.log('🔄 RETURN DETECTED: Package returned to sender');
    } else if (isInTransit) {
      orderStatus = 'sent';
      statusDescription = 'Package in transit';
      shouldSendEmail = true;
      console.log('🚚 TRANSIT DETECTED: Package is in transit');
    } else {
      // Fallback to original switch logic for edge cases
      switch (state) {
        case 'unknown':
        case 'pre_transit':
        case 'information_received':
          orderStatus = 'labelCreated';
          statusDescription = 'Shipping label created';
          shouldSendEmail = false;
          break;
          
        case 'failure':
        case 'exception':
        case 'error':
          orderStatus = 'deliveryFailed';
          statusDescription = 'Delivery failed';
          shouldSendEmail = true;
          break;
          
        default:
          orderStatus = 'unknown';
          statusDescription = statusDetail || trackingStatus?.status || 'Status update';
          shouldSendEmail = false;
          console.log('⚠️ UNKNOWN STATUS: Could not map status to known category');
      }
    }
    
    console.log('📋 Mapped status:', { orderStatus, statusDescription, shouldSendEmail });
    
    let updatedOrders = [];
    
    // If we have an order ID, update that specific order
    if (orderId && db) {
      try {
        const orderRef = db.collection('orders').doc(orderId);
        await orderRef.update({
          status: orderStatus,
          statusDescription: statusDescription,
          updatedAt: new Date().toISOString(),
          trackingStatus: trackingStatus,
        });
        console.log(`Order ${orderId} status updated to ${orderStatus} in Firestore`);
        updatedOrders.push(orderId);
      } catch (error) {
        console.error(`Failed to update order ${orderId}:`, error);
      }
    }
    
    // ENHANCED search for orders with this tracking number - search multiple fields and patterns
    try {
      if (db) {
        console.log(`🔍 ENHANCED SEARCH: Looking for orders with tracking: ${trackingNumber}`);
        
        // Search multiple tracking number fields for maximum compatibility
        const searchQueries = [
          // Standard fields
          db.collection('orders').where('trackingNumber', '==', trackingNumber),
          db.collection('orders').where('outboundTrackingNumber', '==', trackingNumber),
          
          // Alternative field names that might exist
          db.collection('orders').where('tracking_number', '==', trackingNumber),
          db.collection('orders').where('shipment_tracking', '==', trackingNumber),
        ];
        
        // Execute all search queries in parallel
        const queryResults = await Promise.all(
          searchQueries.map(query => query.get().catch(err => {
            console.log('Query failed (field might not exist):', err.message);
            return { docs: [] }; // Return empty result for failed queries
          }))
        );
        
        // Combine all results and deduplicate by document ID
        const allOrders = new Map();
        queryResults.forEach(result => {
          result.docs.forEach(doc => allOrders.set(doc.id, doc));
        });
        
        console.log(`📊 Found ${allOrders.size} orders matching tracking ${trackingNumber}`);
        
        if (allOrders.size > 0) {
          // Only update if the new status is different and more advanced
          const batch = db.batch();
          let actualUpdates = 0;
          
          allOrders.forEach((doc, docId) => {
            const currentData = doc.data();
            const currentStatus = currentData.status;
            
            console.log(`📝 Order ${docId}: current status '${currentStatus}' -> proposed '${orderStatus}'`);
            
            // Only update if status is changing to avoid unnecessary updates
            if (currentStatus !== orderStatus) {
              batch.update(doc.ref, {
                status: orderStatus,
                statusDescription: statusDescription,
                updatedAt: new Date().toISOString(),
                trackingStatus: trackingStatus,
                // Ensure trackingNumber field is set for future compatibility
                trackingNumber: trackingNumber,
                // Store the delivery update source
                lastTrackingUpdate: {
                  timestamp: new Date().toISOString(),
                  source: 'shippo_webhook',
                  originalStatus: currentStatus,
                  newStatus: orderStatus
                }
              });
              updatedOrders.push(docId);
              actualUpdates++;
              console.log(`✅ Will update order ${docId}: '${currentStatus}' -> '${orderStatus}'`);
            } else {
              console.log(`⏭️ Skipping order ${docId}: already has status '${currentStatus}'`);
            }
          });
          
          if (actualUpdates > 0) {
            await batch.commit();
            console.log(`✅ Updated ${actualUpdates} orders with tracking ${trackingNumber}`);
          } else {
            console.log(`ℹ️ No orders needed status updates for tracking ${trackingNumber}`);
          }
        } else {
          console.log(`❌ No orders found with tracking number ${trackingNumber}`);
          
          // Additional debugging - let's see what orders exist
          try {
            const allOrdersSnapshot = await db.collection('orders').limit(5).get();
            console.log('📋 Sample of recent orders in database:');
            allOrdersSnapshot.docs.forEach((doc, index) => {
              const data = doc.data();
              console.log(`  ${index + 1}. Order ${doc.id}: tracking=${data.trackingNumber || data.outboundTrackingNumber || 'NONE'}, status=${data.status}`);
            });
          } catch (debugError) {
            console.log('Could not fetch sample orders for debugging:', debugError.message);
          }
        }
      } else {
        console.log('⚠️ Database not available - cannot search orders by tracking number');
      }
    } catch (error) {
      console.error(`❌ Failed to search orders by tracking number:`, error);
    }
    
    // Send notification email to customer about status change (only for important updates)
    if (updatedOrders.length > 0 && shouldSendEmail) {
      console.log(`📧 Sending ${orderStatus} status email to customer...`);
      await sendStatusUpdateEmail(trackingNumber, orderStatus, statusDescription, updatedOrders);
    } else if (updatedOrders.length > 0) {
      console.log(`ℹ️ Status updated but no email sent for status: ${orderStatus}`);
    }
    
    return {
      tracking_number: trackingNumber,
      order_status: orderStatus,
      description: statusDescription,
      updated_orders: updatedOrders,
      timestamp: new Date().toISOString()
    };
    
  } catch (err) {
    console.error('Error updating order status:', err);
    throw err;
  }
}

// Function to send status update emails to customers with specific templates
async function sendStatusUpdateEmail(trackingNumber, orderStatus, statusDescription, orderIds) {
  try {
    if (!db) {
      console.log('⚠️ Database not available - cannot send status update email');
      return;
    }
    
    // Get customer information from the first updated order
    const orderDoc = await db.collection('orders').doc(orderIds[0]).get();
    if (!orderDoc.exists) {
      console.log('Order not found for email notification');
      return;
    }
    
    const orderData = orderDoc.data();
    const customerEmail = orderData.customerEmail || orderData.email;
    const customerName = orderData.customerName || orderData.name || 'Music Lover';
    
    if (!customerEmail) {
      console.log('No customer email found for status update notification');
      return;
    }
    
    // Generate specific email content based on order status
    let emailContent = '';
    let subject = '';
    
    switch (orderStatus) {
      case 'sent':
        // SHIPPED EMAIL TEMPLATE
        emailContent = `

Hello!

A curator has selected an album for you and it's now on its way!

Tracking #: ${trackingNumber}

Please email us at this address if you have any questions or issues with your order.

We hope you enjoy!

DISSONANT

`;
        subject = 'Your Dissonant order has shipped!';
        break;

      case 'delivered':
        // DELIVERED EMAIL TEMPLATE
        emailContent = `
Hello!

Your order has arrived.
Live with it, listen to it, and enjoy the music!
Remember if you don't like it you can return it with the return label included in your package and your next order will be free.

Tracking #: ${trackingNumber}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT

`;
        subject = 'Your Dissonant order has been delivered!';
        break;

      default:
        // GENERIC UPDATE EMAIL TEMPLATE
        emailContent = `DISSONANT ORDER UPDATE

Hi ${customerName},

Status: ${statusDescription}
Tracking #: ${trackingNumber}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT

`;
        subject = `DISSONANT ORDER UPDATE - ${statusDescription.toUpperCase()}`;
        break;
    }

    const mailOptions = {
      from: process.env.EMAIL_USER || 'noreply@dissonant.com',
      to: customerEmail,
      subject: subject,
      text: emailContent,
    };

    await transporter.sendMail(mailOptions);
    console.log(`${orderStatus} status email sent to ${customerEmail} for tracking ${trackingNumber}`);
    
  } catch (emailError) {
    console.error('Failed to send status update email:', emailError);
  }
}

// Test endpoint for shipping status emails
app.post('/test-shipping-emails', async (req, res) => {
  try {
    const { email_type, test_email } = req.body;
    const testEmail = test_email || 'dissonant.helpdesk@gmail.com';
    const testOrderIds = ['TEST-ORDER-123'];
    const testTrackingNumber = '1Z999AA1234567890';
    
    console.log(`Testing ${email_type} email template...`);
    
    let emailSent = false;
    
    switch (email_type) {
      case 'shipped':
        await sendStatusUpdateEmail(testTrackingNumber, 'sent', 'Package in transit', testOrderIds);
        emailSent = true;
        break;
      case 'delivered':
        await sendStatusUpdateEmail(testTrackingNumber, 'delivered', 'Package delivered', testOrderIds);
        emailSent = true;
        break;
      case 'returned':
        await sendStatusUpdateEmail(testTrackingNumber, 'returned', 'Package returned', testOrderIds);
        emailSent = true;
        break;
      default:
        return res.status(400).json({
          error: 'Invalid email_type. Use: shipped, delivered, or returned'
        });
    }
    
    res.json({
      success: true,
      message: `${email_type} email template test sent successfully`,
      email_type,
      recipient: testEmail,
      test_tracking: testTrackingNumber,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Test shipping email failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      email_type: req.body?.email_type
    });
  }
});

// Test email endpoint to debug email functionality
app.post('/test-email', async (req, res) => {
  try {
    console.log('=== EMAIL FUNCTIONALITY TEST ===');
    console.log('Environment variables:');
    console.log('EMAIL_USER:', process.env.EMAIL_USER);
    console.log('EMAIL_PASSWORD:', process.env.EMAIL_PASSWORD ? '***SET***' : 'NOT SET');
    console.log('AWS_SES_REGION:', process.env.AWS_SES_REGION || 'NOT SET');
    console.log('SENDGRID_API_KEY:', process.env.SENDGRID_API_KEY ? '***SET***' : 'NOT SET');
    
    const { test_email } = req.body;
    const testRecipient = test_email || 'dissonant.helpdesk@gmail.com';
    
    console.log('Transporter details:');
    console.log('Type:', transporter.service || transporter.constructor.name || 'Custom');
    console.log('Has verify method:', !!transporter.verify);
    console.log('Has sendMail method:', !!transporter.sendMail);
    
    if (transporter.options) {
      console.log('Transporter options:', {
        service: transporter.options.service,
        host: transporter.options.host,
        port: transporter.options.port,
        secure: transporter.options.secure,
        user: transporter.options.auth?.user,
        passwordSet: !!transporter.options.auth?.pass
      });
    }
    
    // Test transporter verification
    console.log('Testing transporter verification...');
    try {
      if (transporter.verify) {
        await transporter.verify();
        console.log('✅ Transporter verification successful');
      } else {
        console.log('⚠️ Transporter does not support verification');
      }
    } catch (verifyError) {
      console.error('❌ Transporter verification failed:', {
        message: verifyError.message,
        code: verifyError.code,
        errno: verifyError.errno,
        syscall: verifyError.syscall,
        address: verifyError.address,
        port: verifyError.port
      });
    }
    
    const testMailOptions = {
      from: process.env.EMAIL_USER || 'noreply@dissonant.com',
      to: testRecipient,
      subject: `Test Email from Lambda Function - ${new Date().toISOString()}`,
      text: `This is a test email to verify the email functionality is working.
      
Generated at: ${new Date().toISOString()}
Lambda execution ID: ${process.env.AWS_LAMBDA_REQUEST_ID || 'Not in Lambda'}
Environment: ${process.env.NODE_ENV || 'development'}
Transporter: ${transporter.service || transporter.constructor.name || 'Custom'}

If you receive this email, the email functionality is working correctly.`,
    };

    console.log('Attempting to send test email...');
    console.log('Mail options:', {
      from: testMailOptions.from,
      to: testMailOptions.to,
      subject: testMailOptions.subject,
      textLength: testMailOptions.text.length
    });
    
    const result = await transporter.sendMail(testMailOptions);
    console.log('✅ Test email sent successfully');
    console.log('Email result:', {
      messageId: result.messageId || result.response || 'No message ID',
      response: result.response || 'No response',
      envelope: result.envelope || 'No envelope info'
    });
    
    res.json({
      success: true,
      message: 'Test email sent successfully',
      messageId: result.messageId || result.response,
      emailUser: process.env.EMAIL_USER,
      transporterType: transporter.service || transporter.constructor.name || 'Custom',
      recipient: testRecipient,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Test email failed:', error);
    console.error('Complete error details:', {
      message: error.message,
      code: error.code,
      errno: error.errno,
      syscall: error.syscall,
      address: error.address,
      port: error.port,
      command: error.command,
      response: error.response,
      stack: error.stack?.split('\n')[0]
    });
    
    res.status(500).json({
      success: false,
      error: error.message,
      errorCode: error.code,
      emailUser: process.env.EMAIL_USER,
      emailPasswordSet: !!process.env.EMAIL_PASSWORD,
      awsSesRegion: process.env.AWS_SES_REGION || null,
      sendgridKeySet: !!process.env.SENDGRID_API_KEY,
      transporterType: transporter.service || transporter.constructor.name || 'Custom',
      timestamp: new Date().toISOString()
    });
  }
});

module.exports.handler = serverless(app);