const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// SendGrid API for sending emails
// Try multiple ways to get the API key
let SENDGRID_API_KEY = '';
try {
  // First try environment variable
  if (process.env.SENDGRID_API_KEY) {
    SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
    console.log('✅ SendGrid API key loaded from environment variable');
  } 
  // Then try Firebase config
  else if (functions.config().sendgrid && functions.config().sendgrid.apikey) {
    SENDGRID_API_KEY = functions.config().sendgrid.apikey;
    console.log('✅ SendGrid API key loaded from Firebase config');
  }
  
  if (SENDGRID_API_KEY) {
    console.log(`SendGrid key starts with: ${SENDGRID_API_KEY.substring(0, 10)}...`);
  } else {
    console.log('⚠️ No SendGrid API key found');
  }
} catch (configError) {
  console.error('Error loading SendGrid config:', configError.message);
}

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
 * Send custom email verification using SendGrid
 * This generates Firebase's verification link and sends it via SendGrid
 * 
 * TEMPLATE SETUP:
 * 1. Go to SendGrid Dashboard → Email API → Dynamic Templates
 * 2. Create template with these variables: {{displayName}}, {{verificationLink}}
 * 3. Set the template ID below or in Firebase config: sendgrid.verification_template_id
 * 
 * Falls back to Firebase default if SendGrid is not configured
 */
