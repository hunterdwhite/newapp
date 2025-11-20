/**
 * Backfill Free Order Credits for Returned Orders
 * 
 * This script identifies users who had orders returned but didn't receive
 * their free order credit due to the tracking webhook bug, and grants them
 * the credits they should have received.
 * 
 * Usage: node backfill_returned_order_free_credits.js [--dry-run]
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Parse command line arguments
const isDryRun = process.argv.includes('--dry-run');

async function backfillReturnedOrderCredits() {
  try {
    console.log('🔍 Starting backfill process for returned order free credits...');
    console.log(`Mode: ${isDryRun ? 'DRY RUN (no changes will be made)' : 'LIVE (will update database)'}`);
    console.log('');

    // Find all returned orders with flowVersion >= 2
    const returnedOrdersSnapshot = await db.collection('orders')
      .where('status', '==', 'returned')
      .where('flowVersion', '>=', 2)
      .get();

    console.log(`📊 Found ${returnedOrdersSnapshot.size} returned orders with flowVersion >= 2`);
    console.log('');

    // Group orders by user
    const ordersByUser = new Map();
    returnedOrdersSnapshot.forEach(doc => {
      const data = doc.data();
      const userId = data.userId;
      if (!userId) return;

      if (!ordersByUser.has(userId)) {
        ordersByUser.set(userId, []);
      }
      ordersByUser.get(userId).push({
        orderId: doc.id,
        timestamp: data.timestamp?.toDate() || new Date(0),
        address: data.address || 'N/A'
      });
    });

    console.log(`👥 Orders belong to ${ordersByUser.size} unique users`);
    console.log('');

    let totalCreditsGranted = 0;
    let usersUpdated = 0;
    let usersSkipped = 0;
    const updateLog = [];

    // Process each user
    for (const [userId, orders] of ordersByUser.entries()) {
      try {
        // Get user document
        const userDoc = await db.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
          console.log(`⚠️  User ${userId} not found - skipping ${orders.length} order(s)`);
          usersSkipped++;
          continue;
        }

        const userData = userDoc.data();
        const userEmail = userData.email || 'unknown';
        const currentFreeOrders = userData.freeOrdersAvailable || 0;
        
        // Calculate how many credits this user should have received
        const creditsToGrant = orders.length;
        
        console.log(`\n👤 User: ${userEmail} (${userId})`);
        console.log(`   📦 Returned orders: ${orders.length}`);
        console.log(`   💳 Current free orders: ${currentFreeOrders}`);
        console.log(`   🎁 Credits to grant: ${creditsToGrant}`);
        
        // List all returned orders for this user
        orders.sort((a, b) => a.timestamp - b.timestamp);
        orders.forEach((order, index) => {
          console.log(`   ${index + 1}. Order ${order.orderId} - Returned ${order.timestamp.toLocaleDateString()}`);
        });

        if (!isDryRun) {
          // Grant the credits
          const newFreeOrders = currentFreeOrders + creditsToGrant;
          
          await db.collection('users').doc(userId).update({
            freeOrdersAvailable: newFreeOrders,
            freeOrder: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Track the backfill for audit purposes
            lastCreditBackfill: {
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              creditsGranted: creditsToGrant,
              reason: 'returned_order_bug_fix',
              orderIds: orders.map(o => o.orderId)
            }
          });

          console.log(`   ✅ Granted ${creditsToGrant} free order credit(s)`);
          console.log(`   💳 New total: ${newFreeOrders} free order(s) available`);
          
          totalCreditsGranted += creditsToGrant;
          usersUpdated++;

          updateLog.push({
            userId,
            email: userEmail,
            creditsGranted: creditsToGrant,
            previousFreeOrders: currentFreeOrders,
            newFreeOrders: newFreeOrders,
            orderIds: orders.map(o => o.orderId)
          });
        } else {
          console.log(`   🔍 [DRY RUN] Would grant ${creditsToGrant} credit(s) (${currentFreeOrders} → ${currentFreeOrders + creditsToGrant})`);
          totalCreditsGranted += creditsToGrant;
          usersUpdated++;
        }

      } catch (error) {
        console.error(`❌ Error processing user ${userId}:`, error.message);
        usersSkipped++;
      }
    }

    // Print summary
    console.log('\n' + '='.repeat(80));
    console.log('📊 BACKFILL SUMMARY');
    console.log('='.repeat(80));
    console.log(`Mode:                  ${isDryRun ? 'DRY RUN' : 'LIVE'}`);
    console.log(`Users processed:       ${usersUpdated}`);
    console.log(`Users skipped:         ${usersSkipped}`);
    console.log(`Total credits granted: ${totalCreditsGranted}`);
    console.log(`Total orders affected: ${returnedOrdersSnapshot.size}`);
    
    if (!isDryRun && updateLog.length > 0) {
      // Save update log to a file
      const fs = require('fs');
      const logFileName = `backfill_log_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
      fs.writeFileSync(logFileName, JSON.stringify(updateLog, null, 2));
      console.log(`\n📝 Detailed log saved to: ${logFileName}`);
    }

    console.log('\n✅ Backfill process complete!');
    
    if (isDryRun) {
      console.log('\n⚠️  This was a DRY RUN. No changes were made to the database.');
      console.log('To apply these changes, run: node backfill_returned_order_free_credits.js');
    }

  } catch (error) {
    console.error('❌ Fatal error during backfill:', error);
    process.exit(1);
  }
}

// Run the backfill
backfillReturnedOrderCredits()
  .then(() => {
    console.log('\n👋 Script finished successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Script failed:', error);
    process.exit(1);
  });



