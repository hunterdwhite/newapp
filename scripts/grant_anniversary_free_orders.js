#!/usr/bin/env node

/**
 * Grant Anniversary Free Orders Script
 * 
 * This script grants 1 free order to all existing users who haven't placed an order yet.
 * Perfect for launching the 1 Year Anniversary Event.
 * 
 * PREREQUISITES:
 *   Must be run from the project root directory
 *   Requires firebase-admin (installed via functions/node_modules)
 * 
 * USAGE:
 *   cd functions
 *   node ../scripts/grant_anniversary_free_orders.js [--dry-run] [--batch-size=500]
 * 
 * OR:
 *   node functions/node_modules/firebase-admin scripts/grant_anniversary_free_orders.js [--dry-run]
 * 
 * OPTIONS:
 *   --dry-run       Preview changes without actually updating Firestore
 *   --batch-size    Number of users to process per batch (default: 500)
 * 
 * EXAMPLES:
 *   # Preview what would happen (recommended first step)
 *   cd functions && node ../scripts/grant_anniversary_free_orders.js --dry-run
 * 
 *   # Actually grant free orders
 *   cd functions && node ../scripts/grant_anniversary_free_orders.js
 * 
 *   # Process in smaller batches
 *   cd functions && node ../scripts/grant_anniversary_free_orders.js --batch-size=100
 */

// Try to load firebase-admin from functions directory
let admin;
const path = require('path');