exports.sendCustomEmailVerification = functions.https.onCall(async (data, context) => {
  const { email, displayName } = data;
  
  // Get template ID from config (set via: firebase functions:config:set sendgrid.verification_template_id="d-xxx")
  // If not set, uses inline HTML fallback
  let SENDGRID_TEMPLATE_ID = null;
  try {
    SENDGRID_TEMPLATE_ID = functions.config().sendgrid?.verification_template_id || null;
  } catch (e) {
    // Config not set, will use inline HTML
  }
  
  try {
    if (!email) {
      console.log('⚠️ No email provided');
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    
    // Log SendGrid key status
    console.log(`📧 Email verification requested for ${email}`);
    console.log(`SendGrid key configured: ${!!SENDGRID_API_KEY}`);
    console.log(`SendGrid template ID: ${SENDGRID_TEMPLATE_ID || 'not set (using inline HTML)'}`);
    
    // If SendGrid is not configured, throw immediately so app uses default Firebase email
    if (!SENDGRID_API_KEY) {
      console.log('⚠️ SendGrid API key not configured, using Firebase default');
      throw new functions.https.HttpsError('failed-precondition', 'Use default');
    }
    
    // Generate Firebase's official verification link
    let verificationLink;
    try {
      verificationLink = await admin.auth().generateEmailVerificationLink(email);
      console.log(`✅ Generated verification link for ${email}`);
    } catch (linkError) {
      console.error('❌ Failed to generate verification link:', linkError.message);
      throw new functions.https.HttpsError('internal', 'Use default');
    }
    
    // Build email request - use template if configured, otherwise inline HTML
    let emailData;
    
    if (SENDGRID_TEMPLATE_ID) {
      // Use SendGrid Dynamic Template (editable in SendGrid UI)
      emailData = {
        personalizations: [{
          to: [{ email: email }],
          dynamic_template_data: {
            displayName: displayName || 'Music Lover',
            verificationLink: verificationLink,
            email: email
          }
        }],
        from: {
          email: 'no-reply@dissonanthq.com',
          name: 'Dissonant'
        },
        template_id: SENDGRID_TEMPLATE_ID
      };
      console.log(`📨 Using SendGrid template: ${SENDGRID_TEMPLATE_ID}`);
    } else {
      // Fallback: Inline HTML (requires code deploy to change)
      emailData = {
        personalizations: [{
          to: [{ email: email }],
          subject: 'Welcome to Dissonant - Verify Your Email'
        }],
        from: {
          email: 'no-reply@dissonanthq.com',
          name: 'Dissonant'
        },
        content: [{
          type: 'text/plain',
          value: `Welcome to Dissonant!\n\nHi ${displayName || 'Music Lover'}!\n\nPlease verify your email: ${verificationLink}\n\n- The Dissonant Team`
        }, {
          type: 'text/html',
          value: `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background-color:#1a1a1a;">
<table style="width:100%;border-collapse:collapse;"><tr><td style="padding:40px 20px;text-align:center;">
<table style="max-width:600px;margin:0 auto;background-color:#000;border-radius:8px;overflow:hidden;box-shadow:0 4px 20px rgba(228,106,20,0.3);">
<tr><td style="background:linear-gradient(135deg,#E46A14 0%,#D24407 100%);padding:40px 20px;text-align:center;">
<h1 style="color:white;margin:0;font-size:32px;font-weight:bold;letter-spacing:2px;">DISSONANT</h1>
<p style="color:rgba(255,255,255,0.9);margin:10px 0 0 0;font-size:14px;">DIY Music Discovery</p>
</td></tr>
<tr><td style="padding:40px 30px;background-color:#1a1a1a;">
<h2 style="color:#fff;margin:0 0 20px 0;font-size:24px;">Hi ${displayName || 'Music Lover'}!</h2>
<p style="color:#ccc;line-height:1.6;margin:0 0 20px 0;font-size:16px;">Thanks for joining Dissonant! We're excited to help you discover incredible music curated specifically for your taste.</p>
<p style="color:#ccc;line-height:1.6;margin:0 0 30px 0;font-size:16px;">To get started, please verify your email address:</p>
<table style="margin:0 auto 30px auto;"><tr><td style="text-align:center;">
<a href="${verificationLink}" style="background:linear-gradient(135deg,#E46A14 0%,#D24407 100%);color:white;padding:16px 40px;text-decoration:none;border-radius:6px;font-weight:bold;display:inline-block;font-size:16px;">Verify Email Address</a>
</td></tr></table>
<p style="color:#888;line-height:1.6;margin:20px 0;font-size:13px;">If the button doesn't work, copy and paste this link:</p>
<p style="word-break:break-all;background-color:#2a2a2a;padding:15px;border-radius:4px;font-family:monospace;font-size:11px;color:#E46A14;border:1px solid #333;">${verificationLink}</p>
<div style="border-top:1px solid #333;margin:30px 0;padding-top:20px;">
<p style="color:#ccc;line-height:1.6;margin:0;font-size:14px;"><strong style="color:#E46A14;">What's next?</strong><br>Complete a quick taste profile so we can curate the perfect albums for you!</p>
</div></td></tr>
<tr><td style="background-color:#0a0a0a;padding:25px 30px;text-align:center;border-top:1px solid #333;">
<p style="color:#666;font-size:12px;margin:0;line-height:1.5;">This email was sent by Dissonant<br>If you didn't create an account, please ignore this email.</p>
</td></tr></table></td></tr></table></body></html>`
        }]
      };
      console.log(`📨 Using inline HTML template`);
    }
    
    const response = await axios.post('https://api.sendgrid.com/v3/mail/send', emailData, {
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log(`✅ Verification email sent to ${email} via SendGrid`);
    return { success: true };
    
  } catch (error) {
    console.error(`❌ Failed to send verification email: ${error.message}`);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Use default');
  }
});

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
    
    // ENHANCED: Comprehensive check for existing shipping labels (prevent duplicate creation)
    const shippingLabels = updatedOrderData.shippingLabels;
    
    if (shippingLabels) {
      // Check 1: Labels marked as created
      if (shippingLabels.created === true) {
        console.log('✅ Shipping labels already exist (created=true), skipping duplicate creation');
        return null;
      }
      
      // Check 2: Labels with success status
      if (shippingLabels.status === 'success') {
        console.log('✅ Shipping labels already exist (status=success), skipping duplicate creation');
        return null;
      }
      
      // Check 3: Label creation already in progress
      if (shippingLabels.status === 'creating') {
        console.log('⚠️ Shipping label creation already in progress, skipping duplicate creation');
        return null;
      }
      
      // Check 4: Outbound label with tracking number exists
      if (shippingLabels.outboundLabel?.tracking_number) {
        console.log(`✅ Outbound label tracking number already exists (${shippingLabels.outboundLabel.tracking_number}), skipping duplicate creation`);
        return null;
      }
      
      // Check 5: Outbound label URL exists
      if (shippingLabels.outboundLabel?.label_url && !shippingLabels.outboundLabel.label_url.includes('failed')) {
        console.log(`✅ Outbound label URL already exists, skipping duplicate creation`);
        return null;
      }
      
      // Check 6: Return label with tracking number exists
      if (shippingLabels.returnLabel?.tracking_number) {
        console.log(`✅ Return label tracking number already exists (${shippingLabels.returnLabel.tracking_number}), skipping duplicate creation`);
        return null;
      }
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

      // FINAL SAFETY CHECK: Re-verify no labels were created during processing
      console.log('🔒 Final safety check before calling Lambda...');
      const finalCheck = await snap.ref.get();
      const finalCheckData = finalCheck.data();
      const finalLabels = finalCheckData.shippingLabels;
      
      if (finalLabels) {
        if (finalLabels.created === true || finalLabels.status === 'success') {
          console.log('🛑 DUPLICATE PREVENTED: Labels were created by another process during execution');
          return null;
        }
        if (finalLabels.outboundLabel?.tracking_number || finalLabels.returnLabel?.tracking_number) {
          console.log('🛑 DUPLICATE PREVENTED: Tracking numbers detected from another process');
          return null;
        }
      }
      
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

// ============================================================================
// DISCOGS NIGHTLY SYNC - Syncs Discogs collection to Firestore inventory
// ============================================================================

const DISCOGS_TOKEN = process.env.DISCOGS_TOKEN || functions.config().discogs?.token || '';
const DISCOGS_USERNAME = process.env.DISCOGS_USERNAME || functions.config().discogs?.username || '';
const REQUEST_DELAY_MS = 1100;

/**
 * Delays execution for a given number of milliseconds.
 * Useful for throttling API requests to avoid rate limits.
 *
 * @param {number} ms - The number of milliseconds to wait.
 * @return {Promise<void>} A promise that resolves after the delay.
 */
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Fetches the user's full Discogs collection from folder 0 (All).
 * Handles pagination to get all releases.
 * @return {Promise<Array>} List of collected releases.
 */
async function getDiscogsCollection() {
  let allReleases = [];
  let page = 1;
  let hasMorePages = true;

  while (hasMorePages) {
    const url =
      `https://api.discogs.com/users/${DISCOGS_USERNAME}/collection/folders/0/releases` +
      `?token=${DISCOGS_TOKEN}&per_page=100&page=${page}`;

    console.log(`Fetching Discogs collection page ${page}...`);

    const res = await axios.get(url);

    // Log API response structure for debugging
    if (page === 1) {
      console.log(`📊 API Response structure:`, {
        totalItems: res.data.pagination?.items || 'unknown',
        totalPages: res.data.pagination?.pages || 'unknown',
        itemsOnThisPage: res.data.releases?.length || 0,
        sampleItem: res.data.releases?.[0] ? {
          hasBasicInfo: !!res.data.releases[0].basic_information,
          hasId: !!res.data.releases[0].basic_information?.id,
          id: res.data.releases[0].basic_information?.id,
          title: res.data.releases[0].basic_information?.title
        } : 'no items'
      });
    }

    const releases = res.data.releases;
    allReleases = allReleases.concat(releases);

    // Check if there are more pages
    const pagination = res.data.pagination;
    hasMorePages = page < pagination.pages;
    page++;

    // Add delay to respect rate limits
    if (hasMorePages) {
      await delay(REQUEST_DELAY_MS);
    }
  }

  console.log(`Fetched ${allReleases.length} total releases from Discogs collection`);
  return allReleases;
}

/**
 * Fetches detailed release data from Discogs for a given release ID.
 * @param {string|number} releaseId - Discogs release ID.
 * @return {Promise<Object>} Release metadata.
 */
async function fetchReleaseData(releaseId) {
  const url =
    `https://api.discogs.com/releases/${releaseId}?token=${DISCOGS_TOKEN}`;
  const res = await axios.get(url);
  return res.data;
}

/**
 * Syncs the Discogs collection into Firestore, updating or inserting
 * album documents, and maintaining inventory availability.
 * OPTIMIZED: Only fetches detailed data for NEW releases not already in inventory.
 */
async function syncAlbums() {
  if (!DISCOGS_TOKEN || !DISCOGS_USERNAME) {
    console.error('❌ Missing DISCOGS_TOKEN or DISCOGS_USERNAME environment variables');
    throw new Error('Discogs credentials not configured');
  }

  console.log(`🎵 Starting OPTIMIZED Discogs sync for user: ${DISCOGS_USERNAME}`);
  
  const collection = await getDiscogsCollection();
  console.log(`📊 Total Discogs items fetched: ${collection.length}`);

  // Track which albums we've seen in this sync to count actual quantities
  const discogsInventory = new Map();

  // First pass: count actual quantities from Discogs collection
  console.log(`🔍 Analyzing collection structure...`);
  let itemsWithoutBasicInfo = 0;
  let itemsWithoutId = 0;

  for (const item of collection) {
    // Check if item has the expected structure
    if (!item.basic_information) {
      console.log(`⚠️  Item missing basic_information:`, JSON.stringify(item, null, 2));
      itemsWithoutBasicInfo++;
      continue;
    }

    if (!item.basic_information.id) {
      console.log(`⚠️  Item missing id:`, JSON.stringify(item.basic_information, null, 2));
      itemsWithoutId++;
      continue;
    }

    const releaseId = item.basic_information.id.toString();
    const currentCount = discogsInventory.get(releaseId) || 0;
    discogsInventory.set(releaseId, currentCount + 1);
  }

  if (itemsWithoutBasicInfo > 0) {
    console.log(`⚠️  Found ${itemsWithoutBasicInfo} items without basic_information`);
  }

  if (itemsWithoutId > 0) {
    console.log(`⚠️  Found ${itemsWithoutId} items without id`);
  }

  console.log(`🎵 Total items: ${collection.length}, Unique releases: ${discogsInventory.size}`);

  // OPTIMIZATION: Load existing inventory to skip unchanged items
  console.log(`📦 Loading existing inventory to identify new releases...`);
  const existingInventorySnapshot = await db.collection("inventory").get();
  const existingInventory = new Map();
  
  existingInventorySnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.discogsId) {
      existingInventory.set(data.discogsId.toString(), {
        docId: doc.id,
        quantity: data.quantity,
        albumId: data.albumId,
      });
    }
  });
  
  console.log(`📦 Found ${existingInventory.size} items in existing inventory`);

  // Log duplicates
  const duplicates = [];
  discogsInventory.forEach((count, releaseId) => {
    if (count > 1) {
      duplicates.push(`${releaseId}: ${count} copies`);
    }
  });

  if (duplicates.length > 0) {
    console.log(`🔄 Found duplicates: ${duplicates.join(', ')}`);
  }

  // Second pass: sync albums - OPTIMIZED to skip unchanged items
  const processedReleases = new Set();
  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  let unchangedCount = 0;

  for (const item of collection) {
    // Skip items that don't have proper structure (already logged above)
    if (!item.basic_information || !item.basic_information.id) {
      continue;
    }

    const releaseId = item.basic_information.id;
    const releaseIdStr = releaseId.toString();

    // Skip if we've already processed this release in this sync
    if (processedReleases.has(releaseIdStr)) {
      skippedCount++;
      continue;
    }

    processedReleases.add(releaseIdStr);

    const actualQuantity = discogsInventory.get(releaseIdStr);
    const existingItem = existingInventory.get(releaseIdStr);

    // OPTIMIZATION: If item exists and quantity hasn't changed, just update lastUpdated
    if (existingItem && existingItem.quantity === actualQuantity) {
      // Just update the lastUpdated timestamp without making Discogs API call
      const inventoryRef = db.collection("inventory").doc(releaseIdStr);
      await inventoryRef.update({ lastUpdated: new Date() });
      unchangedCount++;
      continue;
    }

    try {
      const isNew = !existingItem;
      const label = isNew ? '🆕 NEW' : '🔄 QTY CHANGED';
      console.log(`${label} Processing release ${releaseIdStr} (${successCount + errorCount + 1})...`);

      const release = await fetchReleaseData(releaseId);
      await delay(REQUEST_DELAY_MS);

      // Validate release data
      if (!release) {
        throw new Error('Release data is null/undefined');
      }

      if (!release.title) {
        throw new Error('Release missing title');
      }

      if (!release.artists_sort) {
        throw new Error('Release missing artists_sort');
      }

      const albumName = release.title;
      const artist = release.artists_sort;

      const matchingQuery = db
          .collection("albums")
          .where("albumName", "==", albumName)
          .where("artist", "==", artist);

      const snapshot = await matchingQuery.get();

      let albumDocRef;

      const albumData = {
        albumName,
        artist,
        coverUrl:
          release.images && release.images.length > 0 ?
            release.images[0].uri :
            "",
        discogsId: release.id,
        genres: release.genres,
        styles: release.styles,
        releaseYear: release.released ?
          release.released.split("-")[0] :
          "",
        label:
          release.labels && release.labels.length > 0 ?
            release.labels[0].name :
            "",
        country: release.country,
        updatedAt: new Date(),
      };

      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        // Exclude coverUrl from update if album exists
        const albumDataWithoutCover = (({coverUrl, ...rest}) => rest)(albumData);
        await doc.ref.set(albumDataWithoutCover, {merge: true});
        albumDocRef = doc.ref;
      } else {
        const docRef = await db.collection("albums").add({
          ...albumData,
          createdAt: new Date(),
        });
        albumDocRef = docRef;
      }

      // Update inventory with actual quantity from Discogs
      const inventoryRef = db.collection("inventory").doc(releaseIdStr);

      const inventoryData = {
        discogsId: release.id,
        albumId: albumDocRef.id,
        albumName,
        artist,
        coverUrl: albumData.coverUrl,
        releaseYear: albumData.releaseYear,
        genres: albumData.genres,
        quantity: actualQuantity, // Set to actual count from Discogs
        lastUpdated: new Date(),
      };

      // Always set the inventory data (create or overwrite)
      await inventoryRef.set(inventoryData);

      console.log(`✅ Synced: ${albumName} - ${artist} (Quantity: ${actualQuantity})`);
      successCount++;
    } catch (error) {
      console.error(`❌ Failed to sync release ${releaseIdStr}:`, error.message);
      errorCount++;
    }
  }

  console.log(`📈 Sync Summary:`);
  console.log(`   ✅ ${successCount} new/updated albums synced`);
  console.log(`   ⏭️  ${unchangedCount} unchanged (skipped API call)`);
  console.log(`   🔄 ${skippedCount} duplicates skipped`);
  console.log(`   ❌ ${errorCount} errors`);

  // Third pass: Remove inventory items that are no longer in Discogs collection
  console.log("Checking for removed items...");
  const batch = db.batch();
  let removedCount = 0;

  existingInventory.forEach((value, discogsId) => {
    // If this item is no longer in the Discogs collection, remove it
    if (!discogsInventory.has(discogsId)) {
      console.log(`Removing from inventory: ${discogsId} (no longer in Discogs)`);
      const docRef = db.collection("inventory").doc(discogsId);
      batch.delete(docRef);
      removedCount++;
    }
  });

  if (removedCount > 0) {
    await batch.commit();
    console.log(`Removed ${removedCount} items from inventory`);
  }

  console.log(`🎵 Discogs sync complete!`);
}

