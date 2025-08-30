# Amazon SES Setup Guide for Lambda Function

## Step-by-Step Setup Instructions

### 1. Set Up Amazon SES in AWS Console

1. **Open AWS Console** → Navigate to **Amazon SES**
2. **Select Region**: Choose `us-east-1` (recommended for Lambda)
3. **Go to "Verified identities"** in the left sidebar

### 2. Verify Your Sender Email

#### Option A: Verify Individual Email Address (Recommended for quick setup - NO DOMAIN REQUIRED)

**IMPORTANT**: Make sure you're in the right section - there should be NO "sending domain" field!

**Correct Navigation Path:**
1. **AWS Console** → **Amazon SES**
2. **Left sidebar** → **"Verified identities"** (NOT "Domains")
3. Click **"Create identity"**
4. Select **"Email address"** (NOT "Domain")
5. Enter: `dissonant.helpdesk@gmail.com`
6. Click **"Create identity"**
7. **Check your email inbox** and click the verification link
8. Status should change to "Verified" ✅

**What you should see:**
- ✅ Simple email input field
- ✅ No "sending domain" field
- ✅ No DNS configuration needed

**If you see "sending domain" field:**
- ❌ You're in the wrong section (probably "Domain" verification)
- ↩️ Go back and select "Email address" instead

**Benefits:**
- ✅ No domain ownership required
- ✅ Quick setup (5 minutes)
- ✅ Can send emails immediately
- ✅ Professional enough for shipping notifications

**What you can send:**
- FROM: `dissonant.helpdesk@gmail.com`
- TO: Any email address (once out of sandbox)
- Perfect for order confirmations and shipping labels

#### Option B: Verify Domain (For production)
1. Click **"Create identity"**
2. Select **"Domain"**
3. Enter your domain (e.g., `dissonant.com`)
4. Add the required DNS TXT records to your domain
5. Wait for verification (can take up to 72 hours)

### 3. Create IAM User for SES Access

1. **Go to IAM Console** → **Users** → **Create user**
2. **Username**: `ses-lambda-user`
3. **Select**: "Programmatic access"
4. **Attach Policy**: Create custom policy (see below)

#### SES IAM Policy JSON:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail",
                "ses:GetSendQuota",
                "ses:GetSendStatistics"
            ],
            "Resource": "*"
        }
    ]
}
```

5. **Download credentials** (Access Key ID and Secret Access Key)

### 4. Configure Lambda Environment Variables

Add these environment variables to your Lambda function:

```bash
AWS_SES_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...  # From IAM user creation
AWS_SECRET_ACCESS_KEY=...  # From IAM user creation
```

#### In AWS Lambda Console:
1. Go to your Lambda function
2. **Configuration** → **Environment variables**
3. **Add** the three variables above

#### In Serverless Framework (serverless.yml):
```yaml
provider:
  environment:
    AWS_SES_REGION: us-east-1
    AWS_ACCESS_KEY_ID: ${env:AWS_ACCESS_KEY_ID}
    AWS_SECRET_ACCESS_KEY: ${env:AWS_SECRET_ACCESS_KEY}
```

### 5. Update Package Dependencies

Your package.json already includes the required dependencies:
- ✅ `aws-sdk: ^2.1691.0`
- ✅ `nodemailer: ^6.9.7`

Run: `npm install` to ensure they're installed.

### 6. Production Access (Important!)

#### Check if you're in Sandbox mode:
1. Go to **SES Console** → **Account dashboard**
2. Look for "Sending status"
3. If it says **"In the Amazon SES sandbox"**, you need to request production access

#### Request Production Access:
1. Click **"Request production access"**
2. **Mail type**: Select "Transactional"
3. **Website URL**: Your app/website URL
4. **Use case description**: 
   ```
   Sending order confirmation emails, shipping notifications, and tracking information 
   for our music subscription service. We send approximately 50-100 emails per day 
   to verified customers who have placed orders.
   ```
5. **Additional contact addresses**: Add any additional emails that should receive bounces/complaints
6. **Submit request**

**Note**: While in sandbox mode, you can only send emails to verified email addresses.

### 7. Test Configuration

#### Test 1: Use the improved test endpoint
```bash
curl -X POST https://your-lambda-url/test-email \
  -H "Content-Type: application/json" \
  -d '{"test_email": "dissonant.helpdesk@gmail.com"}'
```

#### Test 2: Check logs for SES confirmation
Look for these logs in CloudWatch:
- ✅ `Using Amazon SES for email transport`
- ✅ `Transporter verification successful`
- ✅ `Test email sent successfully`

### 8. Verify Email Delivery

1. **Check the recipient inbox** for the test email
2. **Check SES Console** → **Reputation tracking** → **Reputation metrics**
3. **Monitor bounce/complaint rates** (should be very low)

### 9. Configure Bounce/Complaint Handling (Optional but Recommended)

1. **Go to SES Console** → **Configuration sets**
2. **Create configuration set** for tracking
3. **Add event destinations** for bounces/complaints
4. **Set up SNS notifications** for bounce handling

## Troubleshooting

### Common Issues:

#### 1. "Email address not verified"
- **Solution**: Verify sender email in SES Console
- **Check**: "Verified identities" shows "Verified" status

#### 2. "Access Denied" errors
- **Solution**: Check IAM policy has SES permissions
- **Verify**: Access keys are correct in Lambda env vars

#### 3. "Still in sandbox mode"
- **Solution**: Request production access or verify recipient emails
- **Temporary**: Add recipient emails to verified identities

#### 4. "Region mismatch"
- **Solution**: Ensure Lambda and SES are in same region
- **Check**: Environment variable `AWS_SES_REGION` matches SES setup

### Environment Variables Checklist:
- ✅ `AWS_SES_REGION=us-east-1`
- ✅ `AWS_ACCESS_KEY_ID=AKIA...`
- ✅ `AWS_SECRET_ACCESS_KEY=...`

### SES Console Checklist:
- ✅ Identity verified (email or domain)
- ✅ IAM user created with SES permissions
- ✅ Production access requested (if needed)
- ✅ Same region as Lambda function

## Next Steps After Setup:

1. **Deploy updated Lambda function** with new environment variables
2. **Test email functionality** using `/test-email` endpoint
3. **Monitor CloudWatch logs** for SES success messages
4. **Test shipping label creation** end-to-end
5. **Monitor SES metrics** in AWS Console

The Lambda function will automatically detect the SES environment variables and use Amazon SES instead of Gmail.
