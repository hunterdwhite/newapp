# Shipping Label Creation Reliability Improvements

## Problem
30-40% of orders were not triggering the GoShippo shipping label creation endpoint. The Lambda function had no logs, indicating the request never reached the server.

## Root Causes
1. **Client-side dependency**: Shipping labels were created synchronously on the client before submitting the order, meaning network issues, timeouts, or app crashes could prevent the request from reaching Lambda
2. **No retry mechanism**: If the initial request failed, there was no automatic retry
3. **Blocking flow**: The label creation blocked order submission, but failures were silently caught, leading to orders without labels

## Solution

### 1. Firebase Cloud Function (Primary Mechanism)
Created `functions/index.js` with `onCreateOrder` Cloud Function that:
- **Triggers automatically** when an order is created in Firestore
- **Runs server-side** (more reliable than client-side)
- **Includes retry logic** with exponential backoff (3 attempts: 2s, 4s, 8s delays)
- **Prevents duplicates** by checking if labels already exist before creating
- **Handles errors gracefully** by logging to `failed_label_creations` collection
- **Stores label data** in the order document for tracking

### 2. Client-Side Changes (Secondary/Non-Blocking)
Updated order creation flow in:
- `lib/screens/order_screen.dart`
- `lib/screens/checkout_screen.dart`

Changes:
- **Order is created FIRST** in Firestore (triggers Cloud Function)
- **Client-side label creation is non-blocking** (fire-and-forget)
- **10-second timeout** to prevent hanging
- **Errors are logged but don't block** order submission

### 3. Order Document Schema
Orders now include a `shippingLabels` field:
```javascript
{
  created: boolean,
  status: 'creating' | 'success' | 'failed',
  orderId: string,
  outboundLabel: {...},
  returnLabel: {...},
  error: string (if failed),
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## Deployment Steps

### 1. Deploy Firebase Cloud Function
```bash
cd functions
npm install  # Ensure dependencies are installed
firebase deploy --only functions:onCreateOrder
```

### 2. Verify Function Deployment
```bash
firebase functions:log --only onCreateOrder
```

### 3. Test the Solution
1. Create a test order through the app
2. Check Firestore - the order document should have `shippingLabels` field
3. Check Cloud Function logs - should see label creation attempt
4. Check Lambda logs - should see the request from Cloud Function
5. Verify labels are created and emails are sent

### 4. Monitor Failed Label Creations
Query the `failed_label_creations` collection in Firestore to see any failures:
```javascript
db.collection('failed_label_creations')
  .orderBy('timestamp', 'desc')
  .limit(10)
  .get()
```

## How It Works

### Flow 1: Cloud Function (Primary)
1. User places order → Order created in Firestore
2. Cloud Function triggers automatically
3. Function parses address, gets user email
4. Calls Lambda endpoint with retry logic
5. Updates order document with label data

### Flow 2: Client-Side (Secondary)
1. User places order → Order created in Firestore
2. Client attempts to create labels (non-blocking)
3. If successful, great! If not, Cloud Function handles it

## Benefits

1. **Much higher reliability**: Server-side execution means labels are created even if:
   - User closes the app immediately
   - Network connection is poor
   - Client-side code crashes
   - Device goes to sleep

2. **Automatic retries**: If Lambda is temporarily unavailable, Cloud Function retries up to 3 times

3. **No duplicates**: Checks if labels already exist before creating

4. **Better monitoring**: Failed attempts are logged to `failed_label_creations` collection

5. **Faster user experience**: Order submission doesn't wait for label creation

## Monitoring

### Success Metrics
- Check `shippingLabels.created === true` in order documents
- Monitor Cloud Function execution logs
- Check Lambda logs for successful label creation

### Failure Indicators
- Orders with `shippingLabels.status === 'failed'`
- Entries in `failed_label_creations` collection
- Cloud Function error logs

## Troubleshooting

### If labels still aren't being created:

1. **Check Cloud Function logs**:
   ```bash
   firebase functions:log --only onCreateOrder
   ```

2. **Check if function is deployed**:
   ```bash
   firebase functions:list
   ```

3. **Verify Firestore trigger**:
   - Create a test order
   - Check if function executes (look for logs)

4. **Check Lambda endpoint**:
   - Verify the endpoint URL is correct
   - Check Lambda logs in AWS Console
   - Verify environment variables are set

5. **Check address parsing**:
   - Ensure order addresses are in format: "Name\nStreet\nCity, State Zip"
   - Check Cloud Function logs for parsing errors

6. **Check user email**:
   - Verify user document has email field
   - Or verify Auth user has email
   - Check Cloud Function logs for email retrieval errors

## Expected Reliability

With this solution, shipping label creation should succeed in **95%+ of cases** because:
- Server-side execution (no client dependency)
- Automatic retries (handles temporary failures)
- Redundant paths (client + Cloud Function)
- Error handling and logging (easy to identify issues)


