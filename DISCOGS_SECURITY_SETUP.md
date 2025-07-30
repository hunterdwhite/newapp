# Discogs Security Fix - Deployment Guide

## Overview

This fix addresses the security vulnerability where Discogs OAuth consumer credentials were hardcoded in client-side code. The credentials have been moved to secure Firebase Cloud Functions.

## Changes Made

### 1. Created Secure Service
- **File**: `lib/services/discogs_service.dart`
- **Purpose**: Centralized Discogs API interactions using secure credentials from Cloud Functions
- **Features**: 
  - Fetches OAuth credentials securely from backend
  - Handles OAuth flow
  - Manages API calls to Discogs

### 2. Updated Cloud Functions
- **File**: `functions/index.js`
- **Added**: `getDiscogsCredentials` function
- **Purpose**: Securely provides OAuth credentials to authenticated users only

### 3. Updated Client Files
- **Files Modified**:
  - `lib/screens/my_music_library_screen.dart`
  - `lib/screens/wishlist_screen.dart`
  - `lib/screens/link_discogs_screen.dart`
- **Changes**: Removed hardcoded credentials, now use secure service

## Deployment Steps

### 1. Set Environment Variables in Firebase Functions

Add the Discogs OAuth credentials to your Firebase Functions environment:

```bash
cd functions
firebase functions:config:set discogs.consumer_key="YOUR_DISCOGS_CONSUMER_KEY"
firebase functions:config:set discogs.consumer_secret="YOUR_DISCOGS_CONSUMER_SECRET"
```

Or if using newer Firebase Functions (recommended):

```bash
cd functions
echo "DISCOGS_CONSUMER_KEY=YOUR_DISCOGS_CONSUMER_KEY" >> .env
echo "DISCOGS_CONSUMER_SECRET=YOUR_DISCOGS_CONSUMER_SECRET" >> .env
```

**⚠️ IMPORTANT**: 
- Replace `YOUR_DISCOGS_CONSUMER_KEY` and `YOUR_DISCOGS_CONSUMER_SECRET` with the actual values
- The old hardcoded values were:
  - Consumer Key: `EzVdIgMVbCnRNcwacndA`
  - Consumer Secret: `CUqIDOCeEoFmREnzjKqTmKpstenTGnsE`
- **DO NOT commit the .env file to version control**

### 2. Deploy Firebase Functions

```bash
cd functions
firebase deploy --only functions
```

### 3. Update Firebase Security Rules

Ensure your Firestore security rules allow authenticated users to read/write their Discogs data:

```javascript
// In firestore.rules
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4. Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

### 5. Deploy Client App

Build and deploy your Flutter app as usual:

```bash
flutter build appbundle  # for Android
flutter build ios        # for iOS
```

## Security Benefits

1. **No Client-Side Secrets**: OAuth credentials are no longer exposed in client code
2. **Authentication Required**: Cloud Function requires user authentication to access credentials
3. **Centralized Management**: All Discogs API interactions go through a secure service
4. **Environment Variables**: Credentials stored securely in Firebase environment

## Testing

1. **Test OAuth Flow**: Verify that linking Discogs accounts still works
2. **Test Collection/Wantlist**: Ensure data loading works correctly
3. **Test Authentication**: Verify that unauthenticated users cannot access credentials

## Rollback Plan

If issues arise, you can temporarily revert by:

1. Reverting the client files to use hardcoded credentials (NOT RECOMMENDED)
2. Or fixing the Cloud Function configuration and redeploying

## Monitoring

Monitor the following for issues:
- Firebase Functions logs for `getDiscogsCredentials` function
- Client-side errors related to Discogs authentication
- User reports of linking/syncing issues

## Additional Security Recommendations

1. **Rotate Credentials**: Consider rotating Discogs OAuth credentials periodically
2. **Monitor Usage**: Set up alerts for unusual Discogs API usage
3. **Rate Limiting**: Consider adding rate limiting to prevent abuse
4. **Audit Logs**: Monitor who accesses Discogs credentials

## Files Modified

### New Files
- `lib/services/discogs_service.dart` - Secure service for Discogs API
- `DISCOGS_SECURITY_SETUP.md` - This documentation

### Modified Files
- `functions/index.js` - Added secure credentials endpoint
- `lib/services/services.dart` - Added discogs_service export
- `lib/screens/my_music_library_screen.dart` - Uses secure service
- `lib/screens/wishlist_screen.dart` - Uses secure service  
- `lib/screens/link_discogs_screen.dart` - Uses secure service

### Dependencies
- `cloud_functions: ^5.1.3` (already present in pubspec.yaml)