#!/usr/bin/env node

/**
 * Backfill Curator Credits with Tracking
 * 
 * Finds all orders where curator completed work but never received credit.
 * Awards missing credits and marks orders as paid.
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

try {
  admin.initializeApp();
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  process.exit(1);
}

const db = admin.firestore();

async function backfillCuratorCredits() {
  const isDryRun = !process.argv.includes('--execute');
  
  console.log('\n💳 CURATOR CREDIT BACKFILL WITH TRACKING');
  console.log('━'.repeat(70));
  console.log(`Mode: ${isDryRun ? '📋 DRY RUN (no changes)' : '✅ LIVE EXECUTION'}`);
  console.log('━'.repeat(70));
  console.log('\n⏳ Fetching orders where curator completed work...\n');
  
  try {
    // Get all orders where curator has completed their work
    // (ready_to_ship = curator selected album, sent+ = fully completed)
    const ordersSnapshot = await db
      .collection('orders')
      .get();
    
    const ordersNeedingCredits = [];
    const curatorOrderMap = new Map(); // curatorId -> list of unpaid orders
    
    console.log(`📦 Analyzing ${ordersSnapshot.size} total orders...\n`);
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      const orderId = orderDoc.id;
      const curatorId = orderData.curatorId;
      const status = orderData.status;
      const creditAwarded = orderData.curatorCreditAwarded === true;
      
      // Skip orders without curators
      if (!curatorId) continue;
      
      // Check if curator has completed their work (selected album or order fully processed)
      const curatorWorkComplete = ['ready_to_ship', 'sent', 'delivered', 'returned', 'kept', 'returnedConfirmed'].includes(status);
      
      if (curatorWorkComplete && !creditAwarded) {
        // Get curator username
        const curatorDoc = await db.collection('users').doc(curatorId).get();
        const curatorUsername = curatorDoc.exists ? (curatorDoc.data().username || 'Unknown') : 'Unknown';
        
        ordersNeedingCredits.push({
          orderId,
          curatorId,
          curatorUsername,
          status,
          timestamp: orderData.timestamp,
          curatedAt: orderData.curatedAt,
        });
        
        if (!curatorOrderMap.has(curatorId)) {
          curatorOrderMap.set(curatorId, []);
        }
        curatorOrderMap.get(curatorId).push({
          orderId,
          status,
        });
      }
    }
    
    console.log('━'.repeat(70));
    console.log('📊 UNPAID CURATOR ORDERS');
    console.log('━'.repeat(70));
    console.log(`Found ${ordersNeedingCredits.length} orders where curator work is complete but credit not awarded\n`);
    
    if (ordersNeedingCredits.length === 0) {
      console.log('✅ All curators have been paid for their completed work!\n');
      process.exit(0);
    }
    
    // Group by curator
    console.log('BY CURATOR:\n');
    const curatorSummaries = [];
    
    for (const [curatorId, orders] of curatorOrderMap.entries()) {
      const curatorDoc = await db.collection('users').doc(curatorId).get();
      const curatorData = curatorDoc.data() || {};
      const username = curatorData.username || 'Unknown';
      const currentCredits = curatorData.freeOrderCredits || 0;
      const currentFreeOrders = curatorData.freeOrdersAvailable || 0;
      
      curatorSummaries.push({
        curatorId,
        username,
        unpaidOrders: orders.length,
        currentCredits,
        currentFreeOrders,
        orders,
      });
    }
    
    curatorSummaries.sort((a, b) => b.unpaidOrders - a.unpaidOrders);
    
    curatorSummaries.forEach((curator, index) => {
      console.log(`${(index + 1).toString().padStart(2, ' ')}. ${curator.username.padEnd(20, ' ')} - ${curator.unpaidOrders} unpaid orders | Current: ${curator.currentCredits} credits + ${curator.currentFreeOrders} free orders`);
      curator.orders.forEach(order => {
        console.log(`    • Order ${order.orderId.substring(0, 8)}... (${order.status})`);
      });
      console.log('');
    });
    
    console.log('━'.repeat(70));
    console.log('📈 SUMMARY');
    console.log('━'.repeat(70));
    console.log(`Curators needing backpay:    ${curatorSummaries.length}`);
    console.log(`Total unpaid orders:         ${ordersNeedingCredits.length}`);
    console.log(`Total credits to award:      ${ordersNeedingCredits.length}`);
    console.log('━'.repeat(70));
    
    if (isDryRun) {
      console.log('\n📋 DRY RUN MODE - No changes made');
      console.log('\nTo execute the backfill, run:');
      console.log('  node scripts/backfill_curator_credits_with_tracking.js --execute\n');
    } else {
      console.log('\n💰 EXECUTING BACKFILL...\n');
      
      let successCount = 0;
      let errorCount = 0;
      
      for (const curator of curatorSummaries) {
        console.log(`\n⏳ Processing ${curator.username} (${curator.unpaidOrders} orders)...`);
        
        // Award credits for all unpaid orders
        try {
          const userRef = db.collection('users').doc(curator.curatorId);
          const userDoc = await userRef.get();
          const userData = userDoc.data() || {};
          
          const currentCredits = userData.freeOrderCredits || 0;
          const currentFreeOrders = userData.freeOrdersAvailable || 0;
          const creditsToAdd = curator.unpaidOrders;
          
          const newTotalCredits = currentCredits + creditsToAdd;
          const newFreeOrdersEarned = Math.floor(newTotalCredits / 5);
          const remainingCredits = newTotalCredits % 5;
          const totalFreeOrders = currentFreeOrders + newFreeOrdersEarned;
          
          await userRef.update({
            freeOrderCredits: remainingCredits,
            freeOrdersAvailable: totalFreeOrders,
            freeOrder: totalFreeOrders > 0,
          });
          
          console.log(`   ✅ Awarded ${creditsToAdd} credits → ${newFreeOrdersEarned} free orders + ${remainingCredits} credits`);
          
          // Mark each order as paid
          for (const order of curator.orders) {
            try {
              await db.collection('orders').doc(order.orderId).update({
                curatorCreditAwarded: true,
                curatorCreditAwardedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              successCount++;
            } catch (e) {
              console.log(`   ⚠️  Failed to mark order ${order.orderId.substring(0, 8)}... as paid: ${e.message}`);
              errorCount++;
            }
          }
          
        } catch (e) {
          console.log(`   ❌ Error awarding credits to ${curator.username}: ${e.message}`);
          errorCount += curator.orders.length;
        }
      }
      
      console.log('\n━'.repeat(70));
      console.log('✨ BACKFILL COMPLETE');
      console.log('━'.repeat(70));
      console.log(`Successfully processed: ${successCount} orders`);
      console.log(`Errors: ${errorCount} orders`);
      console.log('━'.repeat(70));
      console.log('');
    }
    
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

backfillCuratorCredits();