/**
 * Firebase Cloud Function: runs every 24 hours to sync Discogs data.
 * Using v1 functions for better compatibility with Cloud Scheduler
 */
exports.nightlyDiscogsSync = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes timeout
    memory: "512MB", // More memory for processing
  })
  .pubsub.schedule("every 24 hours")
  .timeZone("America/New_York") // Set timezone
  .onRun(async (context) => {
    console.log("Starting Discogs sync job...");
    try {
      await syncAlbums();
      console.log("Discogs sync complete.");
    } catch (error) {
      console.error("Discogs sync failed:", error);
      throw error; // Re-throw to mark the function as failed
    }
  });

// Export syncAlbums for manual testing via test-sync.js
module.exports.syncAlbums = syncAlbums;

// ============================================================================
// DAILY DELIVERY STATUS CHECK - Updates sent orders to delivered
// ============================================================================

const SHIPPO_TOKEN = process.env.SHIPPO_TOKEN || functions.config().shippo?.token || '';

/**
 * Check tracking status via Shippo API
 * @param {string} trackingNumber - The tracking number to check
 * @param {string} carrier - The carrier (default: usps)
 * @return {Promise<Object|null>} Tracking status object or null if failed
 */
async function checkTrackingStatus(trackingNumber, carrier = 'usps') {
  try {
    const response = await axios.get(
      `https://api.goshippo.com/tracks/${carrier}/${trackingNumber}`,
      {
        headers: {
          'Authorization': `ShippoToken ${SHIPPO_TOKEN}`,
        },
        timeout: 10000,
      }
    );
    return response.data;
  } catch (error) {
    console.error(`Failed to check tracking ${trackingNumber}:`, error.message);
    return null;
  }
}

