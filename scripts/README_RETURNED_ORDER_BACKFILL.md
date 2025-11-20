# Backfill Returned Order Free Credits Script

## Purpose

This script identifies and compensates users who had orders returned but didn't receive their free order credit due to the tracking webhook bug discovered in November 2024.

## The Bug

When packages were automatically returned to sender (detected via Shippo tracking webhooks), the system would:
- ✅ Update the order status to 'returned'
- ❌ **NOT grant the user a free order credit**

This affected users whose packages were returned by the carrier (undeliverable addresses, refused packages, returned to sender, etc.).

## What This Script Does

1. Finds all orders with status 'returned' and flowVersion >= 2
2. Groups them by user
3. Calculates how many free order credits each user should have received
4. Grants the missing credits by incrementing `freeOrdersAvailable`
5. Sets `freeOrder: true` for affected users
6. Logs all actions for audit purposes

## Prerequisites

- Node.js installed
- Firebase Admin SDK configured
- `serviceAccountKey.json` in the scripts directory
- Firebase Admin npm package: `npm install firebase-admin`

## Usage

### Dry Run (Recommended First)

Run in dry-run mode to see what changes would be made WITHOUT modifying the database:

```bash
cd scripts
node backfill_returned_order_free_credits.js --dry-run
```

This will show:
- How many returned orders were found
- Which users would receive credits
- How many credits each user would receive
- No database changes will be made

### Live Run

After reviewing the dry-run results, execute the actual backfill:

```bash
cd scripts
node backfill_returned_order_free_credits.js
```

⚠️ **Warning**: This will modify the database. Make sure you've reviewed the dry-run output first!

## Output

The script provides detailed output including:

### Progress Information
```
👤 User: user@example.com (userId123)
   📦 Returned orders: 2
   💳 Current free orders: 0
   🎁 Credits to grant: 2
   1. Order abc123 - Returned 11/1/2024
   2. Order def456 - Returned 11/5/2024
   ✅ Granted 2 free order credit(s)
   💳 New total: 2 free order(s) available
```

### Summary Statistics
```
📊 BACKFILL SUMMARY
Users processed:       15
Users skipped:         2
Total credits granted: 23
Total orders affected: 23
```

### Audit Log

In live mode, the script creates a JSON log file with detailed information:
- `backfill_log_YYYY-MM-DDTHH-MM-SS.json`

Example log entry:
```json
{
  "userId": "abc123",
  "email": "user@example.com",
  "creditsGranted": 2,
  "previousFreeOrders": 0,
  "newFreeOrders": 2,
  "orderIds": ["order1", "order2"]
}
```

## Database Changes

For each affected user, the script updates:

```javascript
{
  freeOrdersAvailable: <current + creditsToGrant>,
  freeOrder: true,
  updatedAt: <current timestamp>,
  lastCreditBackfill: {
    timestamp: <current timestamp>,
    creditsGranted: <number>,
    reason: 'returned_order_bug_fix',
    orderIds: [<array of order IDs>]
  }
}
```

## Safety Features

1. **Dry Run Mode**: Test before making changes
2. **Audit Trail**: `lastCreditBackfill` field tracks all backfills
3. **Error Handling**: Continues processing other users if one fails
4. **Detailed Logging**: Complete logs for troubleshooting
5. **No Order Modification**: Only updates user documents, not orders

## Verification

After running the script, verify a few users manually:

1. Check the Firebase Console for updated users
2. Verify `freeOrdersAvailable` increased correctly
3. Verify `freeOrder` is set to `true`
4. Check `lastCreditBackfill` field exists with correct data
5. Have a test user place a free order to confirm it works

## Rollback

If needed, you can rollback changes using the log file:

```javascript
// Example rollback script (create if needed)
const log = require('./backfill_log_TIMESTAMP.json');

for (const entry of log) {
  await db.collection('users').doc(entry.userId).update({
    freeOrdersAvailable: entry.previousFreeOrders,
    freeOrder: entry.previousFreeOrders > 0
  });
}
```

## Communication with Users

After running the backfill, consider:

1. **Email affected users**:
   - Apologize for the inconvenience
   - Explain the bug has been fixed
   - Confirm their free order credits have been added
   - Thank them for their patience

2. **Optional: Grant bonus credit**:
   - Consider giving an extra credit as goodwill
   - Shows commitment to customer satisfaction

## Monitoring

After deployment:

1. Monitor backend logs for "🎁 Package returned" messages
2. Verify new returns automatically grant credits
3. Check for any error logs related to free order granting
4. Monitor support tickets for similar complaints

## Related Files

- `../RETURNED_ORDER_FREE_ORDER_FIX.md` - Complete bug fix documentation
- `../my-express-app/dissonantservice/index.js` - Backend fix
- `../lib/screens/return_album_screen.dart` - Frontend fix
- This script: `backfill_returned_order_free_credits.js`

## Support

If you encounter issues:

1. Check the script output for error messages
2. Review the Firebase Console for user/order data
3. Check Firebase Admin SDK permissions
4. Verify `serviceAccountKey.json` is valid
5. Check Node.js version compatibility

## Notes

- Only processes orders with flowVersion >= 2 (current system)
- Skips users who don't exist in the database
- Handles multiple returned orders per user correctly
- Idempotent: Can be run multiple times safely (adds on top of current credits)



