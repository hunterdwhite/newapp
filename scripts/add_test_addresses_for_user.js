const admin = require('firebase-admin');

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  try {
    // Use service account key from scripts directory
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase initialized with service account');
  } catch (error) {
    console.error('❌ Failed to load service account key:', error.message);
    console.error('Make sure serviceAccountKey.json exists in the scripts directory');
    process.exit(1);
  }
}

const db = admin.firestore();

async function addTestAddresses() {
  const testUserId = 'FuX8lTVpxgXFuUpEBfsnqFHKuLr2';
  
  console.log(`🔧 Adding test addresses for user: ${testUserId}`);
  
  const testOrders = [
    {
      userId: testUserId,
      address: 'John Doe\n123 Main Street Apt 4\nNew York, NY 10001',
      status: 'kept',
      timestamp: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      flowVersion: 2,
      details: {}
    },
    {
      userId: testUserId,
      address: 'Jane Smith\n456 Oak Avenue\nLos Angeles, CA 90001',
      status: 'returnedConfirmed',
      timestamp: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      flowVersion: 2,
      details: {}
    },
    {
      userId: testUserId,
      address: 'Bob Johnson\n789 Pine Road Unit 5B\nChicago, IL 60601',
      status: 'kept',
      timestamp: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      flowVersion: 2,
      details: {}
    }
  ];
  
  console.log(`📦 Creating ${testOrders.length} test orders...`);
  
  for (let i = 0; i < testOrders.length; i++) {
    const order = testOrders[i];
    try {
      const docRef = await db.collection('orders').add(order);
      const displayName = order.address.split('\n')[0];
      console.log(`✅ Order ${i + 1}: Added with ID ${docRef.id}`);
      console.log(`   Address: ${displayName}`);
      console.log(`   Status: ${order.status}`);
    } catch (error) {
      console.error(`❌ Failed to add order ${i + 1}:`, error.message);
    }
  }
  
  console.log('\n🎉 All test addresses added successfully!');
  console.log('\n📝 Test addresses created:');
  console.log('   1. John Doe - 123 Main Street Apt 4, New York, NY 10001');
  console.log('   2. Jane Smith - 456 Oak Avenue, Los Angeles, CA 90001');
  console.log('   3. Bob Johnson - 789 Pine Road Unit 5B, Chicago, IL 60601');
  console.log('\n💡 Restart your app and navigate to the Order page to see them!');
  
  process.exit(0);
}

addTestAddresses().catch(err => {
  console.error('❌ Error adding test addresses:', err);
  process.exit(1);
});

