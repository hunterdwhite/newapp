#!/usr/bin/env node

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

(async () => {
  console.log('\n👥 CHECKING ALL CURATORS\n');
  console.log('━'.repeat(70));
  
  // Get all users marked as curators
  const curatorsSnapshot = await db.collection('users').where('isCurator', '==', true).get();
  console.log(`Total users with isCurator=true: ${curatorsSnapshot.size}\n`);
  
  // Get all orders with curatorId
  const allOrdersSnapshot = await db.collection('orders').get();
  const curatorOrdersMap = new Map();
  
  allOrdersSnapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.curatorId) {
      if (!curatorOrdersMap.has(data.curatorId)) {
        curatorOrdersMap.set(data.curatorId, []);
      }
      curatorOrdersMap.get(data.curatorId).push({
        orderId: doc.id,
        status: data.status,
        timestamp: data.timestamp,
      });
    }
  });
  
  console.log(`Total orders with curatorId: ${Array.from(curatorOrdersMap.values()).flat().length}`);
  console.log(`Unique curator IDs in orders: ${curatorOrdersMap.size}\n`);
  console.log('━'.repeat(70));
  console.log('CURATOR DETAILS:\n');
  
  const curatorsWithOrders = [];
  const curatorsWithoutOrders = [];
  
  for (const curatorDoc of curatorsSnapshot.docs) {
    const curatorData = curatorDoc.data();
    const curatorId = curatorDoc.id;
    const username = curatorData.username || 'Unknown';
    const orders = curatorOrdersMap.get(curatorId) || [];
    
    const stats = {
      curatorId,
      username,
      totalOrders: orders.length,
      ordersByStatus: {},
    };
    
    orders.forEach(order => {
      const status = order.status || 'unknown';
      stats.ordersByStatus[status] = (stats.ordersByStatus[status] || 0) + 1;
    });
    
    if (orders.length > 0) {
      curatorsWithOrders.push(stats);
    } else {
      curatorsWithoutOrders.push(stats);
    }
  }
  
  // Sort by total orders
  curatorsWithOrders.sort((a, b) => b.totalOrders - a.totalOrders);
  
  console.log('📦 Curators WITH Orders:\n');
  curatorsWithOrders.forEach((curator, i) => {
    console.log(`${(i+1).toString().padStart(2, ' ')}. ${curator.username.padEnd(20, ' ')} - ${curator.totalOrders} orders`);
    Object.entries(curator.ordersByStatus).forEach(([status, count]) => {
      console.log(`    ${status}: ${count}`);
    });
  });
  
  if (curatorsWithoutOrders.length > 0) {
    console.log(`\n📭 Curators WITHOUT Orders (${curatorsWithoutOrders.length}):\n`);
    curatorsWithoutOrders.forEach((curator, i) => {
      console.log(`${(i+1).toString().padStart(2, ' ')}. ${curator.username}`);
    });
  }
  
  console.log('\n' + '━'.repeat(70));
  console.log('SUMMARY:');
  console.log('━'.repeat(70));
  console.log(`Total curators (isCurator=true): ${curatorsSnapshot.size}`);
  console.log(`Curators with orders: ${curatorsWithOrders.length}`);
  console.log(`Curators without orders: ${curatorsWithoutOrders.length}`);
  console.log('━'.repeat(70));
  console.log('');
  
  process.exit(0);
})();


