#!/usr/bin/env node

/**
 * Get All User Emails
 * 
 * Exports a list of all user emails for importing to Gmail/mailing lists.
 */

const path = require('path');
const fs = require('fs');

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
  console.log('\n📧 ALL USER EMAILS EXPORT');
  console.log('━'.repeat(70));
  console.log('Fetching all users...\n');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    
    console.log(`Found ${usersSnapshot.size} total users\n`);
    console.log('━'.repeat(70));
    
    const users = [];
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      if (userData.email) {
        users.push({
          username: userData.username || 'Unknown',
          email: userData.email,
          isCurator: userData.isCurator || false,
          hasOrdered: userData.hasOrdered || false,
        });
      }
    }
    
    // Sort by username
    users.sort((a, b) => a.username.localeCompare(b.username));
    
    // Display summary
    console.log('USER BREAKDOWN:\n');
    const curators = users.filter(u => u.isCurator);
    const orderedUsers = users.filter(u => u.hasOrdered);
    const newUsers = users.filter(u => !u.hasOrdered);
    
    console.log(`Total users with emails: ${users.length}`);
    console.log(`  - Curators: ${curators.length}`);
    console.log(`  - Have ordered: ${orderedUsers.length}`);
    console.log(`  - Haven't ordered yet: ${newUsers.length}`);
    
    console.log('\n' + '━'.repeat(70));
    console.log('GMAIL-READY FORMATS:\n');
    
    // Format 1: CSV for Gmail import (best option)
    console.log('1️⃣  CSV FORMAT (Best for Gmail Import):');
    console.log('━'.repeat(70));
    const csvContent = 'Name,Email\n' + users.map(u => `${u.username},${u.email}`).join('\n');
    console.log(csvContent);
    
    // Save to file
    const csvFilePath = path.join(__dirname, 'user_emails.csv');
    fs.writeFileSync(csvFilePath, csvContent);
    console.log(`\n✅ Saved to: ${csvFilePath}`);
    
    console.log('\n' + '━'.repeat(70));
    console.log('2️⃣  COMMA-SEPARATED (For BCC field):');
    console.log('━'.repeat(70));
    const emails = users.map(u => u.email);
    const commaSeparated = emails.join(', ');
    console.log(commaSeparated);
    
    console.log('\n' + '━'.repeat(70));
    console.log('3️⃣  ONE PER LINE (For manual entry):');
    console.log('━'.repeat(70));
    emails.forEach(email => console.log(email));
    
    console.log('\n' + '━'.repeat(70));
    console.log('📋 GMAIL IMPORT INSTRUCTIONS:');
    console.log('━'.repeat(70));
    console.log('1. Open Google Contacts (contacts.google.com)');
    console.log('2. Click "Import" on the left sidebar');
    console.log('3. Click "Select file" and choose: user_emails.csv');
    console.log('4. Click "Import"');
    console.log('5. Create a new label/group for these contacts');
    console.log('6. Use this label when composing emails to send to all users');
    console.log('━'.repeat(70));
    console.log('');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
})();


