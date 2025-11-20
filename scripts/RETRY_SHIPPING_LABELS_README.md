# Retry Failed Shipping Labels Script

This script retries shipping label creation for orders that failed or never got labels, perfect for recovering from payment issues or service disruptions.

## What It Does

1. Queries Firestore for orders without shipping labels (`shippingLabels.created != true`)
2. For each order, parses the address and retrieves user email
3. Calls the Lambda endpoint to create shipping labels
4. Updates the order document with the shipping label URLs and tracking numbers
5. Provides a summary of successes and failures

## Prerequisites

- Firebase Admin SDK (already installed in `functions/node_modules`)
- Axios (already installed in `functions/node_modules`)
- Service account key file (`scripts/serviceAccountKey.json`)

## Usage

### 1. First, do a dry run to preview what would be processed:

```bash
cd functions
node ../scripts/retry_failed_shipping_labels.js --dry-run
```

This will show you:
- How many orders are missing shipping labels
- Order IDs and details
- What would be processed (without actually creating labels)

### 2. If everything looks good, run it for real:

```bash
cd functions
node ../scripts/retry_failed_shipping_labels.js
```

This will:
- Create shipping labels for all orders without labels
- Update the order documents in Firestore
- Send email notifications to customers
- Show a summary of successes and failures

### 3. Retry a specific order only:

```bash
cd functions
node ../scripts/retry_failed_shipping_labels.js --order-id=YOUR_ORDER_ID
```

Replace `YOUR_ORDER_ID` with the actual Firestore document ID of the order.

## Options

- `--dry-run`: Preview what would be processed without actually creating labels
- `--order-id=ORDER_ID`: Process a specific order ID only

## What Gets Updated in Firestore

For each successful label creation, the script updates the order document with:

```javascript
{
  shippingLabels: {
    created: true,
    status: 'success',
    outboundLabelUrl: 'https://...',
    returnLabelUrl: 'https://...',
    outboundTrackingNumber: '...',
    returnTrackingNumber: '...',
    orderId: 'ORDER-...',
    createdAt: <timestamp>,
    createdBy: 'retry-script'
  }
}
```

For failed attempts, it updates:

```javascript
{
  shippingLabels: {
    status: 'failed',
    error: '<error message>',
    updatedAt: <timestamp>
  }
}
```

## Output Example

```
✅ Firebase Admin initialized with service account

🔍 Searching for all orders without shipping labels...

📋 Found 5 orders without shipping labels

Order ID: abc123xyz
  Status: new
  User: user123
  Address: John Doe, 123 Main St, New York, NY 10001...
  Current shipping label status: none

📦 Processing order: abc123xyz
  ✅ Parsed address: John Doe New York NY
  ✅ Retrieved user email: john@example.com
  🚀 Calling Lambda endpoint...
  ✅ Shipping labels created successfully!

... (more orders)

============================================================
📊 SUMMARY
============================================================
Total orders processed: 5
✅ Successful: 5
❌ Failed: 0

✅ Script completed!
```

## Troubleshooting

### "Order not found"
The order ID you specified doesn't exist in Firestore. Double-check the order ID.

### "Missing userId in order data"
The order document is missing the `userId` field. Check the order data in Firestore.

### "Missing address in order data"
The order document is missing the `address` field. Check the order data in Firestore.

### "Could not retrieve user email"
The user document doesn't exist or doesn't have an email field. Check the users collection.

### "Address parsing failed"
The address format is invalid. The script expects addresses in one of these formats:
- `Name\nStreet\nCity, State Zip`
- `Name, Street, City, State Zip`

### "401 Shippo Error token does not exist"
Your Shippo API token is invalid or has expired. Check the `SHIPPO_TOKEN` environment variable in your Lambda function.

### Lambda endpoint timeout
The Lambda function took too long to respond. This might indicate an issue with the Shippo API or your Lambda function. Check CloudWatch logs.

## Safety Features

- **Dry run mode**: Preview changes before making them
- **Duplicate prevention**: Won't create labels if they already exist
- **Error handling**: Failed orders are logged and the script continues
- **Rate limiting**: 1 second delay between requests
- **Detailed logging**: Every step is logged for debugging

## When to Use This Script

Use this script when:
- Your Shippo account ran out of funds and orders didn't get labels
- The Lambda endpoint was down during order placement
- The Cloud Function failed for some orders
- You need to recreate labels for specific orders
- You want to bulk-create labels for orders that were created manually

## Important Notes

1. **Customer emails**: The script will send emails to customers with their shipping labels. Make sure your SendGrid API key is configured correctly in the Lambda function.

2. **Costs**: Each label creation costs money through Shippo. Review the dry run output before running for real.

3. **Idempotency**: The script is safe to run multiple times. It only processes orders where `shippingLabels.created != true`.

4. **Order status**: The script doesn't change the order status. If you need to update order statuses, do that separately.







