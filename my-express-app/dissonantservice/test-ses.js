// Quick test script to verify SES configuration
// Run this locally to test your setup before deploying

const nodemailer = require('nodemailer');
const aws = require('aws-sdk');

// Configure AWS (use your actual credentials)
aws.config.update({
  region: 'us-east-1',
  // For local testing, you can set credentials here
  // In Lambda, these will be automatic via execution role
});

// Create SES transporter
const transporter = nodemailer.createTransporter({
  SES: new aws.SES({ apiVersion: '2010-12-01' }),
});

async function testSES() {
  try {
    console.log('Testing SES configuration...');
    
    const mailOptions = {
      from: 'dissonant.helpdesk@gmail.com', // Must be verified in SES
      to: 'dissonant.helpdesk@gmail.com',   // Your test email
      subject: 'SES Test Email',
      text: 'This is a test email from Amazon SES via Node.js'
    };

    const result = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent successfully!');
    console.log('Message ID:', result.messageId);
    
  } catch (error) {
    console.error('❌ Email failed:', error.message);
  }
}

testSES();

