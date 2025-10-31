const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Lambda endpoint URL
const LAMBDA_ENDPOINT = 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels';

/**
 * Helper function to parse address string into components
 * Handles two formats:
 * 1. Newline-separated: "Name\nStreet\nCity, State Zip"
 * 2. Comma-separated: "Name, Street, City, State Zip"
 */
function parseAddress(addressString) {
  try {
    let name, street, city, state, zip;

    // Try newline-separated format first
    const lines = addressString.split('\n');
    
    if (lines.length >= 3) {
      // Format: "Name\nStreet\nCity, State Zip"
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
      // Try comma-separated format: "Name, Street, City, State Zip"
      const parts = addressString.split(', ');
      
      if (parts.length >= 4) {
        name = parts[0].trim();
        street = parts[1].trim();
        city = parts[2].trim();
        
        // Last part should be "State Zip"
        const stateZip = parts[3].split(' ');
        if (stateZip.length >= 2) {
          state = stateZip[0].trim();
          zip = stateZip.slice(1).join(' ').trim();
        }
      }
    }

    // Validate all required fields are present
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
 * Helper function to call Lambda endpoint with retry logic
 */
async function createShippingLabelsWithRetry(payload, maxRetries = 3) {
  let lastError;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`Attempt ${attempt}/${maxRetries} - Creating shipping labels for order ${payload.order_id}`);
      
      const response = await axios.post(LAMBDA_ENDPOINT, payload, {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 30000, // 30 second timeout
      });

      if (response.status === 200 && response.data.success) {
        console.log(`✅ Shipping labels created successfully on attempt ${attempt}`);
        return {
          success: true,
          data: response.data,
        };
      } else {
        throw new Error(`Lambda returned non-success: ${response.status} - ${JSON.stringify(response.data)}`);
      }
    } catch (error) {
      lastError = error;
      console.error(`❌ Attempt ${attempt} failed:`, error.message);
      
      if (attempt < maxRetries) {
        // Exponential backoff: 2s, 4s, 8s
        const waitTime = Math.pow(2, attempt) * 1000;
        console.log(`⏳ Waiting ${waitTime}ms before retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }

  // All retries failed
  console.error(`❌ All ${maxRetries} attempts failed. Last error:`, lastError.message);
  return {
    success: false,
    error: lastError.message,
  };
}

/**
 * Cloud Function triggered when an order is created
 * Automatically creates shipping labels via Lambda endpoint
 */
exports.onCreateOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const orderId = context.params.orderId;
    const orderData = snap.data();
    
    console.log(`📦 Order created: ${orderId}`);
    console.log('Order data:', JSON.stringify(orderData, null, 2));

    // Wait 2 seconds to let client-side attempt finish first (prevents race condition)
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Re-read the order document to check if client-side already created labels
    const updatedOrderDoc = await snap.ref.get();
    const updatedOrderData = updatedOrderDoc.data();
    
    // Check if shipping labels already exist (prevent duplicate creation)
    if (updatedOrderData.shippingLabels && updatedOrderData.shippingLabels.created === true) {
      console.log('✅ Shipping labels already exist for this order (likely created by client), skipping');
      return null;
    }

    // Check if label creation is already in progress
    if (updatedOrderData.shippingLabels && updatedOrderData.shippingLabels.status === 'creating') {
      console.log('⚠️ Shipping label creation already in progress, skipping');
      return null;
    }

    // Validate required fields
    if (!orderData.userId) {
      console.error('❌ Missing userId in order data');
      return null;
    }

    if (!orderData.address) {
      console.error('❌ Missing address in order data');
      return null;
    }

    try {
      // Mark label creation as in progress
      await snap.ref.update({
        'shippingLabels.status': 'creating',
        'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });

      // Parse address
      let toAddress;
      try {
        toAddress = parseAddress(orderData.address);
        console.log('✅ Parsed address:', JSON.stringify(toAddress, null, 2));
      } catch (parseError) {
        console.error('❌ Failed to parse address:', parseError);
        await snap.ref.update({
          'shippingLabels.status': 'failed',
          'shippingLabels.error': `Address parsing failed: ${parseError.message}`,
          'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      // Get user email
      let userEmail;
      let customerName = toAddress.name;
      
      try {
        const userDoc = await db.collection('users').doc(orderData.userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          userEmail = userData.email;
          
          // Use user's display name if available
          if (userData.displayName) {
            customerName = userData.displayName;
          } else if (userData.name) {
            customerName = userData.name;
          }
        } else {
          // Try to get email from Auth
          try {
            const userRecord = await admin.auth().getUser(orderData.userId);
            userEmail = userRecord.email;
            if (userRecord.displayName) {
              customerName = userRecord.displayName;
            }
          } catch (authError) {
            console.error('❌ Failed to get user from Auth:', authError);
          }
        }
      } catch (userError) {
        console.error('❌ Failed to get user data:', userError);
      }

      if (!userEmail) {
        console.error('❌ Could not retrieve user email');
        await snap.ref.update({
          'shippingLabels.status': 'failed',
          'shippingLabels.error': 'Could not retrieve user email',
          'shippingLabels.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      console.log(`✅ Retrieved user email: ${userEmail}`);

      // Parcel dimensions (6x8 inches, 4.9 oz)
      const parcel = {
        length: '8',
        width: '6',
        height: '0.5',
        distance_unit: 'in',
        weight: '4.9',
        mass_unit: 'oz',
      };

      // Create order ID for Lambda (use Firestore order ID)
      // This matches what client-side uses when orderId is provided
      const lambdaOrderId = `ORDER-${orderId}`;

      // Prepare payload for Lambda
      const payload = {
        to_address: toAddress,
        parcel: parcel,
        order_id: lambdaOrderId,
        customer_name: customerName,
        customer_email: userEmail,
      };

      console.log('🚀 Calling Lambda endpoint to create shipping labels...');
      console.log('Payload:', JSON.stringify(payload, null, 2));

      // Call Lambda with retry logic
      const result = await createShippingLabelsWithRetry(payload, 3);

      if (result.success) {
        // Update order with shipping label information
        const labelData = result.data;
        await snap.ref.update({
          'shippingLabels': {
            created: true,
            status: 'success',
            orderId: lambdaOrderId,
            outboundLabel: labelData.outbound_label || null,
            returnLabel: labelData.return_label || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });

        console.log('✅ Shipping labels created and stored in order document');
        console.log('Outbound tracking:', labelData.outbound_label?.tracking_number);
        console.log('Return tracking:', labelData.return_label?.tracking_number);
      } else {
        // Update order with error information
        await snap.ref.update({
          'shippingLabels': {
            created: false,
            status: 'failed',
            error: result.error,
            attemptCount: 3,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });

        console.error('❌ Failed to create shipping labels after all retries');
        
        // Log to a separate collection for monitoring
        await db.collection('failed_label_creations').add({
          orderId: orderId,
          userId: orderData.userId,
          error: result.error,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          orderData: {
            address: orderData.address,
            status: orderData.status,
          },
        });
      }

      return null;
    } catch (error) {
      console.error('❌ Unexpected error in onCreateOrder:', error);
      console.error('Stack trace:', error.stack);

      // Update order with error
      try {
        await snap.ref.update({
          'shippingLabels': {
            created: false,
            status: 'failed',
            error: `Unexpected error: ${error.message}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });
      } catch (updateError) {
        console.error('❌ Failed to update order with error:', updateError);
      }

      // Log to failed_label_creations collection
      try {
        await db.collection('failed_label_creations').add({
          orderId: orderId,
          userId: orderData.userId,
          error: error.message,
          stack: error.stack,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (logError) {
        console.error('❌ Failed to log error:', logError);
      }

      // Don't throw - we don't want to retry the entire function
      return null;
    }
  });

