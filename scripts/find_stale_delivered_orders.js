/**
 * Script to find users with orders in "delivered" status for over a month
 * Run from the functions directory: node ../scripts/find_stale_delivered_orders.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function findStaleDeliveredOrders() {
  console.log('Finding orders in "delivered" status for over a month...\n');

  // Calculate date 30 days ago
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  try {
    // Query all orders with status "delivered"
    const ordersSnapshot = await db
      .collection('orders')
      .where('status', '==', 'delivered')
      .get();

    console.log(`Found ${ordersSnapshot.docs.length} total delivered orders\n`);

    const staleOrders = [];

    for (const doc of ordersSnapshot.docs) {
      const orderData = doc.data();
      
      // Check deliveredAt timestamp, fall back to updatedAt or timestamp
      let deliveredDate = null;
      if (orderData.deliveredAt) {
        deliveredDate = orderData.deliveredAt.toDate();
      } else if (orderData.updatedAt) {
        deliveredDate = orderData.updatedAt.toDate();
      } else if (orderData.timestamp) {
        deliveredDate = orderData.timestamp.toDate();
      }

      // If no date found or delivered over 30 days ago
      if (!deliveredDate || deliveredDate < thirtyDaysAgo) {
        staleOrders.push({
          orderId: doc.id,
          userId: orderData.userId,
          deliveredAt: deliveredDate ? deliveredDate.toISOString() : 'unknown',
          daysDelivered: deliveredDate 
            ? Math.floor((new Date() - deliveredDate) / (1000 * 60 * 60 * 24))
            : 'unknown',
        });
      }
    }

    console.log(`Found ${staleOrders.length} orders delivered over 30 days ago\n`);

    if (staleOrders.length === 0) {
      console.log('No stale delivered orders found.');
      return;
    }

    // Get unique user IDs
    const userIds = [...new Set(staleOrders.map(o => o.userId))];
    console.log(`Fetching emails for ${userIds.length} unique users...\n`);

    // Fetch user emails
    const results = [];
    for (const userId of userIds) {
      try {
        const userRecord = await admin.auth().getUser(userId);
        const userOrders = staleOrders.filter(o => o.userId === userId);
        
        results.push({
          email: userRecord.email,
          userId: userId,
          orderCount: userOrders.length,
          orders: userOrders.map(o => ({
            orderId: o.orderId,
            deliveredAt: o.deliveredAt,
            daysDelivered: o.daysDelivered,
          })),
        });
      } catch (e) {
        console.log(`Could not find user ${userId}: ${e.message}`);
      }
    }

    // Sort by email
    results.sort((a, b) => (a.email || '').localeCompare(b.email || ''));

    // Print results
    console.log('='.repeat(60));
    console.log('USERS WITH ORDERS IN "DELIVERED" STATUS FOR OVER 30 DAYS');
    console.log('='.repeat(60));
    console.log();

    for (const user of results) {
      console.log(`Email: ${user.email}`);
      console.log(`User ID: ${user.userId}`);
      console.log(`Orders: ${user.orderCount}`);
      for (const order of user.orders) {
        console.log(`  - Order ${order.orderId}: delivered ${order.daysDelivered} days ago (${order.deliveredAt})`);
      }
      console.log();
    }

    // Print just emails for easy copy/paste
    console.log('='.repeat(60));
    console.log('EMAIL LIST (copy/paste friendly):');
    console.log('='.repeat(60));
    console.log(results.map(r => r.email).join('\n'));

    console.log();
    console.log(`Total: ${results.length} users with ${staleOrders.length} stale orders`);

  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

findStaleDeliveredOrders();

