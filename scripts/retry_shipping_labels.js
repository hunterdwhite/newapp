#!/usr/bin/env node

/**
 * Retry Shipping Label Creation
 * 
 * Manually triggers shipping label creation for a specific order.
 */

const path = require('path');

let admin;
try {
  admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));
} catch (e) {
  try {
    admin = require('firebase-admin');
  } catch (e2) {
    console.error('❌ Error: firebase-admin not found');
    process.exit(1);
  }
}

// Try to require axios from functions directory
let axiosLib;
try {
  axiosLib = require(path.join(__dirname, '../functions/node_modules/axios'));
} catch (e) {
  try {
    axiosLib = require('axios');
  } catch (e2) {
    console.error('❌ Error: axios not found');
    console.error('Please run: cd functions && npm install axios');
    process.exit(1);
  }
}

try {
  admin.initializeApp();
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  process.exit(1);
}

const db = admin.firestore();

// Lambda endpoint for shipping labels (from Cloud Functions)
const LAMBDA_ENDPOINT = 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels';

async function createShippingLabels(orderId) {
  console.log('\n📦 SHIPPING LABEL RETRY');
  console.log('━'.repeat(70));
  console.log(`Order ID: ${orderId}\n`);

  try {
    // 1. Get order data
    console.log('1️⃣  Fetching order data...');
    const orderDoc = await db.collection('orders').doc(orderId).get();
    
    if (!orderDoc.exists) {
      throw new Error(`Order ${orderId} not found`);
    }
    
    const orderData = orderDoc.data();
    console.log(`   ✅ Order found`);
    console.log(`   User ID: ${orderData.userId}`);
    console.log(`   Status: ${orderData.status}`);
    console.log(`   Created: ${orderData.createdAt?.toDate?.() || 'Unknown'}`);
    
    // 2. Parse address
    console.log('\n2️⃣  Parsing shipping address...');
    const shippingAddress = orderData.shippingAddress || orderData.address;
    
    if (!shippingAddress) {
      throw new Error('No shipping address found in order');
    }
    
    console.log(`   Address: ${shippingAddress}`);
    
    let customerName, streetAddress, city, state, zip;
    
    // Try to parse different address formats
    if (shippingAddress.includes('\n')) {
      // Format: "Name\nStreet\nCity, State Zip"
      const addressLines = shippingAddress.split('\n');
      if (addressLines.length < 3) {
        throw new Error('Invalid address format');
      }
      
      customerName = addressLines[0].trim();
      streetAddress = addressLines[1].trim();
      const cityStateZip = addressLines[2].split(',');
      
      if (cityStateZip.length < 2) {
        throw new Error('Invalid city/state/zip format');
      }
      
      city = cityStateZip[0].trim();
      const stateZipParts = cityStateZip[1].trim().split(' ');
      
      if (stateZipParts.length < 2) {
        throw new Error('Invalid state/zip format');
      }
      
      state = stateZipParts[0].trim();
      zip = stateZipParts.slice(1).join('').trim();
    } else {
      // Format: "Name, Street, Apt, City, State Zip"
      const parts = shippingAddress.split(',').map(p => p.trim());
      
      if (parts.length < 4) {
        throw new Error('Invalid address format - not enough parts');
      }
      
      customerName = parts[0];
      
      // Combine street parts (may include apartment number)
      // Last part should be "City, State Zip"
      const lastPart = parts[parts.length - 1]; // "Austin, TX 78705"
      const secondLastPart = parts[parts.length - 2]; // City might be here
      
      // Check if last part has state and zip
      const stateZipMatch = lastPart.match(/([A-Z]{2})\s+(\d{5}(?:-\d{4})?)/);
      
      if (stateZipMatch) {
        // Last part is "State Zip" or "City State Zip"
        state = stateZipMatch[1];
        zip = stateZipMatch[2];
        
        // Get city from last part (before state)
        city = lastPart.substring(0, lastPart.indexOf(state)).trim();
        
        // If city is empty, it's in secondLastPart
        if (!city) {
          city = secondLastPart;
          // Street is everything between name and city
          streetAddress = parts.slice(1, parts.length - 2).join(', ');
        } else {
          // Street is everything between name and last part
          streetAddress = parts.slice(1, parts.length - 1).join(', ');
        }
      } else {
        throw new Error('Could not parse state and zip from address');
      }
    }
    
    const toAddress = {
      name: customerName,
      street1: streetAddress,
      city: city,
      state: state,
      zip: zip,
      country: 'US',
    };
    
    console.log(`   ✅ Parsed address:`);
    console.log(`      Name: ${toAddress.name}`);
    console.log(`      Street: ${toAddress.street1}`);
    console.log(`      City: ${toAddress.city}`);
    console.log(`      State: ${toAddress.state}`);
    console.log(`      Zip: ${toAddress.zip}`);
    
    // 3. Get user email
    console.log('\n3️⃣  Fetching user email...');
    let userEmail;
    let userName = customerName;
    
    try {
      const userDoc = await db.collection('users').doc(orderData.userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        userEmail = userData.email;
        if (userData.displayName) {
          userName = userData.displayName;
        } else if (userData.username) {
          userName = userData.username;
        }
      } else {
        // Try Auth
        const userRecord = await admin.auth().getUser(orderData.userId);
        userEmail = userRecord.email;
        if (userRecord.displayName) {
          userName = userRecord.displayName;
        }
      }
    } catch (error) {
      console.error('   ⚠️  Failed to get user data:', error.message);
    }
    
    if (!userEmail) {
      throw new Error('Could not retrieve user email');
    }
    
    console.log(`   ✅ User email: ${userEmail}`);
    console.log(`   ✅ User name: ${userName}`);
    
    // 4. Prepare shipping label payload
    console.log('\n4️⃣  Preparing shipping label payload...');
    
    const parcel = {
      length: '8',
      width: '6',
      height: '0.5',
      distance_unit: 'in',
      weight: '4.9',
      mass_unit: 'oz',
    };
    
    const lambdaOrderId = `ORDER-${orderId}`;
    
    const payload = {
      to_address: toAddress,
      parcel: parcel,
      order_id: lambdaOrderId,
      customer_name: userName,
      customer_email: userEmail,
    };
    
    console.log(`   ✅ Payload prepared`);
    
    // 5. Call Lambda endpoint
    console.log('\n5️⃣  Calling shipping label service...');
    console.log(`   Endpoint: ${LAMBDA_ENDPOINT}`);
    console.log(`   Order ID: ${lambdaOrderId}`);
    
    const axios = axiosLib.default || axiosLib;
    const response = await axios.post(LAMBDA_ENDPOINT, payload, {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    });
    
    if (response.status !== 200) {
      throw new Error(`Label service returned status ${response.status}: ${JSON.stringify(response.data)}`);
    }
    
    const result = response.data;
    console.log(`   ✅ Response received`);
    console.log(`   Response data:`, JSON.stringify(result, null, 2));
    
    // Check if response has success field
    if (!result.success) {
      throw new Error(`Label creation failed: ${result.error || 'Unknown error'}`);
    }
    
    // 6. Update order with label data
    console.log('\n6️⃣  Updating order document...');
    
    const updateData = {
      'shippingLabels.created': true,
      'shippingLabels.status': 'success',
      'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Only add fields that exist
    if (result.outbound_label) {
      if (result.outbound_label.label_url) {
        updateData['shippingLabels.outbound.labelUrl'] = result.outbound_label.label_url;
      }
      if (result.outbound_label.tracking_number) {
        updateData['shippingLabels.outbound.trackingNumber'] = result.outbound_label.tracking_number;
      }
    }
    if (result.return_label) {
      if (result.return_label.label_url) {
        updateData['shippingLabels.return.labelUrl'] = result.return_label.label_url;
      }
      if (result.return_label.tracking_number) {
        updateData['shippingLabels.return.trackingNumber'] = result.return_label.tracking_number;
      }
    }
    
    await orderDoc.ref.update(updateData);
    
    console.log(`   ✅ Order updated`);
    
    // 7. Success summary
    console.log('\n' + '━'.repeat(70));
    console.log('✅ SHIPPING LABELS CREATED SUCCESSFULLY');
    console.log('━'.repeat(70));
    if (result.outbound_label) {
      console.log(`\nOUTBOUND LABEL (To Customer):`);
      if (result.outbound_label.tracking_number) {
        console.log(`  Tracking: ${result.outbound_label.tracking_number}`);
      }
      if (result.outbound_label.label_url) {
        console.log(`  Label: ${result.outbound_label.label_url}`);
      }
      if (result.outbound_label.service) {
        console.log(`  Service: ${result.outbound_label.service}`);
      }
      if (result.outbound_label.rate) {
        console.log(`  Rate: $${result.outbound_label.rate}`);
      }
    }
    if (result.return_label) {
      console.log(`\nRETURN LABEL (Back to Warehouse):`);
      if (result.return_label.tracking_number) {
        console.log(`  Tracking: ${result.return_label.tracking_number}`);
      }
      if (result.return_label.label_url) {
        console.log(`  Label: ${result.return_label.label_url}`);
      }
      if (result.return_label.service) {
        console.log(`  Service: ${result.return_label.service}`);
      }
      if (result.return_label.rate) {
        console.log(`  Rate: $${result.return_label.rate}`);
      }
    }
    console.log('\n' + '━'.repeat(70));
    console.log('');
    
  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
    
    // Log to failed_label_creations
    try {
      await db.collection('failed_label_creations').add({
        orderId: orderId,
        error: error.message,
        stack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        manualRetry: true,
      });
      console.log('   Logged to failed_label_creations collection');
    } catch (logError) {
      console.error('   Failed to log error:', logError.message);
    }
    
    console.log('');
    process.exit(1);
  }
  
  process.exit(0);
}

// Get order ID from command line
const orderId = process.argv[2];

if (!orderId) {
  console.error('❌ Usage: node retry_shipping_labels.js <order-id>');
  process.exit(1);
}

createShippingLabels(orderId);

