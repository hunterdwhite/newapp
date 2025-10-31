# Free Order Event Remote Control

This guide explains how to remotely control the "free order for new users" feature via Firestore without redeploying the app.

## Overview

The app now checks the `app_config/pricing_config` Firestore document to determine if new users should receive free orders. This allows you to:
- ✅ Turn the anniversary event ON/OFF remotely
- ✅ Control how many free orders new users get
- ✅ No code deployment required
- ✅ Changes take effect for new registrations immediately

## Firestore Configuration

### Collection: `app_config`
### Document: `pricing_config`

Add these fields to your existing pricing_config document:

```json
{
  "dissonantPrices": [7.99, 9.99, 12.99],
  "communityPrices": [5.99, 7.99, 9.99],
  "defaultShippingCost": 4.99,
  "giveNewUsersFreeOrder": true,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": true
}
```

## Field Descriptions

### `giveNewUsersFreeOrder` (boolean)
- **Type**: Boolean (true/false)
- **Purpose**: Master switch to enable/disable free orders for new users
- **Default**: `false` (if not set or can't be read)
- **Effect**: 
  - `true` = New users get free orders
  - `false` = New users don't get free orders

### `newUserFreeOrderCount` (number)
- **Type**: Integer
- **Purpose**: Number of free orders to give new users
- **Default**: `1` (if not set or can't be read)
- **Effect**: Sets `freeOrdersAvailable` field for new users
- **Note**: Only applies when `giveNewUsersFreeOrder` is `true`

### `showAnniversaryCard` (boolean)
- **Type**: Boolean (true/false)
- **Purpose**: Controls whether the anniversary event card appears on home screen
- **Default**: `false` (if not set or can't be read)
- **Effect**:
  - `true` = Anniversary card shows on home screen carousel
  - `false` = Anniversary card is hidden from home screen
- **Note**: Changes take effect immediately when users refresh home screen

## How It Works

### Registration Flow
1. User registers for a new account
2. App fetches `app_config/pricing_config` from Firestore
3. Checks `giveNewUsersFreeOrder` value
4. If `true`:
   - Sets user's `freeOrder` = `true`
   - Sets user's `freeOrdersAvailable` = `newUserFreeOrderCount`
5. If `false`:
   - Sets user's `freeOrder` = `false`
   - Sets user's `freeOrdersAvailable` = `0`

### User Document Structure
```json
{
  "username": "NewUser123",
  "email": "user@example.com",
  "freeOrder": true,                  // ← Controlled by app_config
  "freeOrdersAvailable": 1,           // ← Controlled by app_config
  "freeOrderCredits": 0,
  // ... other fields
}
```

## Setting Up the Configuration

### Method 1: Firebase Console (Recommended)

1. Go to Firebase Console → Firestore Database
2. Navigate to `app_config` collection
3. Open the `pricing_config` document
4. Add or update fields:
   - Field: `giveNewUsersFreeOrder`
   - Type: `boolean`
   - Value: `true` (for anniversary event)
   
   - Field: `newUserFreeOrderCount`
   - Type: `number`
   - Value: `1`

5. Click "Update"

### Method 2: Using Firebase CLI/Admin SDK

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

await db.collection('app_config').doc('pricing_config').update({
  giveNewUsersFreeOrder: true,
  newUserFreeOrderCount: 1
});
```

### Method 3: Update Existing Document

If you already have a `pricing_config` document, just add the new fields:

```bash
# In Firebase Console, edit the existing document
# Add these two fields to your existing pricing configuration
```

## Use Cases

### 🎉 Anniversary Event (Active)
Turn ON everything for the full event experience:
```json
{
  "giveNewUsersFreeOrder": true,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": true
}
```
**Result**: 
- ✅ Anniversary card visible on home screen
- ✅ New users get 1 free order

### 🛑 After Anniversary Event (Inactive)
Turn OFF everything when event ends:
```json
{
  "giveNewUsersFreeOrder": false,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": false
}
```
**Result**:
- ❌ Anniversary card hidden from home screen
- ❌ New users don't get free orders

### 🎁 Special Promotion (Double Free Orders)
Give new users 2 free orders with visible card:
```json
{
  "giveNewUsersFreeOrder": true,
  "newUserFreeOrderCount": 2,
  "showAnniversaryCard": true
}
```

### 📅 Regular Operation (No Free Orders)
Normal state (no event):
```json
{
  "giveNewUsersFreeOrder": false,
  "newUserFreeOrderCount": 0,
  "showAnniversaryCard": false
}
```

## Timeline: Anniversary Event Control

### Starting the Event
**When**: Anniversary event begins
**Action**: 
```json
{
  "giveNewUsersFreeOrder": true,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": true
}
```
**Result**: 
- ✅ Anniversary card appears on home screen for all users
- ✅ New users registering will get 1 free order

### Ending the Event
**When**: Anniversary event ends
**Action**:
```json
{
  "giveNewUsersFreeOrder": false,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": false
}
```
**Result**: 
- ❌ Anniversary card disappears from home screen for all users
- ❌ New users registering will NOT get free orders

⏱️ **Changes take effect**: 
- Home screen card: Within 30 minutes (cached) or immediately on app refresh
- New user free orders: Immediately for new registrations
📝 **Existing users**: NOT affected (keeps their current free order status)

## Important Notes

### ✅ Who Gets Free Orders
- **New users** registering WHILE the setting is `true`
- Users who **complete registration** during the event period

### ❌ Who Doesn't Get Free Orders
- Users who **already registered** (setting doesn't retroactively change existing users)
- New users registering AFTER you set `giveNewUsersFreeOrder` to `false`

### 🔄 Caching
- Configuration is cached for 30 minutes
- New user registrations always fetch fresh data from Firestore
- No app restart needed for changes to take effect

### 🔒 Security
- Only admins can write to `app_config` (controlled by Firestore rules)
- All authenticated users can read the configuration
- Configuration is validated and has safe defaults

## Testing

### Test New User Registration
1. Set `giveNewUsersFreeOrder` to `true` in Firestore
2. Register a new test account
3. Check the new user document:
   - Should have `freeOrder: true`
   - Should have `freeOrdersAvailable: 1`
4. Open app with test account
5. Navigate to order screen
6. Should see "Free Order" option for community curators

### Test Event End
1. Set `giveNewUsersFreeOrder` to `false` in Firestore
2. Register another new test account
3. Check the new user document:
   - Should have `freeOrder: false`
   - Should have `freeOrdersAvailable: 0`
4. Open app with test account
5. Should NOT see free order options

## Monitoring

### Check Configuration Status
**Firebase Console**: 
- Go to Firestore → `app_config` → `pricing_config`
- Check current value of `giveNewUsersFreeOrder`

### Verify User Creation
Check a recent user document:
```
Firestore → users → {recent_user_id}
Look for:
- freeOrder: true/false
- freeOrdersAvailable: 0 or 1+
```

### Debug Issues
If users aren't getting free orders when they should:
1. ✅ Check `giveNewUsersFreeOrder` is `true` in Firestore
2. ✅ Verify Firestore security rules allow reading `app_config`
3. ✅ Check app logs for any configuration fetch errors
4. ✅ Try clearing the pricing service cache

## Troubleshooting

### Issue: New users still getting free orders after setting to false
**Cause**: User registered before you changed the setting
**Solution**: This is expected - only affects NEW registrations

### Issue: New users not getting free orders when setting is true
**Check**:
1. Field name is exactly `giveNewUsersFreeOrder` (case-sensitive)
2. Value type is boolean, not string
3. Document path is `app_config/pricing_config`
4. Firestore rules allow reading the document

### Issue: Configuration not loading
**Fallback Behavior**: 
- If config can't be loaded, defaults to `giveNewUsersFreeOrder: false`
- This is a safe default to prevent unintended free orders
**Fix**: Check Firestore rules and document existence

## Firestore Rules

Make sure your `firestore.rules` includes:

```javascript
match /app_config/{configId} {
  // Allow all users to read app configuration
  allow read: if true;
  // Only admins can write configuration
  allow write: if isAuthenticated() && isAdmin();
}
```

## Complete Configuration Example

Full `app_config/pricing_config` document for anniversary event:

```json
{
  "dissonantPrices": [7.99, 9.99, 12.99],
  "communityPrices": [5.99, 7.99, 9.99],
  "defaultShippingCost": 4.99,
  "giveNewUsersFreeOrder": true,
  "newUserFreeOrderCount": 1,
  "showAnniversaryCard": true,
  "eventDescription": "1 Year Anniversary - Free orders for new users",
  "eventStartDate": "2024-10-30",
  "eventEndDate": "2024-11-15"
}
```

Note: The last three fields are optional and just for your reference.

## Quick Reference

| Action | giveNewUsersFreeOrder | newUserFreeOrderCount | showAnniversaryCard | Result |
|--------|----------------------|----------------------|---------------------|---------|
| Start Event | `true` | `1` | `true` | Card visible + New users get 1 free order |
| End Event | `false` | `1` | `false` | Card hidden + New users get 0 free orders |
| Card Only | `false` | `0` | `true` | Card visible + No free orders |
| Double Promo | `true` | `2` | `true` | Card visible + New users get 2 free orders |
| Normal State | `false` | `0` | `false` | Card hidden + New users get 0 free orders |

---

**Remember**: 
- ✅ Changes are instant for new registrations
- ✅ No app deployment required
- ✅ Existing users are not affected
- ✅ Safe defaults if config fails to load

