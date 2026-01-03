const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id
});

async function verifyUserEmail(email) {
  console.log('📧 Verifying email for user:', email);
  console.log('='.repeat(80));
  
  try {
    // Get user by email
    console.log('\n🔍 Looking up user...');
    const user = await admin.auth().getUserByEmail(email);
    
    console.log('   ✅ User found!');
    console.log('   User ID:', user.uid);
    console.log('   Email:', user.email);
    console.log('   Current verified status:', user.emailVerified);
    console.log('   Display name:', user.displayName || 'N/A');
    console.log('   Created:', new Date(user.metadata.creationTime).toLocaleString());
    
    if (user.emailVerified) {
      console.log('\n✅ Email is already verified! No action needed.');
      return;
    }
    
    // Update user to mark email as verified
    console.log('\n📝 Updating email verification status...');
    await admin.auth().updateUser(user.uid, {
      emailVerified: true
    });
    
    console.log('   ✅ Email verified successfully!');
    
    // Verify the change
    console.log('\n🔍 Verifying the change...');
    const updatedUser = await admin.auth().getUser(user.uid);
    console.log('   New verified status:', updatedUser.emailVerified);
    
    console.log('\n' + '='.repeat(80));
    console.log('✅ SUCCESS! User can now log in and use the app.');
    console.log('='.repeat(80));
    console.log('\n📋 User Details:');
    console.log('   Email:', updatedUser.email);
    console.log('   User ID:', updatedUser.uid);
    console.log('   Email Verified:', updatedUser.emailVerified);
    console.log('   Display Name:', updatedUser.displayName || 'N/A');
    console.log('='.repeat(80));
    
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.error('\n❌ User not found with email:', email);
      console.error('   Make sure the user has created an account.');
    } else {
      console.error('\n❌ Error:', error.message);
      console.error(error);
    }
    process.exit(1);
  }
  
  process.exit(0);
}

const email = process.argv[2] || 'briannabb1207@icloud.com';
verifyUserEmail(email);