try {
  admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));
} catch (e) {
  try {
    admin = require('firebase-admin');
  } catch (e2) {
    console.error('❌ Error: firebase-admin not found');
    console.error('   Please run this script from the functions directory:');
    console.error('   cd functions && node ../scripts/grant_anniversary_free_orders.js --dry-run');
    console.error('   OR install firebase-admin: npm install firebase-admin');
    process.exit(1);
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const batchSizeArg = args.find(arg => arg.startsWith('--batch-size='));
const BATCH_SIZE = batchSizeArg ? parseInt(batchSizeArg.split('=')[1]) : 500;

// Initialize Firebase Admin
// This assumes you're running from the functions directory where service account is configured
// OR you can set GOOGLE_APPLICATION_CREDENTIALS environment variable
try {
  admin.initializeApp();
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  console.log('\nMake sure you either:');
  console.log('1. Run this from the functions directory: cd functions && node ../scripts/grant_anniversary_free_orders.js --dry-run');
  console.log('2. Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file path');
  console.log('3. OR run: firebase login (if using Firebase CLI)');
  process.exit(1);
}

const db = admin.firestore();

// Statistics tracking
const stats = {
  total: 0,
  eligible: 0,
  alreadyHasFreeOrder: 0,
  updated: 0,
  skipped: 0,
  errors: 0
};

/**
 * Check if a user is eligible for a free order
 * Now checks actual orders in the database instead of hasOrdered field
 */
async function isEligible(userId, userData) {
  // Check if they already have a free order
  const hasFreeOrder = userData.freeOrder === true;
  const freeOrdersAvailable = userData.freeOrdersAvailable || 0;
  
  if (hasFreeOrder || freeOrdersAvailable > 0) {
    return { eligible: false, reason: 'already has free order', hasFreeOrder: true };
  }
  
  // Check if user has any actual orders in the database
  const ordersSnapshot = await db
    .collection('orders')
    .where('userId', '==', userId)
    .limit(1)
    .get();
  
  const hasActualOrders = !ordersSnapshot.empty;
  
  if (hasActualOrders) {
    return { eligible: false, reason: 'already placed order' };
  }
  
  return { eligible: true };
}

/**
 * Grant free order to a user
 */
async function grantFreeOrder(userId, userData, batch, batchOps) {
  const userRef = db.collection('users').doc(userId);
  
  batch.update(userRef, {
    freeOrder: true,
    freeOrdersAvailable: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  batchOps.push({
    userId,
    username: userData.username || 'Unknown',
    email: userData.email || 'Unknown'
  });
  
  stats.updated++;
}

/**
 * Process users in batches
 */
async function processUsers() {
  console.log('\n🎉 DISSONANT 1 YEAR ANNIVERSARY - FREE ORDER GRANT');
  console.log('━'.repeat(70));
  console.log(`Mode: ${isDryRun ? '🔍 DRY RUN (Preview Only)' : '✅ LIVE UPDATE'}`);
  console.log(`Batch Size: ${BATCH_SIZE} users`);
  console.log('━'.repeat(70));
  console.log('\n⏳ Fetching users from Firestore...\n');
  
  try {
    // Fetch all users
    const usersSnapshot = await db.collection('users').get();
    stats.total = usersSnapshot.size;
    
    console.log(`📊 Found ${stats.total} total users\n`);
    console.log('🔍 Analyzing eligibility...\n');
    
    // Process in batches
    let batch = db.batch();
    let batchOps = [];
    let batchCount = 0;
    let eligibleUsers = []; // Track eligible users for dry-run
    
    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();
      
      // Check eligibility (now async - checks actual orders)
      const eligibilityCheck = await isEligible(userId, userData);
      
      if (!eligibilityCheck.eligible) {
        if (eligibilityCheck.hasFreeOrder) {
          stats.alreadyHasFreeOrder++;
        } else {
          stats.skipped++;
        }
        continue;
      }
      
      stats.eligible++;
      
      if (isDryRun) {
        // In dry-run, just collect the eligible users
        eligibleUsers.push({
          username: userData.username || 'Unknown',
          email: userData.email || 'Unknown',
          userId: userId
        });
      } else {
        // Grant free order
        await grantFreeOrder(userId, userData, batch, batchOps);
        batchCount++;
        
        // Commit batch if it reaches the batch size
        if (batchCount >= BATCH_SIZE) {
          console.log(`   💾 Committing batch of ${batchCount} updates...`);
          await batch.commit();
          
          // Log updated users
          batchOps.forEach(op => {
            console.log(`      ✅ ${op.username} (${op.email})`);
          });
          
          // Reset for next batch
          batch = db.batch();
          batchOps = [];
          batchCount = 0;
        }
      }
    }
    
    // Commit any remaining operations
    if (!isDryRun && batchCount > 0) {
      console.log(`\n   💾 Committing final batch of ${batchCount} updates...`);
      await batch.commit();
      
      // Log updated users
      batchOps.forEach(op => {
        console.log(`      ✅ ${op.username} (${op.email})`);
      });
    }
    
    // Print summary
    printSummary();
    
    // In dry-run, show eligible users
    if (isDryRun && eligibleUsers.length > 0) {
      console.log('\n👥 ELIGIBLE USERS (would receive free order):');
      console.log('━'.repeat(70));
      eligibleUsers.forEach((user, index) => {
        console.log(`${(index + 1).toString().padStart(3, ' ')}. ${user.username} (${user.email})`);
      });
      console.log('━'.repeat(70));
    }
    
  } catch (error) {
    console.error('\n❌ Error processing users:', error);
    stats.errors++;
    process.exit(1);
  }
}

/**
 * Print summary statistics
 */
function printSummary() {
  console.log('\n' + '━'.repeat(70));
  console.log('📈 SUMMARY');
  console.log('━'.repeat(70));
  console.log(`Total Users:                 ${stats.total}`);
  console.log(`Eligible for Free Order:     ${stats.eligible} 🎁`);
  console.log(`Already Have Free Order:     ${stats.alreadyHasFreeOrder}`);
  console.log(`Already Placed Order:        ${stats.skipped}`);
  
  if (isDryRun) {
    console.log(`\n${stats.eligible} users WOULD RECEIVE a free order`);
    console.log('\n💡 Run without --dry-run to actually grant free orders');
  } else {
    console.log(`\nUpdated:                     ${stats.updated} ✅`);
    console.log(`Errors:                      ${stats.errors}`);
    console.log('\n✨ Free orders have been granted!');
  }
  
  console.log('━'.repeat(70));
  
  // Breakdown by percentage
  if (stats.total > 0) {
    const eligiblePercent = ((stats.eligible / stats.total) * 100).toFixed(1);
    const orderedPercent = ((stats.skipped / stats.total) * 100).toFixed(1);
    const alreadyFreePercent = ((stats.alreadyHasFreeOrder / stats.total) * 100).toFixed(1);
    
    console.log('\n📊 Distribution:');
    console.log(`   • ${eligiblePercent}% eligible for free order`);
    console.log(`   • ${orderedPercent}% already placed orders`);
    console.log(`   • ${alreadyFreePercent}% already have free orders`);
  }
  
  console.log('\n');
}

/**
 * Main execution
 */
async function main() {
  try {
    await processUsers();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  }
}

// Run the script
main();

