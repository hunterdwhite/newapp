#!/usr/bin/env node

/**
 * Get Curator Emails
 * 
 * Exports a list of all emails for users who have signed up as curators.
 */

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
  console.log('\n📧 CURATOR EMAIL LIST');
  console.log('━'.repeat(70));
  console.log('Fetching all users with isCurator=true...\n');
  
  try {
    // Get all users marked as curators
    const curatorsSnapshot = await db
      .collection('users')
      .where('isCurator', '==', true)
      .get();
    
    console.log(`Found ${curatorsSnapshot.size} curators\n`);
    console.log('━'.repeat(70));
    
    const curators = [];
    
    for (const curatorDoc of curatorsSnapshot.docs) {
      const curatorData = curatorDoc.data();
      const curatorId = curatorDoc.id;
      
      curators.push({
        username: curatorData.username || 'Unknown',
        email: curatorData.email || 'No email',
        curatorId: curatorId,
        joinedAt: curatorData.createdAt,
      });
    }
    
    // Sort by username
    curators.sort((a, b) => a.username.localeCompare(b.username));
    
    // Display with numbers
    console.log('CURATOR LIST:\n');
    curators.forEach((curator, index) => {
      console.log(`${(index + 1).toString().padStart(2, ' ')}. ${curator.username.padEnd(20, ' ')} - ${curator.email}`);
    });
    
    console.log('\n' + '━'.repeat(70));
    console.log('EMAIL LIST (comma-separated):\n');
    const emails = curators.map(c => c.email).filter(e => e !== 'No email');
    console.log(emails.join(', '));
    
    console.log('\n' + '━'.repeat(70));
    console.log('EMAIL LIST (one per line):\n');
    emails.forEach(email => console.log(email));
    
    console.log('\n' + '━'.repeat(70));
    console.log('SUMMARY:');
    console.log('━'.repeat(70));
    console.log(`Total curators: ${curators.length}`);
    console.log(`Valid emails: ${emails.length}`);
    console.log('━'.repeat(70));
    console.log('');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
})();


