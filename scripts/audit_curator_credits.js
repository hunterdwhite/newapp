#!/usr/bin/env node

/**
 * Audit Curator Credits
 * 
 * Checks all completed curator orders and verifies curators received their credits.
 * Can optionally backfill missing credits.
 */

const path = require('path');

// Load firebase-admin
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

// Initialize Firebase Admin
try {
  admin.initializeApp();
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  process.exit(1);
}

const db = admin.firestore();

async function auditCuratorCredits() {
  const isDryRun = process.argv.includes('--dry-run');
  
  console.log('\n🔍 CURATOR CREDIT AUDIT');
  console.log('━'.repeat(70));
  console.log(`Mode: ${isDryRun ? '📋 DRY RUN (no changes)' : '✅ LIVE UPDATE'}`);
  console.log('━'.repeat(70));
  console.log('\n⏳ Fetching completed curator orders...\n');
  
  try {
    // Get all orders with curators where curator has completed their work
    // This includes ready_to_ship (curator selected album, waiting for admin to ship)
    const ordersSnapshot = await db
      .collection('orders')
      .where('status', 'in', ['ready_to_ship', 'sent', 'delivered', 'returned', 'kept', 'returnedConfirmed'])
      .get();
    
    console.log(`📦 Found ${ordersSnapshot.size} completed orders\n`);
    console.log('⏳ Analyzing curator rewards...\n');
    
    // Track curator order counts
    const curatorOrderCounts = new Map();
    const curatorOrderIds = new Map();
    const ordersWithCurators = [];
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      const curatorId = orderData.curatorId;
      
      if (curatorId) {
        ordersWithCurators.push({
          orderId: orderDoc.id,
          curatorId,
          status: orderData.status,
          timestamp: orderData.timestamp,
          curatedAt: orderData.curatedAt,
          shippedAt: orderData.shippedAt,
        });
        
        if (!curatorOrderCounts.has(curatorId)) {
          curatorOrderCounts.set(curatorId, 0);
          curatorOrderIds.set(curatorId, []);
        }
        curatorOrderCounts.set(curatorId, curatorOrderCounts.get(curatorId) + 1);
        curatorOrderIds.get(curatorId).push(orderDoc.id);
      }
    }
    
    console.log(`👥 Found ${curatorOrderCounts.size} curators with completed orders\n`);
    console.log('━'.repeat(70));
    console.log('CURATOR ANALYSIS');
    console.log('━'.repeat(70));
    
    const curatorsNeedingCredits = [];
    const curatorStats = [];
    
    // Check each curator's credit balance
    for (const [curatorId, completedOrders] of curatorOrderCounts.entries()) {
      const userDoc = await db.collection('users').doc(curatorId).get();
      
      if (!userDoc.exists) {
        console.log(`⚠️  Curator ${curatorId} not found in users collection`);
        continue;
      }
      
      const userData = userDoc.data();
      const username = userData.username || 'Unknown';
      const freeOrderCredits = userData.freeOrderCredits || 0;
      const freeOrdersAvailable = userData.freeOrdersAvailable || 0;
      const isCurator = userData.isCurator || false;
      
      // Calculate expected minimum credits (each completed order = 1 credit)
      // Note: Users also get credits from placing orders (1 per order)
      // So we can't determine exact expected, but we can flag suspicious cases
      
      const totalCreditsAndOrders = freeOrderCredits + (freeOrdersAvailable * 5);
      
      curatorStats.push({
        curatorId,
        username,
        completedOrders,
        freeOrderCredits,
        freeOrdersAvailable,
        totalCreditsAndOrders,
        isCurator,
        orderIds: curatorOrderIds.get(curatorId),
      });
      
      // Flag curators who have completed orders but have 0 credits/orders
      // This is a strong indicator they never received rewards
      if (completedOrders > 0 && totalCreditsAndOrders === 0) {
        curatorsNeedingCredits.push({
          curatorId,
          username,
          completedOrders,
          creditsOwed: completedOrders, // 1 credit per completed order
        });
      }
    }
    
    // Sort by completed orders (descending)
    curatorStats.sort((a, b) => b.completedOrders - a.completedOrders);
    
    // Display top curators
    console.log('\n📊 TOP CURATORS BY COMPLETED ORDERS:\n');
    curatorStats.slice(0, 15).forEach((curator, index) => {
      console.log(`${(index + 1).toString().padStart(2, ' ')}. ${curator.username.padEnd(20, ' ')} - ${curator.completedOrders} orders | Credits: ${curator.freeOrderCredits} | Free Orders: ${curator.freeOrdersAvailable} | Total Value: ${curator.totalCreditsAndOrders}`);
    });
    
    // Display curators who definitely need credits
    console.log('\n━'.repeat(70));
    console.log('⚠️  CURATORS MISSING CREDITS');
    console.log('━'.repeat(70));
    console.log('These curators have completed orders but 0 credits/free orders:');
    console.log('(They should have received 1 credit per completed order)\n');
    
    if (curatorsNeedingCredits.length === 0) {
      console.log('✅ No curators found with missing credits!\n');
    } else {
      curatorsNeedingCredits.forEach((curator, index) => {
        console.log(`${(index + 1).toString().padStart(3, ' ')}. ${curator.username} (${curator.curatorId})`);
        console.log(`     Completed Orders: ${curator.completedOrders}`);
        console.log(`     Credits Owed: ${curator.creditsOwed}`);
        console.log('');
      });
      
      console.log(`📊 Total curators needing credits: ${curatorsNeedingCredits.length}`);
      console.log(`💰 Total credits to award: ${curatorsNeedingCredits.reduce((sum, c) => sum + c.creditsOwed, 0)}`);
      
      if (isDryRun) {
        console.log('\n━'.repeat(70));
        console.log('📋 DRY RUN MODE - No changes made');
        console.log('━'.repeat(70));
        console.log('\nTo backfill these credits, run:');
        console.log('  node scripts/audit_curator_credits.js --backfill\n');
      } else if (process.argv.includes('--backfill')) {
        console.log('\n━'.repeat(70));
        console.log('💳 BACKFILLING CREDITS');
        console.log('━'.repeat(70));
        
        for (const curator of curatorsNeedingCredits) {
          try {
            console.log(`\n⏳ Awarding ${curator.creditsOwed} credits to ${curator.username}...`);
            
            const userRef = db.collection('users').doc(curator.curatorId);
            const userDoc = await userRef.get();
            const userData = userDoc.data() || {};
            
            const currentCredits = userData.freeOrderCredits || 0;
            const currentFreeOrders = userData.freeOrdersAvailable || 0;
            
            const newTotalCredits = currentCredits + curator.creditsOwed;
            const newFreeOrdersEarned = Math.floor(newTotalCredits / 5);
            const remainingCredits = newTotalCredits % 5;
            const totalFreeOrders = currentFreeOrders + newFreeOrdersEarned;
            
            await userRef.update({
              freeOrderCredits: remainingCredits,
              freeOrdersAvailable: totalFreeOrders,
              freeOrder: totalFreeOrders > 0,
            });
            
            console.log(`   ✅ ${curator.username}: ${curator.creditsOwed} credits → ${newFreeOrdersEarned} free orders + ${remainingCredits} credits`);
          } catch (e) {
            console.log(`   ❌ Error awarding credits to ${curator.username}: ${e.message}`);
          }
        }
        
        console.log('\n✨ Backfill complete!\n');
      }
    }
    
    console.log('━'.repeat(70));
    console.log('📈 SUMMARY');
    console.log('━'.repeat(70));
    console.log(`Total completed orders:           ${ordersWithCurators.length}`);
    console.log(`Orders with curators:             ${ordersWithCurators.length}`);
    console.log(`Unique curators:                  ${curatorOrderCounts.size}`);
    console.log(`Curators with missing credits:    ${curatorsNeedingCredits.length}`);
    console.log('━'.repeat(70));
    console.log('');
    
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

auditCuratorCredits();

