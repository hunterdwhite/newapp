#!/usr/bin/env node

/**
 * Register Existing Tracking Numbers with Shippo
 * 
 * This script finds all orders with tracking numbers that are in "sent" or "labelCreated"
 * status and registers them with Shippo's tracking API. This enables automatic webhook
 * updates when the package status changes (shipped, delivered, etc.).
 * 
 * PREREQUISITES:
 *   Must be run from the functions directory where firebase-admin is installed
 *   Requires SHIPPO_TOKEN environment variable
 * 
 * USAGE:
 *   cd functions
 *   SHIPPO_TOKEN=your_token_here node ../scripts/register_existing_tracking.js [--dry-run]
 * 
 * OPTIONS:
 *   --dry-run       Preview what would be registered without actually calling Shippo API
 * 
 * EXAMPLES:
 *   # Preview (recommended first)
 *   cd functions && SHIPPO_TOKEN=your_token node ../scripts/register_existing_tracking.js --dry-run
 * 
 *   # Actually register tracking numbers
 *   cd functions && SHIPPO_TOKEN=your_token node ../scripts/register_existing_tracking.js
 */

const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Parse command line arguments
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase initialized');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase:', error.message);
    process.exit(1);
  }
}

const db = admin.firestore();

// Check for Shippo token
const SHIPPO_TOKEN = process.env.SHIPPO_TOKEN;
if (!SHIPPO_TOKEN) {
  console.error('❌ SHIPPO_TOKEN environment variable is required');
  console.error('Usage: SHIPPO_TOKEN=your_token node register_existing_tracking.js');
  process.exit(1);
}

async function registerTracking(trackingNumber, carrier, orderId, customerName) {
  try {
    const response = await fetch('https://api.goshippo.com/tracks/', {
      method: 'POST',
      headers: {
        'Authorization': `ShippoToken ${SHIPPO_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        carrier: carrier.toLowerCase(),
        tracking_number: trackingNumber,
        metadata: `Backfill - Order ${orderId} - ${customerName || 'Customer'}`,
      }),
    });
    
    if (response.ok) {
      const data = await response.json();
      return { success: true, data };
    } else {
      const errorData = await response.json();
      return { success: false, error: errorData };
    }
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function main() {
  console.log('🔍 ============================================');
  console.log('🔍 Register Existing Tracking Numbers');
  console.log('🔍 ============================================');
  console.log(`Mode: ${dryRun ? '🧪 DRY RUN (no changes)' : '🚀 LIVE (will register)'}`);
  console.log('');
  
  try {
    // Find all orders with tracking numbers that are in sent or labelCreated status
    console.log('📦 Fetching orders with tracking numbers...');
    const ordersSnapshot = await db.collection('orders')
      .where('status', 'in', ['sent', 'labelCreated'])
      .get();
    
    console.log(`Found ${ordersSnapshot.size} orders to process\n`);
    
    let registered = 0;
    let skipped = 0;
    let failed = 0;
    const results = [];
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      const trackingNumber = orderData.trackingNumber || orderData.outboundTrackingNumber;
      const customerName = orderData.customerName || 'Customer';
      
      if (!trackingNumber) {
        skipped++;
        console.log(`⏭️  Order ${orderDoc.id}: No tracking number`);
        continue;
      }
      
      console.log(`\n📍 Order ${orderDoc.id}`);
      console.log(`   Tracking: ${trackingNumber}`);
      console.log(`   Status: ${orderData.status}`);
      console.log(`   Customer: ${customerName}`);
      
      if (dryRun) {
        console.log(`   ✅ Would register with Shippo (dry run)`);
        registered++;
      } else {
        const result = await registerTracking(
          trackingNumber,
          'usps', // Default to USPS
          orderDoc.id,
          customerName
        );
        
        if (result.success) {
          registered++;
          console.log(`   ✅ Successfully registered`);
          console.log(`      Shippo ID: ${result.data.object_id}`);
          console.log(`      Status: ${result.data.tracking_status?.status || 'pending'}`);
          
          results.push({
            orderId: orderDoc.id,
            trackingNumber,
            success: true
          });
        } else {
          failed++;
          console.log(`   ❌ Failed to register`);
          console.log(`      Error: ${result.error.detail || result.error}`);
          
          results.push({
            orderId: orderDoc.id,
            trackingNumber,
            success: false,
            error: result.error
          });
        }
        
        // Rate limit: wait 500ms between requests
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
    
    console.log('\n\n✅ ============================================');
    console.log('✅ Registration Complete');
    console.log('✅ ============================================');
    console.log(`📊 Total Orders: ${ordersSnapshot.size}`);
    console.log(`✅ Registered: ${registered}`);
    console.log(`⏭️  Skipped: ${skipped}`);
    console.log(`❌ Failed: ${failed}`);
    console.log('');
    
    if (!dryRun && failed > 0) {
      console.log('\n⚠️  Failed Orders:');
      results.filter(r => !r.success).forEach(r => {
        console.log(`   - Order ${r.orderId}: ${r.error.detail || r.error}`);
      });
    }
    
    if (dryRun) {
      console.log('\n💡 This was a dry run. To actually register, run without --dry-run');
    } else {
      console.log('\n🎉 Tracking numbers are now registered with Shippo!');
      console.log('📬 You will receive webhook updates when package status changes.');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  }
}

main();

