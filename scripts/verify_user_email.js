#!/usr/bin/env node

/**
 * Verify User Email
 * 
 * Manually verifies a user's email in Firebase Authentication.
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

async function verifyUserEmail(uid) {
  console.log('\n📧 MANUAL EMAIL VERIFICATION');
  console.log('━'.repeat(70));
  console.log(`User UID: ${uid}\n`);
  
  try {
    // Get user info before update
    console.log('⏳ Fetching user information...\n');
    const userBefore = await admin.auth().getUser(uid);
    
    console.log('👤 User Information:');
    console.log('━'.repeat(70));
    console.log(`   Email:              ${userBefore.email}`);
    console.log(`   Display Name:       ${userBefore.displayName || 'Not set'}`);
    console.log(`   Email Verified:     ${userBefore.emailVerified ? '✅ Yes' : '❌ No'}`);
    console.log(`   Created:            ${new Date(userBefore.metadata.creationTime).toLocaleString()}`);
    console.log(`   Last Sign In:       ${userBefore.metadata.lastSignInTime ? new Date(userBefore.metadata.lastSignInTime).toLocaleString() : 'Never'}`);
    console.log('━'.repeat(70));
    
    if (userBefore.emailVerified) {
      console.log('\n✅ User email is already verified!');
      console.log('   No action needed.\n');
      process.exit(0);
    }
    
    // Update user to verify email
    console.log('\n⏳ Verifying email...');
    await admin.auth().updateUser(uid, {
      emailVerified: true
    });
    
    // Get user info after update to confirm
    const userAfter = await admin.auth().getUser(uid);
    
    console.log('✅ Email verification updated!\n');
    console.log('📊 Updated Status:');
    console.log('━'.repeat(70));
    console.log(`   Email:              ${userAfter.email}`);
    console.log(`   Email Verified:     ${userAfter.emailVerified ? '✅ Yes' : '❌ No'}`);
    console.log('━'.repeat(70));
    
    if (userAfter.emailVerified) {
      console.log('\n🎉 SUCCESS! User email has been verified.');
      console.log('   The user can now proceed past the verification step.\n');
    } else {
      console.log('\n⚠️  WARNING: Email verification status did not update.');
      console.log('   Please check Firebase console manually.\n');
    }
    
  } catch (error) {
    console.error('\n❌ Error verifying user email:');
    console.error(`   ${error.message}\n`);
    
    if (error.code === 'auth/user-not-found') {
      console.error('💡 The user UID provided does not exist in Firebase Authentication.');
    }
    
    process.exit(1);
  }
  
  process.exit(0);
}

// Get UID from command line argument
const uid = process.argv[2];

if (!uid) {
  console.error('\n❌ Error: No UID provided');
  console.error('Usage: node verify_user_email.js <UID>\n');
  process.exit(1);
}

verifyUserEmail(uid);


