#!/usr/bin/env node

/**
 * Validate Free Order Grant
 * 
 * Verifies that free orders were successfully granted to eligible users.
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

async function validateFreeOrders() {
  console.log('\n🔍 VALIDATING FREE ORDER GRANT');
  console.log('━'.repeat(70));
  console.log('Checking that free orders were correctly granted...\n');
  
  try {
    // Fetch all users
    const usersSnapshot = await db.collection('users').get();
    const totalUsers = usersSnapshot.size;
    
    console.log(`📊 Found ${totalUsers} total users\n`);
    console.log('⏳ Validating free order grants...\n');
    
    let usersWithFreeOrders = 0;
    let usersWithFreeOrdersAvailable = 0;
    let eligibleUsersWithoutFreeOrders = [];
    let usersWithOrdersButFreeOrders = [];
    
    // Check each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      const hasFreeOrder = userData.freeOrder === true;
      const freeOrdersAvailable = userData.freeOrdersAvailable || 0;
      
      if (hasFreeOrder) usersWithFreeOrders++;
      if (freeOrdersAvailable > 0) usersWithFreeOrdersAvailable++;
      
      // Check if user has any actual orders
      const ordersSnapshot = await db
        .collection('orders')
        .where('userId', '==', userId)
        .limit(1)
        .get();
      
      const hasActualOrders = !ordersSnapshot.empty;
      
      // Find eligible users who DON'T have free orders (potential issue)
      if (!hasActualOrders && !hasFreeOrder && freeOrdersAvailable === 0) {
        eligibleUsersWithoutFreeOrders.push({
          userId,
          username: userData.username || 'Unknown',
          email: userData.email || 'Unknown'
        });
      }
      
      // Find users with orders who HAVE free orders (shouldn't happen)
      if (hasActualOrders && (hasFreeOrder || freeOrdersAvailable > 0)) {
        usersWithOrdersButFreeOrders.push({
          userId,
          username: userData.username || 'Unknown',
          email: userData.email || 'Unknown',
          freeOrdersAvailable
        });
      }
    }
    
    // Print results
    console.log('━'.repeat(70));
    console.log('📈 VALIDATION RESULTS');
    console.log('━'.repeat(70));
    console.log(`Total Users:                           ${totalUsers}`);
    console.log(`Users with freeOrder = true:           ${usersWithFreeOrders}`);
    console.log(`Users with freeOrdersAvailable > 0:    ${usersWithFreeOrdersAvailable}`);
    console.log(`\nEligible users WITHOUT free orders:    ${eligibleUsersWithoutFreeOrders.length} ${eligibleUsersWithoutFreeOrders.length === 0 ? '✅' : '⚠️'}`);
    console.log(`Users WITH orders BUT have free order: ${usersWithOrdersButFreeOrders.length} ${usersWithOrdersButFreeOrders.length === 0 ? '✅' : '⚠️'}`);
    
    if (eligibleUsersWithoutFreeOrders.length > 0) {
      console.log('\n⚠️  ELIGIBLE USERS WITHOUT FREE ORDERS:');
      console.log('━'.repeat(70));
      eligibleUsersWithoutFreeOrders.forEach((user, index) => {
        console.log(`${(index + 1).toString().padStart(3, ' ')}. ${user.username} (${user.email})`);
      });
      console.log('\n💡 These users should have received free orders but didn\'t.');
    }
    
    if (usersWithOrdersButFreeOrders.length > 0) {
      console.log('\n⚠️  USERS WITH ORDERS WHO HAVE FREE ORDERS:');
      console.log('━'.repeat(70));
      usersWithOrdersButFreeOrders.slice(0, 10).forEach((user, index) => {
        console.log(`${(index + 1).toString().padStart(3, ' ')}. ${user.username} (${user.email}) - ${user.freeOrdersAvailable} free order(s)`);
      });
      if (usersWithOrdersButFreeOrders.length > 10) {
        console.log(`... and ${usersWithOrdersButFreeOrders.length - 10} more`);
      }
      console.log('\n💡 These users had already placed orders but have free orders.');
      console.log('   This is normal if they received free orders BEFORE placing orders.');
    }
    
    // Overall validation
    console.log('\n' + '━'.repeat(70));
    if (eligibleUsersWithoutFreeOrders.length === 0) {
      console.log('✅ VALIDATION PASSED!');
      console.log('   All eligible users have received their free orders.');
      console.log(`   ${usersWithFreeOrders} users now have free orders available.`);
    } else {
      console.log('⚠️  VALIDATION FAILED!');
      console.log(`   ${eligibleUsersWithoutFreeOrders.length} eligible users did not receive free orders.`);
    }
    console.log('━'.repeat(70));
    console.log('\n');
    
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

validateFreeOrders();


