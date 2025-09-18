const { syncAlbums } = require('./index.js');

console.log('Starting manual Discogs sync test...');

async function testSync() {
  try {
    await syncAlbums();
    console.log('✅ Manual sync completed successfully!');
  } catch (error) {
    console.error('❌ Sync failed:', error);
  }
}

testSync();

