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
    firebaseApp = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || 'dissonantapp2',
    });
  } else {
    firebaseApp = admin.app();
  }
} catch (error) {
  console.log('Firebase Admin already initialized');
  firebaseApp = admin.app();
}

const db = admin.firestore();

app.use(bodyParser.json());

// Configure email transporter with multiple fallback options
let transporter;

// Try to use Amazon SES first (recommended for Lambda)
if (process.env.AWS_SES_REGION) {
  console.log('Using Amazon SES for email transport');
  console.log('SES Region:', process.env.AWS_SES_REGION);
  console.log('SES Email User:', process.env.EMAIL_USER);
  
  const aws = require('aws-sdk');
  // In Lambda, use IAM role instead of explicit credentials
  aws.config.update({
    region: process.env.AWS_SES_REGION,
  });
  
  transporter = nodemailer.createTransport({
    SES: new aws.SES({ apiVersion: '2010-12-01' }),
    sendingRate: 14, // max 14 messages/second
  });
  
  console.log('✅ Amazon SES transporter configured');
} else if (process.env.SENDGRID_API_KEY) {
  // Use SendGrid as fallback
  console.log('Using SendGrid for email transport');
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
} else {
  // Fallback to Gmail with better configuration
  console.log('Using Gmail for email transport (fallback)');
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

// PayPal payment endpoint
app.post('/create-paypal-payment', async (req, res) => {
  try {
    const { amount, currency = 'USD', return_url, cancel_url } = req.body || {};
    if (!amount) {
      return res.status(400).json({ error: 'Missing amount' });
    }

    // For now, return a mock PayPal approval URL
    // In a real implementation, you'd integrate with PayPal SDK
    const mockPaymentId = `PAY-${Date.now()}`;
    const approvalUrl = `https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=${mockPaymentId}`;
    
    console.log(`Mock PayPal payment created for $${amount} ${currency}`);
    
    return res.json({
      payment_id: mockPaymentId,
      approval_url: approvalUrl,
      amount,
      currency,
      status: 'created'
    });
  } catch (err) {
    console.error('PayPal payment creation error', err);
    return res.status(500).json({ error: 'Internal error' });
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
    };

    // Create outbound shipment
    console.log('Creating outbound shipment...');
    const outboundShipment = await fetch('https://api.goshippo.com/shipments/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        address_to: to_address,
        address_from: from_address,
        parcels: [parcel],
        async: false,
      }),
    });

    if (!outboundShipment.ok) {
      const errorData = await outboundShipment.json();
      console.error('Outbound shipment creation failed:', errorData);
      throw new Error(`Failed to create outbound shipment: ${errorData.detail || errorData.message}`);
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
    const outboundTransaction = await fetch('https://api.goshippo.com/transactions/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        rate: outboundRate.object_id,
        async: false,
        label_file_type: 'PDF_4X6', // 4x6 inch label for easy printing
      }),
    });

    if (!outboundTransaction.ok) {
      const errorData = await outboundTransaction.json();
      console.error('Outbound transaction creation failed:', errorData);
      throw new Error(`Failed to create outbound transaction: ${errorData.detail || errorData.message}`);
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

    // Create return shipment (reverse addresses)
    console.log('Creating return shipment...');
    const returnShipment = await fetch('https://api.goshippo.com/shipments/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        address_to: from_address, // Return to warehouse
        address_from: to_address, // From customer
        parcels: [parcel],
        async: false,
      }),
    });

    if (!returnShipment.ok) {
      const errorData = await returnShipment.json();
      console.error('Return shipment creation failed:', errorData);
      throw new Error(`Failed to create return shipment: ${errorData.detail || errorData.message}`);
    }

    const returnShipmentData = await returnShipment.json();
    console.log('Return shipment created:', returnShipmentData.object_id);

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
    console.log('Creating 4x6 inch Ground Advantage return label...');
    console.log('Selected return rate:', returnRate.object_id);

    // Create return transaction (label)
    console.log('Creating return label...');
    const returnTransaction = await fetch('https://api.goshippo.com/transactions/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `ShippoToken ${process.env.SHIPPO_TOKEN}`,
      },
      body: JSON.stringify({
        rate: returnRate.object_id,
        async: false,
        label_file_type: 'PDF_4X6', // 4x6 inch label for easy printing
      }),
    });

    if (!returnTransaction.ok) {
      const errorData = await returnTransaction.json();
      console.error('Return transaction creation failed:', errorData);
      throw new Error(`Failed to create return transaction: ${errorData.detail || errorData.message}`);
    }

    const returnTransactionData = await returnTransaction.json();
    console.log('Return label created:', returnTransactionData.object_id);
    
    // Wait a moment for the label to be fully generated
    if (returnTransactionData.status === 'SUCCESS') {
      console.log('Return label status:', returnTransactionData.status);
      console.log('Return label URL:', returnTransactionData.label_url);
      console.log('Return tracking:', returnTransactionData.tracking_number);
    } else {
      console.log('Return label status:', returnTransactionData.status);
      console.log('Return label message:', returnTransactionData.messages);
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
    };

    // Send emails with robust error handling and retry logic
    const sendEmails = async () => {
      const maxRetries = 3;
      let attempt = 0;
      
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
        
      } catch (emailError) {
        console.error('❌ Final failure sending warehouse shipping label email:', emailError);
        
        // Store failed email to database for manual retry
        try {
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
        } catch (dbError) {
          console.error('Failed to log email failure to database:', dbError);
        }
      }

      // Send tracking information only to customer
      if (customer_email) {
        try {
          const customerEmailContent = `DISSONANT ORDER RECEIVED

Hi ${customer_name},

Your order has been receieved. A curator will select an album for you and ship it soon!
TRACKING #: ${outboundLabel.tracking_number}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT

--
Order processed: ${new Date().toLocaleString('en-US', { 
  timeZone: 'America/New_York',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit'
})} EST`;

          const customerMailOptions = {
            from: process.env.EMAIL_USER || 'noreply@dissonant.com',
            to: customer_email,
            subject: `DISSONANT ORDER RECEIVED`,
            text: customerEmailContent,
          };

          await sendEmailWithRetry(customerMailOptions, 'customer tracking email');
          
        } catch (emailError) {
          console.error('❌ Final failure sending customer tracking email:', emailError);
          
          // Store failed customer email to database for manual retry
          try {
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
          } catch (dbError) {
            console.error('Failed to log customer email failure to database:', dbError);
          }
        }
      } else {
        console.log('No customer email provided, skipping customer notification');
      }
      
      console.log('Email sending process completed');
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
        await db.collection('email_debug').add({
          type: 'transporter_verification_failed',
          error: verifyError.message,
          error_code: verifyError.code,
          timestamp: new Date().toISOString(),
          order_id
        });
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
    }

    return res.json({
      success: true,
      order_id,
      message: 'Real shipping labels created and emails sent successfully',
      outbound_label: outboundLabel,
      return_label: returnLabel,
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
    
    // Handle different webhook events
    if (event === 'track_updated' && data?.tracking_number) {
      console.log('📦 Processing tracking update for:', data.tracking_number);
      
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

// Function to update order status in Firestore based on tracking
async function updateOrderStatusFromTracking(trackingNumber, trackingStatus, orderId = null) {
  try {
    console.log(`Updating order status for tracking ${trackingNumber}: ${trackingStatus}`);
    
    // Enhanced mapping of Shippo tracking status to our order status
    let orderStatus = 'unknown';
    let statusDescription = '';
    let shouldSendEmail = false;
    
    const state = trackingStatus?.status?.toLowerCase() || trackingStatus?.state?.toLowerCase();
    const substatus = trackingStatus?.substatus?.toLowerCase();
    
    console.log('📊 Processing tracking status:', { state, substatus, trackingStatus });
    
    switch (state) {
      case 'unknown':
      case 'pre_transit':
        orderStatus = 'labelCreated';
        statusDescription = 'Shipping label created';
        shouldSendEmail = false; // Don't send email for label creation
        break;
        
      case 'transit':
      case 'in_transit':
        orderStatus = 'sent';
        statusDescription = 'Package in transit';
        shouldSendEmail = true; // Send "shipped" email
        break;
        
      case 'delivered':
        orderStatus = 'delivered';
        statusDescription = 'Package delivered';
        shouldSendEmail = true; // Send "delivered" email
        break;
        
      case 'returned':
      case 'return_to_sender':
        orderStatus = 'returned';
        statusDescription = 'Package returned';
        shouldSendEmail = true; // Send "return confirmed" email
        break;
        
      case 'failure':
      case 'exception':
      case 'error':
        orderStatus = 'deliveryFailed';
        statusDescription = 'Delivery failed';
        shouldSendEmail = true; // Send generic update email
        break;
        
      case 'out_for_delivery':
        orderStatus = 'sent';
        statusDescription = 'Out for delivery';
        shouldSendEmail = false; // Don't send separate email for out-for-delivery
        break;
        
      default:
        orderStatus = 'unknown';
        statusDescription = trackingStatus?.status_detail || 'Status update';
        shouldSendEmail = false;
    }
    
    console.log('📋 Mapped status:', { orderStatus, statusDescription, shouldSendEmail });
    
    let updatedOrders = [];
    
    // If we have an order ID, update that specific order
    if (orderId) {
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
    
    // Also search for orders with this tracking number and update them
    try {
      const ordersQuery = await db.collection('orders')
        .where('trackingNumber', '==', trackingNumber)
        .get();
      
      if (!ordersQuery.empty) {
        const batch = db.batch();
        ordersQuery.forEach(doc => {
          batch.update(doc.ref, {
            status: orderStatus,
            statusDescription: statusDescription,
            updatedAt: new Date().toISOString(),
            trackingStatus: trackingStatus,
          });
          updatedOrders.push(doc.id);
        });
        await batch.commit();
        console.log(`Updated ${ordersQuery.size} orders with tracking ${trackingNumber}`);
      }
    } catch (error) {
      console.error(`Failed to search orders by tracking number:`, error);
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
        emailContent = `YOUR DISSONANT ORDER HAS SHIPPED

Hi ${customerName},

Hello!

A curator has selected an album for you and it's now on its way!

Tracking #: ${trackingNumber}

Please email us at this address if you have any questions or issues with your order.

We hope you enjoy!

DISSONANT

--
Shipped: ${new Date().toLocaleString('en-US', { 
  timeZone: 'America/New_York',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit'
})} EST`;
        subject = 'YOUR DISSONANT ORDER HAS SHIPPED';
        break;

      case 'delivered':
        // DELIVERED EMAIL TEMPLATE
        emailContent = `YOUR DISSONANT ORDER HAS BEEN DELIVERED

Your order has arrived.
Live with it, listen to it, and enjoy the music!
Remember if you don't like it you can return it with the return label included in your package and your next order will be free.

Tracking #: ${trackingNumber}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT

--
Delivered: ${new Date().toLocaleString('en-US', { 
  timeZone: 'America/New_York',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit'
})} EST`;
        subject = 'YOUR DISSONANT ORDER HAS BEEN DELIVERED';
        break;

      default:
        // GENERIC UPDATE EMAIL TEMPLATE
        emailContent = `DISSONANT ORDER UPDATE

Hi ${customerName},

Status: ${statusDescription}
Tracking #: ${trackingNumber}

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT

--
Updated: ${new Date().toLocaleString('en-US', { 
  timeZone: 'America/New_York',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit'
})} EST`;
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