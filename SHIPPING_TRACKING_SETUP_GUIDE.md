# 📦 Shipping Tracking & Auto-Delivery Setup Guide

## ✅ What's Been Implemented

Your system can now **automatically detect when packages are delivered** and update order status in real-time!

### Changes Made:

#### 1. **Automatic Tracking Registration** (CRITICAL FIX)
- **File:** `my-express-app/dissonantservice/index.js` (after line 752)
- **What it does:** When shipping labels are created, tracking numbers are automatically registered with Shippo
- **Impact:** Shippo will now monitor packages and send webhooks when status changes

#### 2. **Scheduled Polling Backup** (NEW)
- **File:** `my-express-app/dissonantservice/index.js` (end of file)
- **What it does:** Runs every 6 hours to check "stale" orders (in transit for 12+ hours)
- **Impact:** Ensures orders update even if webhooks fail

#### 3. **Backfill Script** (NEW)
- **File:** `scripts/register_existing_tracking.js`
- **What it does:** Registers tracking numbers for existing orders
- **Impact:** Old orders will start receiving tracking updates

---

## 🚀 Complete Setup Instructions

### Step 1: Deploy Updated Backend

```bash
cd my-express-app/dissonantservice
serverless deploy
```

**Expected output:**
```
✅ Tracking check job scheduled (runs every 6 hours at :00)
Serverless: Packaging service...
Serverless: Uploading CloudFormation file to S3...
```

---

### Step 2: Configure Shippo Webhook (REQUIRED)

This is a **manual step** that must be done in the Shippo dashboard:

1. **Login to Shippo:** https://apps.goshippo.com
2. **Go to Settings → Webhooks**
3. **Click "Add Webhook"**
4. **Enter webhook URL:**
   ```
   https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/shippo-webhook
   ```
5. **Select these events:**
   - ✅ `track_updated`
   - ✅ `tracking_updated`
   - ✅ `shipment_updated`
6. **Click "Save"**
7. **Test the webhook** (optional but recommended)

**Screenshot locations to find:**
- Shippo Dashboard → Settings (gear icon) → Webhooks → + Add Webhook

---

### Step 3: Register Existing Tracking Numbers

For orders that already have tracking numbers (before this fix):

```bash
cd functions

# Preview what will be registered (dry run)
SHIPPO_TOKEN=your_shippo_token_here node ../scripts/register_existing_tracking.js --dry-run

# Actually register them
SHIPPO_TOKEN=your_shippo_token_here node ../scripts/register_existing_tracking.js
```

**Where to find Shippo token:**
- Shippo Dashboard → Settings → API → Live Token (or Test Token for testing)

**Expected output:**
```
✅ Registration Complete
📊 Total Orders: 15
✅ Registered: 15
⏭️  Skipped: 0
❌ Failed: 0

🎉 Tracking numbers are now registered with Shippo!
```

---

## 🧪 Testing the System

### Test 1: Webhook Simulation (Quick Test)

Test that your webhook endpoint works:

```bash
curl -X POST https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/test-webhook-simulation \
  -H "Content-Type: application/json" \
  -d '{
    "tracking_number": "ACTUAL_TRACKING_NUMBER_FROM_YOUR_ORDER",
    "status": "delivered"
  }'
```

**Expected result:**
- Order status changes to "delivered"
- Customer receives "DELIVERED" email
- Console logs show: `🎯 DELIVERY DETECTED: Package marked as delivered`

### Test 2: Real Package Test (Full End-to-End)

1. **Place a test order** through your app
2. **Ship the physical package** (or create a test label)
3. **Wait for USPS to scan** (~1-2 hours after pickup)
4. **Check your logs** for webhook notifications:
   ```bash
   # AWS CloudWatch Logs
   aws logs tail /aws/lambda/dissonantservice-dev-app --follow
   ```
5. **Verify order status** updates in Firestore
6. **Confirm customer receives emails**:
   - "SHIPPED" email when package is scanned
   - "DELIVERED" email when package arrives

### Test 3: Manual Status Check

Force-check a specific tracking number:

```bash
curl -X POST https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/check-order-status \
  -H "Content-Type: application/json" \
  -d '{
    "tracking_number": "YOUR_TRACKING_NUMBER"
  }'
```

---

## 📊 How the System Works

### Automatic Flow:

```
┌─────────────────┐
│ Label Created   │
│ (Your Backend)  │
└────────┬────────┘
         │
         ├─► Register with Shippo ✨ NEW
         │   (Tracking API)
         │
         ▼
┌─────────────────┐
│ Package Ships   │
│ (USPS Scans)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Shippo Detects  │
│ Status Change   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Webhook Fires   │  ◄── YOUR ENDPOINT
│ /shippo-webhook │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Order Updated   │
│ Email Sent      │
└─────────────────┘
```

### Backup Flow (Every 6 hours):

```
┌─────────────────┐
│ Cron Job Runs   │  ◄── Scheduled
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Find Stale      │
│ Orders (12h+)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Poll Shippo API │
│ Check Status    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update if       │
│ Status Changed  │
└─────────────────┘
```

