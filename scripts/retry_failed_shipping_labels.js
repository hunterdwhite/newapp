#!/usr/bin/env node

/**
 * Retry Failed Shipping Labels Script
 * 
 * This script retries shipping label creation for orders that failed or never got labels.
 * Perfect for recovering from payment issues or service disruptions.
 * 
 * PREREQUISITES:
 *   Must be run from the project root directory or functions directory
 *   Requires firebase-admin and axios (installed via functions/node_modules)
 * 
 * USAGE:
 *   cd functions
 *   node ../scripts/retry_failed_shipping_labels.js [--dry-run] [--order-id=ORDER_ID]
 * 
 * OPTIONS:
 *   --dry-run       Preview what would be processed without actually creating labels
 *   --order-id      Process a specific order ID only (e.g., --order-id=abc123)
 * 
 * EXAMPLES:
 *   # Preview all orders that need labels (recommended first step)
 *   cd functions && node ../scripts/retry_failed_shipping_labels.js --dry-run
 * 
 *   # Actually create labels for all failed orders
 *   cd functions && node ../scripts/retry_failed_shipping_labels.js
 * 
 *   # Retry a specific order only
 *   cd functions && node ../scripts/retry_failed_shipping_labels.js --order-id=abc123
 * 
 * WHAT IT DOES:
 *   1. Queries Firestore for orders without shipping labels (shippingLabels.created != true)
 *   2. For each order, parses the address and retrieves user email
 *   3. Calls the Lambda endpoint to create shipping labels
 *   4. Updates the order document with the shipping label URLs and tracking numbers
 *   5. Provides a summary of successes and failures
 */

// Resolve dependencies from functions directory
const path = require('path');
const functionsDir = path.join(__dirname, '..', 'functions');
const admin = require(path.join(functionsDir, 'node_modules', 'firebase-admin'));
const axiosModule = require(path.join(functionsDir, 'node_modules', 'axios'));
const axios = axiosModule.default || axiosModule;

// Initialize Firebase Admin (uses service account key in scripts folder)
if (!admin.apps.length) {
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin initialized with service account\n');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin. Make sure serviceAccountKey.json exists in scripts folder.');
    throw error;
  }
}

const db = admin.firestore();

// Lambda endpoint URL
const LAMBDA_ENDPOINT = 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels';

/**
 * Parse address string into components
 * Handles both newline-separated and comma-separated formats
 */
function parseAddress(addressString) {
  try {
    let name, street, city, state, zip;

    // Try newline-separated format first
    const lines = addressString.split('\n');
    
    if (lines.length >= 3) {
      name = lines[0].trim();
      street = lines[1].trim();
      const cityStateZip = lines[2].split(', ');
      
      if (cityStateZip.length >= 2) {
        city = cityStateZip[0].trim();
        const stateZip = cityStateZip[1].split(' ');
        
        if (stateZip.length >= 2) {
          state = stateZip[0].trim();
          zip = stateZip.slice(1).join(' ').trim();
        }
      }
    } else {
      // Try comma-separated format
      const parts = addressString.split(', ');
      
      if (parts.length >= 4) {
        name = parts[0].trim();
        street = parts[1].trim();
        city = parts[2].trim();
        
        const stateZip = parts[3].split(' ');
        if (stateZip.length >= 2) {
          state = stateZip[0].trim();
          zip = stateZip.slice(1).join(' ').trim();
        }
      }
    }

    if (!name || !street || !city || !state || !zip) {
      throw new Error(`Missing required address fields. Got: name="${name}", street="${street}", city="${city}", state="${state}", zip="${zip}"`);
    }

    return {
      name,
      street1: street,
      city,
      state,
      zip,
      country: 'US',
    };
  } catch (error) {
    console.error('Error parsing address:', error);
    console.error('Address string was:', addressString);
    throw error;
  }
}

/**
 * Create shipping labels for an order
 */
