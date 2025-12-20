const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// SendGrid API for sending emails (you already use this in Lambda)
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY || '';

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
 * Send email notification to curator when they're chosen using SendGrid
 * @param {string} curatorId - The curator's user ID
 * @param {string} orderId - The order ID
 */
async function notifyCuratorByEmail(curatorId, orderId) {
  try {
    // Get curator's email and name from Firestore
    const curatorDoc = await db.collection('users').doc(curatorId).get();
    
    if (!curatorDoc.exists) {
      console.log(`⚠️ Curator ${curatorId} not found in database`);
      return;
    }
    
    const curatorData = curatorDoc.data();
    const curatorEmail = curatorData.email;
    const curatorName = curatorData.username || 'Curator';
    
    if (!curatorEmail) {
      console.log(`⚠️ No email found for curator ${curatorId}`);
      return;
    }
    
    if (!SENDGRID_API_KEY) {
      console.log(`⚠️ SendGrid API key not configured`);
      return;
    }
    
    // Simple, straightforward email using SendGrid API
    const emailData = {
      personalizations: [{
        to: [{ email: curatorEmail }],
        subject: 'A user has chosen you to curate an album'
      }],
      from: {
        email: 'no-reply@dissonanthq.com',
        name: 'Dissonant'
      },
      content: [{
        type: 'text/plain',
        value: `Hi ${curatorName},\n\nA user has chosen you to curate an album for them. Open the app to pick them something great!\n\nHappy curating!\n- Dissonant Team`
      }, {
        type: 'text/html',
        value: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <p>Hi ${curatorName},</p>
          <p>A user has chosen you to curate an album for them. Open the app to pick them something great!</p>
          <p>Happy curating!</p>
          <p>- Dissonant Team</p>
        </div>`
      }]
    };
    
    const response = await axios.post('https://api.sendgrid.com/v3/mail/send', emailData, {
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log(`✅ Curator notification email sent to ${curatorEmail} via SendGrid`);
    
  } catch (error) {
    console.error(`❌ Failed to send curator notification email: ${error.message}`);
    // Don't throw - we don't want to fail the order creation if email fails
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

      // Send email notification to curator if one was assigned
      if (orderData.curatorId) {
        console.log(`📧 Sending curator notification email to curator: ${orderData.curatorId}`);
        await notifyCuratorByEmail(orderData.curatorId, orderId);
      }

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

/**
 * Sends a SendGrid email using v3 API.
 * This project already uses SendGrid via axios elsewhere in this file.
 */
async function sendSendGridEmail({ to, fromEmail, fromName, subject, text, html }) {
  if (!SENDGRID_API_KEY) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'SendGrid API key not configured (SENDGRID_API_KEY).'
    );
  }

  const emailData = {
    personalizations: [{ to: [{ email: to }], subject }],
    from: { email: fromEmail, name: fromName },
    content: [
      { type: 'text/plain', value: text },
      { type: 'text/html', value: html },
    ],
  };

  await axios.post('https://api.sendgrid.com/v3/mail/send', emailData, {
    headers: {
      Authorization: `Bearer ${SENDGRID_API_KEY}`,
      'Content-Type': 'application/json',
    },
  });
}

/**
 * Callable used by the Flutter registration flow to send a branded verification email.
 *
 * IMPORTANT:
 * - Uses Firebase Admin to generate a real email verification link.
 * - Requires the caller to be authenticated (the registering user).
 *
 * Environment variables (optional):
 * - EMAIL_VERIFICATION_CONTINUE_URL: where Firebase should continue after verification
 * - VERIFICATION_FROM_EMAIL / VERIFICATION_FROM_NAME: SendGrid "from"
 */
exports.sendCustomEmailVerification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const email = (data && typeof data.email === 'string' ? data.email.trim() : '') ||
    (context.auth.token && typeof context.auth.token.email === 'string' ? context.auth.token.email.trim() : '');
  const displayName = data && typeof data.displayName === 'string' ? data.displayName.trim() : '';

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing email.');
  }

  const continueUrl = process.env.EMAIL_VERIFICATION_CONTINUE_URL || 'https://dissonanthq.com';

  // handleCodeInApp=true is recommended for mobile flows (Firebase will use the app, if configured).
  const actionCodeSettings = {
    url: continueUrl,
    handleCodeInApp: true,
  };

  // Generate a real Firebase email verification link for this email address.
  const verificationLink = await admin.auth().generateEmailVerificationLink(email, actionCodeSettings);

  const safeName = displayName || 'Music Lover';
  const subject = 'Verify your email for Dissonant';
  const text = `Hi ${safeName},

Thanks for joining Dissonant! Please verify your email address using this link:
${verificationLink}

If you didn’t create this account, you can ignore this email.

- Dissonant Team`;

  const html = `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h2 style="margin: 0 0 12px 0;">Hi ${safeName},</h2>
  <p style="margin: 0 0 12px 0;">Thanks for joining Dissonant! Please verify your email address by clicking the button below:</p>
  <p style="margin: 18px 0;">
    <a href="${verificationLink}" style="background-color:#E46A14;color:#fff;padding:12px 18px;border-radius:6px;text-decoration:none;display:inline-block;">
      Verify Email
    </a>
  </p>
  <p style="margin: 0 0 6px 0; color: #666;">If the button doesn’t work, paste this link into your browser:</p>
  <p style="word-break: break-all; font-family: monospace; font-size: 12px; background: #f4f4f4; padding: 10px; border-radius: 6px;">
    ${verificationLink}
  </p>
  <p style="margin: 18px 0 0 0; color: #888;">If you didn’t create this account, you can ignore this email.</p>
  <p style="margin: 10px 0 0 0;">- Dissonant Team</p>
</div>`;

  const fromEmail = process.env.VERIFICATION_FROM_EMAIL || 'no-reply@dissonanthq.com';
  const fromName = process.env.VERIFICATION_FROM_NAME || 'Dissonant';

  await sendSendGridEmail({
    to: email,
    fromEmail,
    fromName,
    subject,
    text,
    html,
  });

  return { success: true };
});

/**
 * Admin-only callable: manually mark a user's email as verified by email address.
 *
 * Security: requires a custom claim `admin: true` on the caller.
 */
exports.adminVerifyUserEmailByEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }
  if (!context.auth.token || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required.');
  }

  const email = data && typeof data.email === 'string' ? data.email.trim() : '';
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing email.');
  }

  const userRecord = await admin.auth().getUserByEmail(email);
  if (userRecord.emailVerified) {
    return { success: true, uid: userRecord.uid, emailVerified: true, alreadyVerified: true };
  }

  await admin.auth().updateUser(userRecord.uid, { emailVerified: true });
  return { success: true, uid: userRecord.uid, emailVerified: true, alreadyVerified: false };
});

