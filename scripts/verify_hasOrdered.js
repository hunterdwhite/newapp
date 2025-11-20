#!/usr/bin/env node

/**
 * Verify hasOrdered Field Accuracy
 * 
 * This script checks if the hasOrdered field matches actual order data
 * to ensure the anniversary script is working correctly.
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
    console.error('   Please run from functions directory');
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

async function verifyHasOrderedField() {
  console.log('\n🔍 VERIFYING hasOrdered FIELD ACCURACY');
  console.log('━'.repeat(70));
  console.log('Checking if hasOrdered field matches actual orders...\n');
  
  try {
    // Fetch all users
    const usersSnapshot = await db.collection('users').get();
    const totalUsers = usersSnapshot.size;
    
    console.log(`📊 Found ${totalUsers} total users\n`);
    console.log('⏳ Analyzing users vs actual orders...\n');
    
    let usersWithHasOrderedTrue = 0;
    let usersWithHasOrderedFalse = 0;
    let usersWithHasOrderedMissing = 0;
    let discrepancies = [];
    
    // Check each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const hasOrderedField = userData.hasOrdered;
      
      // Count hasOrdered field status
      if (hasOrderedField === true) {
        usersWithHasOrderedTrue++;
      } else if (hasOrderedField === false) {
        usersWithHasOrderedFalse++;
      } else {
        usersWithHasOrderedMissing++;
      }
      
      // Check actual orders for this user
      const ordersSnapshot = await db
        .collection('orders')
        .where('userId', '==', userId)
        .limit(1)
        .get();
      
      const hasActualOrders = !ordersSnapshot.empty;
      
      // Check for discrepancies
      if (hasActualOrders && hasOrderedField !== true) {
        discrepancies.push({
          userId,
          username: userData.username || 'Unknown',
          email: userData.email || 'Unknown',
          hasOrderedField: hasOrderedField,
          hasActualOrders: true,
          orderCount: ordersSnapshot.size,
          issue: 'Has orders but hasOrdered is not true'
        });
      } else if (!hasActualOrders && hasOrderedField === true) {
        discrepancies.push({
          userId,
          username: userData.username || 'Unknown',
          email: userData.email || 'Unknown',
          hasOrderedField: hasOrderedField,
          hasActualOrders: false,
          orderCount: 0,
          issue: 'hasOrdered is true but no orders found'
        });
      }
    }
    
    // Print results
    console.log('━'.repeat(70));
    console.log('📈 RESULTS');
    console.log('━'.repeat(70));
    console.log(`Total Users:                      ${totalUsers}`);
    console.log(`Users with hasOrdered = true:     ${usersWithHasOrderedTrue}`);
    console.log(`Users with hasOrdered = false:    ${usersWithHasOrderedFalse}`);
    console.log(`Users with hasOrdered missing:    ${usersWithHasOrderedMissing}`);
    console.log(`\nUsers without orders (eligible):  ${usersWithHasOrderedFalse + usersWithHasOrderedMissing}`);
    console.log(`Discrepancies found:              ${discrepancies.length}`);
    
    if (discrepancies.length > 0) {
      console.log('\n⚠️  DISCREPANCIES FOUND:');
      console.log('━'.repeat(70));
      discrepancies.forEach((disc, index) => {
        console.log(`\n${index + 1}. ${disc.username} (${disc.email})`);
        console.log(`   Issue: ${disc.issue}`);
        console.log(`   hasOrdered field: ${disc.hasOrderedField}`);
        console.log(`   Actual orders: ${disc.hasActualOrders ? 'Yes' : 'No'}`);
      });
    } else {
      console.log('\n✅ No discrepancies found! The hasOrdered field is accurate.');
    }
    
    console.log('\n━'.repeat(70));
    console.log('📊 BREAKDOWN:');
    console.log(`   • ${((usersWithHasOrderedTrue / totalUsers) * 100).toFixed(1)}% of users have placed orders`);
    console.log(`   • ${(((usersWithHasOrderedFalse + usersWithHasOrderedMissing) / totalUsers) * 100).toFixed(1)}% of users have NOT placed orders`);
    console.log('━'.repeat(70));
    console.log('\n');
    
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

verifyHasOrderedField();


