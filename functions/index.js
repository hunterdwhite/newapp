const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config();

admin.initializeApp();
const db = admin.firestore();

const DISCOGS_TOKEN = process.env.DISCOGS_TOKEN;
const DISC_USERNAME = process.env.DISCOGS_USERNAME;
const REQUEST_DELAY_MS = 1100;


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
      `https://api.discogs.com/users/${DISC_USERNAME}/collection/folders/0/releases` +
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
 * Syncs the Discogs collection into Firestore, updating or inserting
 * album documents, and maintaining inventory availability.
 */
async function syncAlbums() {
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
  
  // Second pass: sync albums and update inventory with actual quantities
  const processedReleases = new Set();
  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  
  for (const item of collection) {
    // Skip items that don't have proper structure (already logged above)
    if (!item.basic_information || !item.basic_information.id) {
      continue;
    }
    
    const releaseId = item.basic_information.id;
    const releaseIdStr = releaseId.toString();
    
    // Skip if we've already processed this release in this sync
    if (processedReleases.has(releaseIdStr)) {
      console.log(`🔄 Skipping duplicate: ${releaseIdStr}`);
      skippedCount++;
      continue;
    }
    processedReleases.add(releaseIdStr);
    
    try {
      console.log(`🔍 Processing release ${releaseIdStr} (${successCount + errorCount + 1}/${discogsInventory.size})...`);
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
      const actualQuantity = discogsInventory.get(releaseIdStr);

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
  
  console.log(`📈 Sync Summary: ${successCount} successful, ${errorCount} errors, ${skippedCount} skipped duplicates`);
  
  // Third pass: Remove inventory items that are no longer in Discogs collection
  console.log("Checking for removed items...");
  const inventorySnapshot = await db.collection("inventory").get();
  const batch = db.batch();
  let removedCount = 0;
  
  inventorySnapshot.forEach((doc) => {
    const inventoryData = doc.data();
    const discogsId = inventoryData.discogsId ? inventoryData.discogsId.toString() : null;
    
    // If this item is no longer in the Discogs collection, remove it
    if (discogsId && !discogsInventory.has(discogsId)) {
      console.log(`Removing from inventory: ${inventoryData.albumName} - ${inventoryData.artist} (no longer in Discogs)`);
      batch.delete(doc.ref);
      removedCount++;
    }
  });
  
  if (removedCount > 0) {
    await batch.commit();
    console.log(`Removed ${removedCount} items from inventory`);
  }
}


/**
 * Firebase Cloud Function: runs every 24 hours to sync Discogs data.
 * Using v1 functions for better compatibility with Cloud Scheduler
 */
const functions = require("firebase-functions");

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

// Import and export custom email service functions
// Temporarily commented out due to environment variable issues
// const { sendCustomEmailVerification, verifyCustomEmail } = require('./email-service');
// exports.sendCustomEmailVerification = sendCustomEmailVerification;
// exports.verifyCustomEmail = verifyCustomEmail;

/**
 * ENHANCED Cloud Function: Send push notification to curator when order is assigned
 */
exports.notifyCuratorOnOrderAssignment = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const orderId = context.params.orderId;
  
    console.log(`🔔 Processing new order ${orderId} for curator notification:`, {
      curatorId: orderData.curatorId,
      status: orderData.status,
      userId: orderData.userId
    });
  
    // Only send notification if order has a curator assigned AND status is curator_assigned
    if (!orderData.curatorId || orderData.status !== 'curator_assigned') {
      console.log(`📋 Order ${orderId} - curatorId: ${orderData.curatorId}, status: ${orderData.status} - skipping notification`);
      return null;
    }
  
    try {
      // Get curator's FCM token and info from user document
      const curatorDoc = await db.collection('users').doc(orderData.curatorId).get();
      
      if (!curatorDoc.exists) {
        console.log(`❌ Curator ${orderData.curatorId} not found in users collection`);
        return null;
      }
      
      const curatorData = curatorDoc.data();
      const fcmToken = curatorData.fcmToken;
      const curatorName = curatorData.username || 'Curator';
      
      if (!fcmToken) {
        console.log(`⚠️ No FCM token found for curator ${curatorName} (${orderData.curatorId})`);
        return null;
      }
      
      // Get customer name from user document
      let customerName = 'Music Lover';
      try {
        const customerDoc = await db.collection('users').doc(orderData.userId).get();
        if (customerDoc.exists) {
          const customerData = customerDoc.data();
          customerName = customerData.username || customerData.displayName || 'Music Lover';
        }
      } catch (e) {
        console.log(`⚠️ Could not fetch customer name: ${e.message}`);
      }
      
      console.log(`📧 Sending notification to curator ${curatorName} about order from ${customerName}`);
      
      // Send push notification with enhanced message
      const message = {
        token: fcmToken,
        notification: {
          title: '🎵 New Order Assigned!',
          body: `${customerName} has requested your curation expertise. Tap to start curating!`,
        },
        data: {
          type: 'curator_order',
          orderId: orderId,
          curatorId: orderData.curatorId,
          customerName: customerName,
        },
        android: {
          notification: {
            icon: 'ic_launcher',
            color: '#FFA12C', // Dissonant orange
            channelId: 'curator_orders',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
              alert: {
                title: '🎵 New Order Assigned!',
                body: `${customerName} has requested your curation expertise. Tap to start curating!`,
              },
            },
          },
        },
      };
      
      const response = await admin.messaging().send(message);
      console.log(`✅ Successfully sent FCM notification to curator ${curatorName}:`, response);
      
      // Also send to topic for backup (in case direct token fails)
      try {
        const topicMessage = {
          topic: `curator_${orderData.curatorId}`,
          notification: {
            title: '🎵 New Order Assigned!',
            body: `${customerName} has requested your curation expertise`,
          },
          data: {
            type: 'curator_order',
            orderId: orderId,
            curatorId: orderData.curatorId,
            customerName: customerName,
          },
        };
        
        await admin.messaging().send(topicMessage);
        console.log(`✅ Successfully sent topic notification for curator ${curatorName}`);
      } catch (topicError) {
        console.log(`⚠️ Topic notification failed (not critical): ${topicError.message}`);
      }
      
      return null;
      
    } catch (error) {
      console.error(`❌ Error sending notification for order ${orderId}:`, error);
      
      // Log detailed error information for debugging
      console.error('Error details:', {
        message: error.message,
        code: error.code,
        stack: error.stack?.split('\n')[0]
      });
      
      return null;
    }
  });