/**
 * Firebase Cloud Function: runs daily to check sent orders and update delivered ones
 */
exports.dailyDeliveryCheck = functions
  .runWith({
    timeoutSeconds: 300, // 5 minutes timeout
    memory: '256MB',
  })
  .pubsub.schedule('every day 09:00')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('🚚 Starting daily delivery status check...');

    if (!SHIPPO_TOKEN) {
      console.error('❌ SHIPPO_TOKEN not configured');
      return;
    }

    try {
      // Get all orders with "sent" status
      const sentOrdersSnapshot = await db.collection('orders')
        .where('status', '==', 'sent')
        .get();

      console.log(`📦 Found ${sentOrdersSnapshot.size} orders in "sent" status`);

      if (sentOrdersSnapshot.empty) {
        console.log('✅ No sent orders to check');
        return;
      }

      let updatedCount = 0;
      let checkedCount = 0;
      let errorCount = 0;

      for (const doc of sentOrdersSnapshot.docs) {
        const data = doc.data();
        const orderId = doc.id;

        // Get tracking number from various possible locations
        const trackingNumber = data.trackingNumber || 
                              data.outboundTrackingNumber || 
                              data.shippingLabels?.outboundLabel?.tracking_number;

        if (!trackingNumber) {
          console.log(`⚠️ Order ${orderId}: No tracking number found`);
          continue;
        }

        checkedCount++;

        // Rate limit: wait between API calls
        if (checkedCount > 1) {
          await delay(500);
        }

        const trackingInfo = await checkTrackingStatus(trackingNumber);

        if (!trackingInfo) {
          errorCount++;
          continue;
        }

        const trackingStatus = trackingInfo.tracking_status?.status?.toUpperCase();

        if (trackingStatus === 'DELIVERED') {
          console.log(`📬 Order ${orderId} (${trackingNumber}): DELIVERED - updating status`);
          
          await doc.ref.update({
            status: 'delivered',
            deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveryConfirmedBy: 'dailyDeliveryCheck',
          });
          
          updatedCount++;
        } else {
          console.log(`📍 Order ${orderId} (${trackingNumber}): ${trackingStatus || 'UNKNOWN'}`);
        }
      }

      console.log(`\n📊 Daily Delivery Check Summary:`);
      console.log(`   📦 ${sentOrdersSnapshot.size} orders in "sent" status`);
      console.log(`   🔍 ${checkedCount} orders checked`);
      console.log(`   ✅ ${updatedCount} orders updated to "delivered"`);
      console.log(`   ❌ ${errorCount} errors`);

    } catch (error) {
      console.error('❌ Daily delivery check failed:', error);
      throw error;
    }
  });

/**
 * One-time migration: Backfill curator stats for all existing curators
 * Call via: https://[region]-[project].cloudfunctions.net/backfillCuratorStats
 */
exports.backfillCuratorStats = functions.https.onRequest(async (req, res) => {
  console.log('🔄 Starting curator stats backfill...');
  
  try {
    // Get all curators
    const curatorsSnapshot = await db.collection('users')
      .where('isCurator', '==', true)
      .get();
    
    console.log(`Found ${curatorsSnapshot.size} curators to update`);
    
    const completedStatuses = ['kept', 'returnedConfirmed'];
    let updated = 0;
    let errors = 0;
    
    for (const curatorDoc of curatorsSnapshot.docs) {
      const curatorId = curatorDoc.id;
      
      try {
        // Count completed orders
        const ordersSnapshot = await db.collection('orders')
          .where('curatorId', '==', curatorId)
          .where('status', 'in', completedStatuses)
          .get();
        
        const orderCount = ordersSnapshot.size;
        
        // Calculate average rating from curatorReviews subcollection
        const reviewsSnapshot = await db.collection('users')
          .doc(curatorId)
          .collection('curatorReviews')
          .get();
        
        let averageRating = 0;
        const reviewCount = reviewsSnapshot.size;
        
        if (reviewCount > 0) {
          let totalRating = 0;
          reviewsSnapshot.docs.forEach(doc => {
            totalRating += doc.data().rating || 0;
          });
          averageRating = totalRating / reviewCount;
        }
        
        // Update curator document
        await db.collection('users').doc(curatorId).update({
          curatorOrderCount: orderCount,
          curatorAverageRating: averageRating,
          curatorReviewCount: reviewCount,
        });
        
        console.log(`✅ ${curatorDoc.data().username || curatorId}: ${orderCount} orders, ${averageRating.toFixed(2)} rating`);
        updated++;
        
      } catch (err) {
        console.error(`❌ Error updating ${curatorId}:`, err.message);
        errors++;
      }
    }
    
    const summary = `Backfill complete: ${updated} curators updated, ${errors} errors`;
    console.log(`\n📊 ${summary}`);
    res.status(200).send(summary);
    
  } catch (error) {
    console.error('❌ Backfill failed:', error);
    res.status(500).send(`Error: ${error.message}`);
  }
});

