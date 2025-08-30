# Email Debugging Guide for Lambda Function

## Issues Identified & Solutions Implemented

### 1. **Primary Issue: Gmail Authentication in Lambda**
Gmail's SMTP often gets blocked in serverless environments due to security restrictions and dynamic IP addresses.

### 2. **Background Email Processing**
The original code sent emails in the background, which could time out before completion in Lambda.

## Solutions Implemented

### Multi-Transport Configuration
The function now supports three email providers in order of preference:

1. **Amazon SES** (Recommended for Lambda)
2. **SendGrid** (Reliable alternative)
3. **Gmail SMTP** (Fallback)

### Environment Variables Required

#### For Amazon SES:
```bash
AWS_SES_REGION=us-east-1  # or your preferred region
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
```

#### For SendGrid:
```bash
SENDGRID_API_KEY=your_sendgrid_api_key
```

#### For Gmail (Fallback):
```bash
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-specific-password  # NOT your regular password
```

## Debugging Steps

### 1. Test Email Functionality
Call the improved test endpoint:
```bash
POST /test-email
{
  "test_email": "your-email@example.com"
}
```

### 2. Check CloudWatch Logs
Look for these specific log messages:
- `Using Amazon SES for email transport`
- `Using SendGrid for email transport`  
- `Using Gmail for email transport (fallback)`
- Email verification success/failure
- Detailed error messages with codes

### 3. Common Error Codes & Solutions

#### SMTP Errors:
- `ENOTFOUND` / `ECONNREFUSED`: Network connectivity issues
- `535 Authentication failed`: Wrong credentials
- `550 Relay denied`: Email provider blocking

#### Solutions:
1. **Switch to SES**: Most reliable for Lambda
2. **Use SendGrid**: Good alternative with API-based sending
3. **Gmail Setup**: Ensure app-specific password is used

## Recommended Setup: Amazon SES

### 1. Enable SES in AWS Console
1. Go to Amazon SES in AWS Console
2. Verify your domain or email address
3. Request production access (if needed)
4. Create IAM user with SES permissions

### 2. IAM Policy for SES
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. Lambda Environment Variables
Set these in your Lambda function configuration:
```
AWS_SES_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

## Alternative: SendGrid Setup

### 1. Create SendGrid Account
1. Sign up at sendgrid.com
2. Verify your sender email/domain
3. Create API key with Mail Send permissions

### 2. Lambda Environment Variable
```
SENDGRID_API_KEY=SG....
```

## Gmail Setup (Not Recommended for Production)

### 1. Enable 2FA on Gmail Account
### 2. Create App-Specific Password
1. Go to Google Account settings
2. Security → 2-Step Verification → App passwords
3. Generate password for "Mail"

### 3. Lambda Environment Variables
```
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=generated-app-password
```

## New Features Added

### 1. Failed Email Logging
Failed emails are now logged to Firestore collection `failed_emails` for manual retry.

### 2. Retry Logic
Emails are retried up to 3 times with exponential backoff.

### 3. Comprehensive Logging
Detailed logs help identify exactly where the failure occurs.

### 4. Immediate Processing
Emails are now sent in the foreground to ensure completion.

## Testing Checklist

1. ✅ Deploy updated Lambda function
2. ✅ Set appropriate environment variables
3. ✅ Call `/test-email` endpoint
4. ✅ Check CloudWatch logs for detailed output
5. ✅ Verify email delivery
6. ✅ Test shipping label creation

## Troubleshooting Commands

### Check Environment Variables
```javascript
console.log('EMAIL_USER:', process.env.EMAIL_USER);
console.log('AWS_SES_REGION:', process.env.AWS_SES_REGION);
console.log('SENDGRID_API_KEY exists:', !!process.env.SENDGRID_API_KEY);
```

### Manual Email Test
```bash
curl -X POST https://your-lambda-url/test-email \
  -H "Content-Type: application/json" \
  -d '{"test_email": "your-email@example.com"}'
```

## Next Steps

1. **Choose email provider** (SES recommended)
2. **Set environment variables** in Lambda
3. **Update dependencies** (`npm install`)
4. **Deploy function**
5. **Test with `/test-email` endpoint**
6. **Monitor CloudWatch logs**

The root cause is most likely Gmail authentication issues in the Lambda environment. Switching to Amazon SES or SendGrid should resolve the email delivery problems.