async function createShippingLabel(orderId, orderData) {
  console.log(`\n📦 Processing order: ${orderId}`);
  
  try {
    // Validate required fields
    if (!orderData.userId) {
      throw new Error('Missing userId in order data');
    }

    if (!orderData.address) {
      throw new Error('Missing address in order data');
    }

    // Parse address
    const toAddress = parseAddress(orderData.address);
    console.log('  ✅ Parsed address:', toAddress.name, toAddress.city, toAddress.state);

    // Get user email
    let userEmail;
    let customerName = toAddress.name;
    
    const userDoc = await db.collection('users').doc(orderData.userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      userEmail = userData.email;
      
      if (userData.displayName) {
        customerName = userData.displayName;
      } else if (userData.name) {
        customerName = userData.name;
      }
    } else {
      // Try to get email from Auth
      const userRecord = await admin.auth().getUser(orderData.userId);
      userEmail = userRecord.email;
      if (userRecord.displayName) {
        customerName = userRecord.displayName;
      }
    }

    if (!userEmail) {
      throw new Error('Could not retrieve user email');
    }

    console.log(`  ✅ Retrieved user email: ${userEmail}`);

    // Parcel dimensions (6x8 inches, 4.9 oz)
    const parcel = {
      length: '8',
      width: '6',
      height: '0.5',
      distance_unit: 'in',
      weight: '4.9',
      mass_unit: 'oz',
    };

    // Create order ID for Lambda
    const lambdaOrderId = `ORDER-${orderId}`;

    // Prepare payload for Lambda
    const payload = {
      to_address: toAddress,
      parcel: parcel,
      order_id: lambdaOrderId,
      customer_name: customerName,
      customer_email: userEmail,
    };

    console.log('  🚀 Calling Lambda endpoint...');

    // Call Lambda endpoint
    const response = await axios.post(LAMBDA_ENDPOINT, payload, {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000, // 30 second timeout
    });

    if (response.status === 200 && response.data.success) {
      console.log('  ✅ Shipping labels created successfully!');
      console.log('  Response data:', JSON.stringify(response.data, null, 2));
      
      // Update order document with shipping label info
      const outboundLabel = response.data.outbound_label;
      const returnLabel = response.data.return_label;
      
      await db.collection('orders').doc(orderId).update({
        'shippingLabels.created': true,
        'shippingLabels.status': 'success',
        'shippingLabels.outboundLabel': {
          label_url: outboundLabel.label_url,
          tracking_number: outboundLabel.tracking_number,
          rate: outboundLabel.rate,
          service: outboundLabel.service,
          status: outboundLabel.status,
          transaction_id: outboundLabel.transaction_id
        },
        'shippingLabels.returnLabel': {
          label_url: returnLabel.label_url,
          tracking_number: returnLabel.tracking_number,
          rate: returnLabel.rate,
          service: returnLabel.service,
          status: returnLabel.status,
          transaction_id: returnLabel.transaction_id,
          billing_method: returnLabel.billing_method
        },
        'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        'shippingLabels.createdBy': 'retry-script',
      });
      
      return { success: true };
    } else {
      throw new Error(response.data.error || 'Unknown error from Lambda');
    }
  } catch (error) {
    console.error(`  ❌ Failed to create shipping label: ${error.message}`);
    
    // Update order document with error
    try {
      await db.collection('orders').doc(orderId).update({
        'shippingLabels.status': 'failed',
        'shippingLabels.error': error.message,
        'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (updateError) {
      console.error(`  ❌ Failed to update order with error: ${updateError.message}`);
    }
    
    return { success: false, error: error.message };
  }
}

/**
 * Main function
 */
async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const orderIdArg = args.find(arg => arg.startsWith('--order-id='));
  const specificOrderId = orderIdArg ? orderIdArg.split('=')[1] : null;
  const limitArg = args.find(arg => arg.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1]) : null;
  
  if (dryRun) {
    console.log('🔍 DRY RUN MODE - No labels will be created\n');
  }
  
  if (limit) {
    console.log(`⚠️  LIMIT MODE - Will only process first ${limit} order(s)\n`);
  }
  
  if (specificOrderId) {
    console.log(`🎯 Processing specific order: ${specificOrderId}\n`);
  } else {
    console.log('🔍 Searching for orders (new, curator_assigned, ready_to_ship) without shipping labels or with failed labels...\n');
  }
  
  try {
    let ordersSnapshot;
    
    if (specificOrderId) {
      // Query specific order
      console.log(`Looking up order document: ${specificOrderId}`);
      const orderDoc = await db.collection('orders').doc(specificOrderId).get();
      console.log(`Order exists: ${orderDoc.exists}`);
      if (!orderDoc.exists) {
        console.log(`❌ Order ${specificOrderId} not found!`);
        return;
      }
      console.log(`Found order: ${orderDoc.id}, status: ${orderDoc.data()?.status}`);
      ordersSnapshot = { docs: [orderDoc], empty: false, size: 1 };
    } else {
      // Query for orders with status: new, curator_assigned, or ready_to_ship
      const statuses = ['new', 'curator_assigned', 'ready_to_ship'];
      const allOrdersPromises = statuses.map(status => 
        db.collection('orders').where('status', '==', status).get()
      );
      
      const allOrdersResults = await Promise.all(allOrdersPromises);
      const allOrdersDocs = allOrdersResults.flatMap(snapshot => snapshot.docs);
      
      console.log(`Found ${allOrdersDocs.length} total orders with status: ${statuses.join(', ')}`);
      console.log('Checking each order for missing or failed labels...\n');
      
      // Filter for orders without shipping labels OR with failed labels
      const docsWithoutLabels = allOrdersDocs.filter(doc => {
        const data = doc.data();
        
        // Debug: Log what we're seeing for each order
        console.log(`  Checking order ${doc.id}:`);
        console.log(`    - shippingLabels.outboundLabel.status: ${data.shippingLabels?.outboundLabel?.status}`);
        console.log(`    - shippingLabels.returnLabel.status: ${data.shippingLabels?.returnLabel?.status}`);
        console.log(`    - shippingLabels.created: ${data.shippingLabels?.created}`);
        console.log(`    - shippingLabels.status: ${data.shippingLabels?.status}`);
        
        // Check if labels exist but have ERROR status (check this FIRST)
        // Labels are nested under shippingLabels.outboundLabel.status
        const outboundFailed = data.shippingLabels?.outboundLabel?.status === 'ERROR' || 
                               data.shippingLabels?.outboundLabel?.label_url?.includes('failed');
        const returnFailed = data.shippingLabels?.returnLabel?.status === 'ERROR' || 
                            data.shippingLabels?.returnLabel?.label_url?.includes('failed');
        
        // Check if shippingLabels.status is 'failed'
        const labelStatusFailed = data.shippingLabels?.status === 'failed';
        
        // If labels failed, definitely include this order
        if (outboundFailed || returnFailed || labelStatusFailed) {
          console.log(`    ✅ MATCH: This order has failed labels!`);
          return true;
        }
        
        // No shipping labels at all
        if (!data.shippingLabels || data.shippingLabels.created !== true) {
          console.log(`    ✅ MATCH: This order has no labels!`);
          return true;
        }
        
        console.log(`    ❌ SKIP: Labels are OK\n`);
        return false;
      });
      
      ordersSnapshot = { 
        docs: docsWithoutLabels, 
        empty: docsWithoutLabels.length === 0, 
        size: docsWithoutLabels.length 
      };
    }
    
    if (ordersSnapshot.empty) {
      console.log('✅ No orders found without shipping labels!');
      return;
    }
    
    console.log(`📋 Found ${ordersSnapshot.size} orders without shipping labels\n`);
    
    const results = {
      total: ordersSnapshot.size,
      success: 0,
      failed: 0,
      errors: []
    };
    
    // Apply limit if specified
    const ordersToProcess = limit ? ordersSnapshot.docs.slice(0, limit) : ordersSnapshot.docs;
    
    if (limit && ordersToProcess.length < ordersSnapshot.docs.length) {
      console.log(`⚠️  Processing ${ordersToProcess.length} of ${ordersSnapshot.docs.length} orders due to --limit flag\n`);
    }
    
    // Process each order
    for (const doc of ordersToProcess) {
      const orderId = doc.id;
      const orderData = doc.data();
      
      // Show order info
      console.log(`Order ID: ${orderId}`);
      console.log(`  Status: ${orderData.status || 'unknown'}`);
      console.log(`  User: ${orderData.userId}`);
      console.log(`  Address: ${orderData.address?.substring(0, 50)}...`);
      console.log(`  Current shipping label status: ${orderData.shippingLabels?.status || 'none'}`);
      
      if (dryRun) {
        console.log('  [DRY RUN] Would create shipping label for this order\n');
        results.success++;
        continue;
      }
      
      const result = await createShippingLabel(orderId, orderData);
      
      if (result.success) {
        results.success++;
      } else {
        results.failed++;
        results.errors.push({ orderId, error: result.error });
      }
      
      // Small delay between requests to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total orders processed: ${results.total}`);
    console.log(`✅ Successful: ${results.success}`);
    console.log(`❌ Failed: ${results.failed}`);
    
    if (results.errors.length > 0) {
      console.log('\n❌ Failed orders:');
      results.errors.forEach(({ orderId, error }) => {
        console.log(`  - ${orderId}: ${error}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error querying orders:', error);
    throw error;
  }
}

// Run the script
main()
  .then(() => {
    console.log('\n✅ Script completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });

