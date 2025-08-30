# Quick Test Commands - Lambda Function

## 🚀 **One-Line Health Check**

```powershell
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/test-email" -Method POST -ContentType "application/json" -Body '{"test_email":"dissonant.helpdesk@gmail.com"}'
```

**Expected**: `success: True`, email delivered to inbox

## 📧 **Email Test (SES)**
```powershell
# Test email functionality
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/test-email" -Method POST -ContentType "application/json" -Body '{"test_email":"dissonant.helpdesk@gmail.com"}'
```

## 💳 **Payment Test (Stripe)**
```powershell
# Test payment intent creation
Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent" -Method POST -ContentType "application/json" -Body '{"amount":2000}'
```

## 📦 **Shipping Labels Test (Shippo)**
```powershell
# Test shipping label creation
$shippingData = @{
    "to_address" = @{
        "name" = "Test User"
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
    "order_id" = "TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
    "customer_name" = "Test User"
    "customer_email" = "dissonant.helpdesk@gmail.com"
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels" -Method POST -ContentType "application/json" -Body $shippingData
```

## 🔍 **Quick Debug Commands**

### Check Lambda Function Status:
```bash
aws lambda get-function --function-name dissonantservice-dev-api --profile utenatenjou25 --query "Configuration.{State:State,LastModified:LastModified}"
```

### Get Recent Logs:
```bash
aws logs filter-log-events --log-group-name "/aws/lambda/dissonantservice-dev-api" --profile utenatenjou25 --limit 5 --query "events[].message" --output text
```

### Check SES Send Statistics:
```bash
aws ses get-send-statistics --profile utenatenjou25
```

## 🔧 **Environment Variables Check**
```bash
aws lambda get-function-configuration --function-name dissonantservice-dev-api --profile utenatenjou25 --query "Environment.Variables"
```

## 📊 **Function Info**
- **API URL**: `https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev`
- **Function**: `dissonantservice-dev-api`
- **Profile**: `utenatenjou25`
- **Region**: `us-east-1`