/**
 * Update curator stats (order count, rating) when order status changes
 * This keeps denormalized stats on the user document for fast curator list loading
 */
exports.onOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only update stats when status changes to/from completed states
    const completedStatuses = ['kept', 'returnedConfirmed'];
    const wasCompleted = completedStatuses.includes(before.status);
    const isCompleted = completedStatuses.includes(after.status);
    
    // Skip if no relevant status change
    if (wasCompleted === isCompleted) {
      return null;
    }
    
    const curatorId = after.curatorId;
    if (!curatorId) {
      console.log('No curatorId found on order, skipping stats update');
      return null;
    }
    
    console.log(`📊 Updating curator stats for ${curatorId} (order ${context.params.orderId})`);
    
    try {
      // Count completed orders for this curator
      const ordersSnapshot = await db.collection('orders')
        .where('curatorId', '==', curatorId)
        .where('status', 'in', completedStatuses)
        .get();
      
      const orderCount = ordersSnapshot.size;
      
      // Calculate average rating from curatorReviews subcollection
      const reviewsSnapshot = await db.collection('users')
        .doc(curatorId)
        .collection('curatorReviews')
        .get();
      
      let averageRating = 0;
      const reviewCount = reviewsSnapshot.size;
      
      if (reviewCount > 0) {
        let totalRating = 0;
        reviewsSnapshot.docs.forEach(doc => {
          totalRating += doc.data().rating || 0;
        });
        averageRating = totalRating / reviewCount;
      }
      
      // Update denormalized fields on curator's user document
      await db.collection('users').doc(curatorId).update({
        curatorOrderCount: orderCount,
        curatorAverageRating: averageRating,
        curatorReviewCount: reviewCount,
      });
      
      console.log(`✅ Updated curator ${curatorId}: ${orderCount} orders, ${averageRating.toFixed(2)} avg rating, ${reviewCount} reviews`);
      
    } catch (error) {
      console.error(`❌ Error updating curator stats for ${curatorId}:`, error);
    }
    
    return null;
  });

