# Lambda Function Testing Guide for AWS CLI

## 🚀 **Function Overview**

**Function Name**: `dissonantservice-dev-api`  
**API Gateway ID**: `86ej4qdp9i`  
**Base URL**: `https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev`  
**AWS Profile**: `utenatenjou25`  
**Region**: `us-east-1`

## 📋 **Available Endpoints**

### 1. **Test Email Functionality**
**Endpoint**: `POST /test-email`  
**Purpose**: Test Amazon SES email configuration

#### PowerShell Command:
```powershell
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/test-email" -Method POST -ContentType "application/json" -Body '{"test_email":"dissonant.helpdesk@gmail.com"}'
```

#### Expected Response:
```json
{
  "success": true,
  "message": "Test email sent successfully",
  "messageId": "<unique-message-id>",
  "emailUser": "utenatenjou25@gmail.com",
  "transporterType": "SESTransporter",
  "recipient": "dissonant.helpdesk@gmail.com",
  "timestamp": "2025-08-25T19:xx:xx.xxxZ"
}
```

### 2. **Create Payment Intent (Stripe)**
**Endpoint**: `POST /create-payment-intent`

#### PowerShell Command:
```powershell
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent" -Method POST -ContentType "application/json" -Body '{"amount":2000}'
```

### 3. **Address Validation (Shippo)**
**Endpoint**: `POST /validate-address`

#### PowerShell Command:
```powershell
$addressData = @{
    "name" = "John Doe"
    "street1" = "123 Main St"
    "city" = "New York"
    "state" = "NY"
    "zip" = "10001"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/validate-address" -Method POST -ContentType "application/json" -Body $addressData
```

### 4. **Create Shipping Labels**
**Endpoint**: `POST /create-shipping-labels`

#### PowerShell Command:
```powershell
$shippingData = @{
    "to_address" = @{
        "name" = "John Doe"
        "street1" = "123 Main St"
        "city" = "New York"
        "state" = "NY"
        "zip" = "10001"
        "country" = "US"
    }
    "parcel" = @{
        "length" = "12"
        "width" = "12"
        "height" = "4"
        "distance_unit" = "in"
        "weight" = "1"
        "mass_unit" = "lb"
    }
    "order_id" = "TEST-ORDER-123"
    "customer_name" = "John Doe"
    "customer_email" = "dissonant.helpdesk@gmail.com"
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels" -Method POST -ContentType "application/json" -Body $shippingData
```

### 5. **Check Order Status**
**Endpoint**: `POST /check-order-status`

#### PowerShell Command:
```powershell
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/check-order-status" -Method POST -ContentType "application/json" -Body '{"tracking_number":"1Z12345E1234567890","order_id":"TEST-ORDER-123"}'
```

### 6. **PayPal Payment (Mock)**
**Endpoint**: `POST /create-paypal-payment`

#### PowerShell Command:
```powershell
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-paypal-payment" -Method POST -ContentType "application/json" -Body '{"amount":"20.00","currency":"USD"}'
```

## 🔧 **AWS CLI Testing Commands**

### Get Function Information:
```bash
aws lambda get-function --function-name dissonantservice-dev-api --profile utenatenjou25
```

### Get Function Configuration:
```bash
aws lambda get-function-configuration --function-name dissonantservice-dev-api --profile utenatenjou25
```

### Invoke Function Directly (AWS CLI):
```bash
aws lambda invoke --function-name dissonantservice-dev-api --profile utenatenjou25 --payload '{"httpMethod":"POST","path":"/test-email","body":"{\"test_email\":\"dissonant.helpdesk@gmail.com\"}","headers":{"Content-Type":"application/json"}}' response.json
```

### View Function Logs:
```bash
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/dissonantservice-dev-api" --profile utenatenjou25
```

### Get Recent Logs:
```bash
aws logs filter-log-events --log-group-name "/aws/lambda/dissonantservice-dev-api" --profile utenatenjou25 --start-time $(date -d "1 hour ago" +%s)000
```

## 📊 **Monitoring & Debugging**

### CloudWatch Logs Location:
- **Log Group**: `/aws/lambda/dissonantservice-dev-api`
- **Console URL**: `https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/$252Faws$252Flambda$252Fdissonantservice-dev-api`

### SES Metrics:
```bash
aws ses get-send-statistics --profile utenatenjou25
```

### View SES Verified Identities:
```bash
aws ses list-verified-email-addresses --profile utenatenjou25
```

## 🧪 **Quick Health Check**

Run this command to verify everything is working:

```powershell
# Test email functionality
$response = Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/test-email" -Method POST -ContentType "application/json" -Body '{"test_email":"dissonant.helpdesk@gmail.com"}'

if ($response.success) {
    Write-Host "✅ Lambda function is healthy!" -ForegroundColor Green
    Write-Host "📧 Email sent with Message ID: $($response.messageId)" -ForegroundColor Green
    Write-Host "🚀 Transporter: $($response.transporterType)" -ForegroundColor Green
} else {
    Write-Host "❌ Lambda function test failed!" -ForegroundColor Red
}
```

## 🔍 **Troubleshooting**

### Common Issues:

#### 1. **"Forbidden" Error**
- **Cause**: Missing `/dev` stage in URL
- **Fix**: Use `https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/endpoint`

#### 2. **Email Not Sending**
- **Check**: CloudWatch logs for SES errors
- **Verify**: Email is verified in SES console
- **Command**: `aws ses list-verified-email-addresses --profile utenatenjou25`

#### 3. **Function Timeout**
- **Check**: CloudWatch logs for timeout errors
- **Fix**: Increase Lambda timeout (currently 30s)

#### 4. **AWS CLI Auth Issues**
- **Fix**: Refresh SSO login
- **Command**: `aws sso login --profile utenatenjou25`

### Debug Commands:

#### Get Last 10 Log Events:
```bash
aws logs filter-log-events --log-group-name "/aws/lambda/dissonantservice-dev-api" --profile utenatenjou25 --limit 10
```

#### Check Environment Variables:
```bash
aws lambda get-function-configuration --function-name dissonantservice-dev-api --profile utenatenjou25 --query "Environment.Variables"
```

## 📝 **Environment Variables Configured**

- ✅ `AWS_SES_REGION=us-east-1`
- ✅ `EMAIL_USER=dissonant.helpdesk@gmail.com`
- ✅ SES permissions attached to Lambda role

## 🎯 **Success Indicators**

When everything is working correctly, you should see:

1. **✅ API Response**: `"success": true`
2. **✅ Email Delivery**: Test email in inbox
3. **✅ CloudWatch Logs**: `"Using Amazon SES for email transport"`
4. **✅ SES Console**: Send statistics showing successful sends

## 📚 **Related Documentation**

- [SES Setup Guide](./SES_SETUP_GUIDE.md)
- [Email Debug Guide](./EMAIL_DEBUG_GUIDE.md)
- [AWS Lambda Console](https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/dissonantservice-dev-api)
- [API Gateway Console](https://console.aws.amazon.com/apigateway/home?region=us-east-1#/apis/86ej4qdp9i)

---

**Last Updated**: August 25, 2025  
**Function Version**: Latest  
**SES Status**: ✅ Configured and Working
