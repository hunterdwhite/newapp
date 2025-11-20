# Anniversary Free Order Grant Script

## Quick Start

### 1. Set Up Authentication

**Option A: Service Account (Recommended)**

1. Download service account key:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to **Project Settings** → **Service Accounts**
   - Click **Generate New Private Key**
   - Save as `serviceAccountKey.json` (keep it secure!)

2. Set environment variable:

**Windows PowerShell:**
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="$PWD\serviceAccountKey.json"
```

**Windows CMD:**
```cmd
set GOOGLE_APPLICATION_CREDENTIALS=%CD%\serviceAccountKey.json
```

**Mac/Linux:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/serviceAccountKey.json"
```

**Option B: Firebase CLI**
```bash
firebase login
```

### 2. Run the Script

**Dry Run (Preview - Recommended First):**
```bash
cd functions
node ../scripts/grant_anniversary_free_orders.js --dry-run
```

**Live Execution:**
```bash
cd functions
node ../scripts/grant_anniversary_free_orders.js
```

## What the Script Does

✅ **Grants 1 free order to existing users who:**
- Have NOT placed an order yet (`hasOrdered: false` or not set)
- Do NOT already have a free order

❌ **Skips users who:**
- Have already placed at least one order
- Already have `freeOrder: true` or `freeOrdersAvailable > 0`

## Command Options

```bash
--dry-run          # Preview only, no changes made
--batch-size=N     # Process N users per batch (default: 500)
```

## Examples

```bash
# Preview what will happen
cd functions && node ../scripts/grant_anniversary_free_orders.js --dry-run

# Actually grant free orders
cd functions && node ../scripts/grant_anniversary_free_orders.js

# Process in smaller batches (for large user bases)
cd functions && node ../scripts/grant_anniversary_free_orders.js --batch-size=100

# Combine options
cd functions && node ../scripts/grant_anniversary_free_orders.js --dry-run --batch-size=250
```

## Expected Output

### Dry Run Output:
```
🎉 DISSONANT 1 YEAR ANNIVERSARY - FREE ORDER GRANT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mode: 🔍 DRY RUN (Preview Only)
Batch Size: 500 users
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏳ Fetching users from Firestore...

📊 Found 1,234 total users

🔍 Analyzing eligibility...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Users:                 1,234
Eligible for Free Order:     856 🎁
Already Have Free Order:     12
Already Placed Order:        366

856 users WOULD RECEIVE a free order

💡 Run without --dry-run to actually grant free orders
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Distribution:
   • 69.4% eligible for free order
   • 29.7% already placed orders
   • 1.0% already have free orders
```

### Live Execution Output:
```
🎉 DISSONANT 1 YEAR ANNIVERSARY - FREE ORDER GRANT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mode: ✅ LIVE UPDATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   💾 Committing batch of 500 updates...
      ✅ john_doe (john@example.com)
      ✅ jane_smith (jane@example.com)
      ... (498 more)
   
   💾 Committing final batch of 356 updates...
      ✅ user_name (user@example.com)
      ... (355 more)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Users:                 1,234
Eligible for Free Order:     856 🎁
Already Have Free Order:     12
Already Placed Order:        366

Updated:                     856 ✅
Errors:                      0

✨ Free orders have been granted!
```

## Safety Features

✅ **Idempotent** - Safe to run multiple times, won't duplicate free orders
✅ **Batched** - Processes users in batches to avoid Firestore limits
✅ **Dry-run** - Preview changes before applying them
✅ **Error handling** - Gracefully handles errors and continues processing
✅ **Detailed logging** - Shows exactly which users are being updated

## Troubleshooting

### Error: "Unable to detect a Project Id"
**Cause:** Firebase authentication not configured

**Solution:**
1. Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable
2. OR run `firebase login`

### Error: "Cannot find module 'firebase-admin'"
**Cause:** firebase-admin not installed

**Solution:**
```bash
cd functions
npm install
```

### Error: "Permission denied"
**Cause:** Service account doesn't have Firestore permissions

**Solution:**
1. Go to Firebase Console → IAM & Admin
2. Find your service account
3. Add role: **Cloud Datastore User** or **Firebase Admin**

### Error: "DEADLINE_EXCEEDED" or timeout
**Cause:** Too many users to process in one go

**Solution:** Use smaller batch size:
```bash
node ../scripts/grant_anniversary_free_orders.js --batch-size=100
```

### Script hangs or is very slow
**Cause:** Large user base

**Solution:** This is normal for large databases. The script shows progress. You can:
- Use smaller batch sizes
- Let it run (it will complete eventually)
- Stop and restart (it's idempotent)

## FAQs

**Q: Can I run this multiple times?**
A: Yes! It's safe. It only updates users who don't already have free orders.

**Q: What if I stop the script mid-execution?**
A: You can safely restart it. It will skip users who were already updated.

**Q: Will this affect users who sign up during execution?**
A: No. This script only affects existing users. New users get free orders automatically via the `giveNewUsersFreeOrder` config setting.

**Q: How long does it take?**
A: Approximately:
- 1,000 users: 30-60 seconds
- 10,000 users: 3-5 minutes
- 100,000 users: 30-45 minutes

**Q: Can I customize the number of free orders?**
A: Yes! Edit line 114 in `grant_anniversary_free_orders.js`:
```javascript
freeOrdersAvailable: 2,  // Change from 1 to 2 (or any number)
```

**Q: How do I verify it worked?**
A: Check Firestore Console → users collection. Look for:
- `freeOrder: true`
- `freeOrdersAvailable: 1`

---

**Need more help?** See `ANNIVERSARY_EVENT_LAUNCH.md` for the complete event launch guide.


