const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

// Configure your email service (example with SendGrid)
const transporter = nodemailer.createTransporter({
  service: 'SendGrid', // or use 'gmail', 'mailgun', etc.
  auth: {
    user: 'apikey',
    pass: functions.config().sendgrid.apikey, // Set with: firebase functions:config:set sendgrid.apikey="your-api-key"
  },
});

// Custom email verification function
exports.sendCustomEmailVerification = functions.https.onCall(async (data, context) => {
  try {
    const { email, displayName } = data;
    
    // Generate custom verification token
    const customToken = await admin.auth().createCustomToken(context.auth.uid);
    const verificationLink = `https://your-domain.com/verify-email?token=${customToken}&email=${email}`;

    const mailOptions = {
      from: '"Dissonant Music" <noreply@dissonant.com>',
      to: email,
      subject: 'Welcome to Dissonant - Verify Your Email',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Welcome to Dissonant</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
          <table role="presentation" style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 40px 0; text-align: center;">
                <table role="presentation" style="width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                  <!-- Header -->
                  <tr>
                    <td style="background-color: #E46A14; padding: 40px 20px; text-align: center;">
                      <h1 style="color: white; margin: 0; font-size: 28px;">Welcome to Dissonant!</h1>
                      <p style="color: white; margin: 10px 0 0 0; opacity: 0.9;">Discover Music That Moves You</p>
                    </td>
                  </tr>
                  
                  <!-- Content -->
                  <tr>
                    <td style="padding: 40px 30px;">
                      <h2 style="color: #333; margin: 0 0 20px 0;">Hi ${displayName || 'Music Lover'}!</h2>
                      
                      <p style="color: #666; line-height: 1.6; margin: 0 0 20px 0;">
                        Thanks for joining Dissonant! We're excited to help you discover incredible music curated specifically for your taste.
                      </p>
                      
                      <p style="color: #666; line-height: 1.6; margin: 0 0 30px 0;">
                        To get started and unlock your personalized music recommendations, please verify your email address by clicking the button below:
                      </p>
                      
                      <!-- CTA Button -->
                      <table role="presentation" style="margin: 0 auto;">
                        <tr>
                          <td style="text-align: center;">
                            <a href="${verificationLink}" style="background-color: #E46A14; color: white; padding: 16px 32px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block; font-size: 16px;">
                              Verify Email Address
                            </a>
                          </td>
                        </tr>
                      </table>
                      
                      <p style="color: #666; line-height: 1.6; margin: 30px 0 20px 0; font-size: 14px;">
                        If the button doesn't work, copy and paste this link into your browser:
                      </p>
                      <p style="word-break: break-all; background-color: #f8f9fa; padding: 15px; border-radius: 4px; font-family: monospace; font-size: 12px;">
                        ${verificationLink}
                      </p>
                      
                      <div style="border-top: 1px solid #eee; margin: 30px 0; padding-top: 20px;">
                        <p style="color: #666; line-height: 1.6; margin: 0;">
                          <strong>What's next?</strong><br>
                          After verification, you'll complete a quick taste profile to help us curate the perfect albums for you!
                        </p>
                      </div>
                    </td>
                  </tr>
                  
                  <!-- Footer -->
                  <tr>
                    <td style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eee;">
                      <p style="color: #999; font-size: 12px; margin: 0; line-height: 1.4;">
                        This email was sent by Dissonant Music<br>
                        If you didn't create an account with us, please ignore this email.
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
      `,
      // Text fallback
      text: `
        Welcome to Dissonant!
        
        Hi ${displayName || 'Music Lover'}!
        
        Thanks for joining Dissonant! Please verify your email address by clicking this link:
        ${verificationLink}
        
        If you didn't create an account with us, please ignore this email.
        
        - The Dissonant Team
      `
    };

    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// Email verification handler
exports.verifyCustomEmail = functions.https.onCall(async (data, context) => {
  try {
    const { token, email } = data;
    
    // Verify the custom token
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Update user as verified
    await admin.auth().updateUser(decodedToken.uid, {
      emailVerified: true
    });
    
    return { success: true };
  } catch (error) {
    console.error('Error verifying email:', error);
    throw new functions.https.HttpsError('invalid-argument', 'Invalid verification token');
  }
}); 