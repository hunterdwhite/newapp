# Testing Your Email Templates

## 📍 **Email Location:**
**File**: `my-express-app/dissonantservice/index.js`
**Lines**: 544-576 (Customer email when order is processed)
**Trigger**: `/create-shipping-labels` endpoint

## 🧪 **Testing Methods:**

### **Method 1: Via Your App (Recommended)**
1. Place an order through your Flutter app
2. Complete the payment/shipping flow
3. Check your email for the "DISSONANT ORDER RECEIVED" message

### **Method 2: Direct API Test (If Shippo is configured)**
```bash
curl -X POST https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels \
  -H "Content-Type: application/json" \
  -d '{
    "to_address": {
      "name": "Test Customer",
      "street1": "123 Main Street", 
      "city": "New York",
      "state": "NY",
      "zip": "10001",
      "country": "US"
    },
    "parcel": {
      "length": "12",
      "width": "12", 
      "height": "4",
      "distance_unit": "in",
      "weight": "1",
      "mass_unit": "lb"
    },
    "order_id": "TEST-123",
    "customer_name": "Test Customer",
    "customer_email": "your-email@gmail.com"
  }'
```

### **Method 3: Mock Test (For Email Only)**
Create a simple test endpoint that sends just the email part.

## 📧 **Current Customer Email Template:**

**Subject**: `DISSONANT ORDER RECEIVED`

**Content**:
```
DISSONANT ORDER RECEIVED

Hi [customer_name],

Your order has been receieved. A curator will select an album for you and ship it soon!
TRACKING #: [tracking_number]

Questions? Reply to this email or contact us at dissonant.helpdesk@gmail.com

DISSONANT
```

## 🚚 **For "Actually Shipped" Notifications:**

If you want a separate email when the package is **actually shipped** (not just when labels are created), you would need to:

1. **Add a new email template** for "shipped" status
2. **Use Shippo webhooks** to detect when packages are actually picked up
3. **Create a tracking update system** that sends emails based on USPS tracking status

## 🎯 **Best Testing Approach:**

Since your Shippo token needs to be configured first, the most reliable test is:

1. **Fix your Shippo token** (get it from https://apps.goshippo.com/settings/api)
2. **Update Lambda environment** with real Shippo token
3. **Test through your app** by placing a real order
4. **Check email** for your updated template

This ensures the full flow works as your customers will experience it.
