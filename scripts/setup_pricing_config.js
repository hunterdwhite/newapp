/**
 * Setup Pricing Configuration in Firestore
 * 
 * This script creates the initial pricing configuration document in Firestore.
 * Run this from the functions directory:
 * 
 *   node ../scripts/setup_pricing_config.js
 * 
 * Or from the project root after installing firebase-admin:
 * 
 *   npm install firebase-admin
 *   node scripts/setup_pricing_config.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
// This assumes you're running from the functions directory where service account is configured
// OR you can set GOOGLE_APPLICATION_CREDENTIALS environment variable
try {
  admin.initializeApp();
} catch (error) {
  console.error('Error initializing Firebase Admin:', error.message);
  console.log('\nMake sure you either:');
  console.log('1. Run this from the functions directory, OR');
  console.log('2. Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file path');
  process.exit(1);
}

const db = admin.firestore();

async function setupPricingConfig() {
  console.log('🚀 Setting up pricing configuration in Firestore...\n');

  const pricingData = {
    dissonantPrices: [7.99, 9.99, 12.99],
    communityPrices: [5.99, 7.99, 9.99],
    defaultShippingCost: 4.99,
    giveNewUsersFreeOrder: true,   // Anniversary event: Give free orders to new users
    newUserFreeOrderCount: 1,      // Number of free orders for new users
    showAnniversaryCard: true      // Show anniversary event card on home screen
  };

  try {
    // Check if the document already exists
    const docRef = db.collection('app_config').doc('pricing_config');
    const doc = await docRef.get();

    if (doc.exists) {
      console.log('⚠️  Pricing configuration already exists!');
      console.log('Current configuration:');
      console.log(JSON.stringify(doc.data(), null, 2));
      console.log('\nDo you want to overwrite it? (y/n)');
      
      // For non-interactive mode, just show the existing config and exit
      console.log('\n💡 To update manually:');
      console.log('   1. Go to Firebase Console → Firestore Database');
      console.log('   2. Navigate to app_config → pricing_config');
      console.log('   3. Edit the document fields\n');
      process.exit(0);
    }

    // Create the pricing configuration
    await docRef.set(pricingData);

    console.log('✅ Pricing configuration created successfully!\n');
    console.log('Configuration details:');
    console.log('━'.repeat(50));
    console.log('📍 Collection: app_config');
    console.log('📄 Document:   pricing_config');
    console.log('');
    console.log('💰 Dissonant Prices:     ', pricingData.dissonantPrices.map(p => `$${p}`).join(', '));
    console.log('👥 Community Prices:     ', pricingData.communityPrices.map(p => `$${p}`).join(', '));
    console.log('📦 Default Shipping:     ', `$${pricingData.defaultShippingCost}`);
    console.log('🎁 Free Order Event:     ', pricingData.giveNewUsersFreeOrder ? 'ENABLED ✅' : 'DISABLED ❌');
    console.log('🎟️  Free Order Count:     ', pricingData.newUserFreeOrderCount);
    console.log('📢 Anniversary Card:     ', pricingData.showAnniversaryCard ? 'VISIBLE ✅' : 'HIDDEN ❌');
    console.log('━'.repeat(50));
    console.log('\n✨ The app will now use these prices from Firestore!');
    console.log('\n🎉 Anniversary Event Control:');
    console.log('   • New users will receive ' + pricingData.newUserFreeOrderCount + ' free order(s)');
    console.log('   • Anniversary card is ' + (pricingData.showAnniversaryCard ? 'VISIBLE' : 'HIDDEN') + ' on home screen');
    console.log('   • To END the event:');
    console.log('     - Set giveNewUsersFreeOrder to false (stops free orders)');
    console.log('     - Set showAnniversaryCard to false (hides card)');
    console.log('   • See FREE_ORDER_EVENT_CONTROL.md for details');
    console.log('\n💡 To update configuration in the future:');
    console.log('   • Update directly in Firebase Console, OR');
    console.log('   • Use this script to recreate the document\n');

  } catch (error) {
    console.error('❌ Error setting up pricing configuration:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Run the setup
setupPricingConfig();