---

## 🔍 Monitoring & Debugging

### CloudWatch Logs to Watch For:

**Good signs:**
- `📡 Registering outbound tracking ... with Shippo...`
- `✅ Outbound tracking registered successfully`
- `🔔 Received Shippo webhook`
- `🎯 DELIVERY DETECTED: Package marked as delivered`
- `✅ Updated order [orderId]`
- `📧 Sending delivered status email to customer...`

**Bad signs:**
- `⚠️ Failed to register outbound tracking`
- `❌ Webhook processing error`
- `❌ No orders found with tracking number`
- `❌ Failed to get tracking info`

### Debug Endpoints:

**Check order status by tracking number:**
```bash
curl -X POST https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/debug-order-status \
  -H "Content-Type: application/json" \
  -d '{"tracking_number": "YOUR_TRACKING"}'
```

**Response shows:**
- Which orders have that tracking number
- Current status in Firestore
- Last update timestamp

---

## 📋 Status Flow

| Shippo Status | Your Order Status | Email Sent? | User Can Order Again? |
|---------------|-------------------|-------------|----------------------|
| `pre_transit` | `labelCreated` | ❌ No | ❌ No |
| `in_transit` | `sent` | ✅ SHIPPED | ❌ No |
| `out_for_delivery` | `sent` | ❌ No | ❌ No |
| `delivered` | `delivered` | ✅ DELIVERED | ❌ No (can rate/return) |
| `returned` | `returned` | ✅ RETURNED | ❌ No (processing) |
| `returnedConfirmed` | `returnedConfirmed` | ❌ No | ✅ YES (can order) |
| `kept` | `kept` | ❌ No | ✅ YES (can order) |

---

## 🎛️ Configuration Options

### Adjust Polling Frequency

**File:** `my-express-app/dissonantservice/index.js`

**Current:** Every 6 hours
```javascript
const trackingCheckJob = schedule.scheduleJob('0 */6 * * *', async function() {
```

**Change to every 12 hours:**
```javascript
const trackingCheckJob = schedule.scheduleJob('0 */12 * * *', async function() {
```

**Cron syntax:** `'minute hour day month weekday'`
- `'0 */6 * * *'` = Every 6 hours at :00
- `'0 */12 * * *'` = Every 12 hours at :00
- `'0 0 * * *'` = Daily at midnight
- `'0 0,12 * * *'` = Daily at midnight and noon

### Adjust Stale Order Threshold

**Current:** 12 hours
```javascript
const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
```

**Change to 24 hours:**
```javascript
const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Backend deployed successfully
- [ ] Shippo webhook configured in dashboard
- [ ] Webhook URL is accessible (returns 200 OK)
- [ ] Existing tracking numbers registered (script ran successfully)
- [ ] Scheduled job shows in logs: `✅ Tracking check job scheduled`
- [ ] Test order status updates when webhook simulated
- [ ] Real package test successful (if possible)
- [ ] CloudWatch logs show tracking registration for new orders
- [ ] Email templates working (SHIPPED, DELIVERED, RETURNED)

---

## 🚨 Troubleshooting

### Issue: Webhooks not firing

**Check:**
1. Webhook URL configured in Shippo dashboard?
2. URL exactly: `https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/shippo-webhook`
3. Events selected: `track_updated`, `tracking_updated`, `shipment_updated`
4. Test webhook in Shippo dashboard (should return 200 OK)

**Solution:** Re-configure webhook in Shippo dashboard

### Issue: Orders not updating

**Check:**
1. Tracking numbers registered with Shippo?
2. Run: `curl https://api.goshippo.com/tracks/YOUR_TRACKING -H "Authorization: ShippoToken YOUR_TOKEN"`
3. Check CloudWatch logs for webhook events
4. Verify scheduled job is running (check logs every 6 hours)

**Solution:** Run `register_existing_tracking.js` script

### Issue: Emails not sending

**Check:**
1. `SENDGRID_API_KEY` or `EMAIL_USER`/`EMAIL_PASSWORD` set in environment?
2. CloudWatch logs show: `✅ [status] status email sent successfully`?
3. Check spam folder

**Solution:** Test email endpoint or reconfigure email settings

---

## 🎉 Success Indicators

You'll know it's working when:

1. ✅ New orders show: `✅ Outbound tracking registered successfully` in logs
2. ✅ Webhooks appear in logs: `🔔 Received Shippo webhook`
3. ✅ Order status automatically changes from `sent` → `delivered`
4. ✅ Customers receive delivery confirmation emails
5. ✅ Scheduled job runs without errors every 6 hours
6. ✅ No orders stuck in `sent` status for days

---

## 📞 Next Steps

1. **Deploy the updated backend** (Step 1)
2. **Configure Shippo webhook** (Step 2) ← **CRITICAL**
3. **Register existing tracking** (Step 3)
4. **Test with simulation** (Test 1)
5. **Monitor logs** for 24-48 hours
6. **Adjust polling frequency** if needed

---

Your shipping tracking system is now fully automated! 🚀📦✉️