/**
 * Update curator stats when a new review is added
 */
exports.onNewCuratorReview = functions.firestore
  .document('users/{userId}/curatorReviews/{reviewId}')
  .onCreate(async (snapshot, context) => {
    const curatorId = context.params.userId;
    
    console.log(`⭐ New curator review added for ${curatorId}`);
    
    try {
      // Calculate average rating from all curatorReviews
      const reviewsSnapshot = await db.collection('users')
        .doc(curatorId)
        .collection('curatorReviews')
        .get();
      
      let averageRating = 0;
      const reviewCount = reviewsSnapshot.size;
      
      if (reviewCount > 0) {
        let totalRating = 0;
        reviewsSnapshot.docs.forEach(doc => {
          totalRating += doc.data().rating || 0;
        });
        averageRating = totalRating / reviewCount;
      }
      
      // Update denormalized rating fields
      await db.collection('users').doc(curatorId).update({
        curatorAverageRating: averageRating,
        curatorReviewCount: reviewCount,
      });
      
      console.log(`✅ Updated curator ${curatorId} rating: ${averageRating.toFixed(2)} avg (${reviewCount} reviews)`);
      
    } catch (error) {
      console.error(`❌ Error updating curator rating for ${curatorId}:`, error);
    }
    
    return null;
  });

// Delete the old onNewReview function - it was watching the wrong collection path
