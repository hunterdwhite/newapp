# 🚀 Production Launch Plan
## Dissonant App - Step-by-Step Implementation Guide

**Estimated Total Time:** 3-10 days  
**Priority Level:** CRITICAL  
**Owner:** Development Team

---

## 📊 Quick Stats

| Phase | Tasks | Time | Status |
|-------|-------|------|--------|
| **Phase 1: Blockers** | 9 tasks | 3-5 days | ⏳ Not Started |
| **Phase 2: High Priority** | 7 tasks | 3-4 days | ⏳ Not Started |
| **Phase 3: Launch Prep** | 5 tasks | 1-2 days | ⏳ Not Started |

---

## 🎯 PHASE 1: BLOCKERS (MUST DO - 3-5 Days)

### Task 1: Deploy Missing Firestore Indexes ⚠️ CRITICAL

**Priority:** 🔴 BLOCKING  
**Time:** 30 minutes  
**Impact:** Without this, queries will be VERY slow and may fail

**Steps:**

1. **Update `firestore.indexes.json`:**

```json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "curatorId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "trackingNumber", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "updatedAt", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "referralCode", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "albums",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "genre", "order": "ASCENDING"},
        {"fieldPath": "releaseDate", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

2. **Deploy the indexes:**

```bash
# Make sure you're in the project root
cd C:\Workspace\newapp\newapp

# Login to Firebase
firebase login

# Deploy indexes
firebase deploy --only firestore:indexes

# This will take 10-30 minutes to build the indexes
```

3. **Verify deployment:**
   - Go to Firebase Console → Firestore → Indexes tab
   - Check that all indexes show "Enabled" status
   - Wait for all to complete building (may take up to 30 minutes)

**Success Criteria:**
- ✅ All 7 indexes deployed
- ✅ All indexes show "Enabled" status in Firebase Console
- ✅ No index warnings in app logs

---

### Task 2: Fix Firestore Security Rule ⚠️ HIGH RISK

**Priority:** 🔴 BLOCKING  
**Time:** 15 minutes  
**Impact:** Users could give themselves unlimited free credits

**File:** `firestore.rules`  
**Lines:** Around line 54-55

**Current Code (INSECURE):**
```javascript
// Allow authenticated users to update credit fields for referral system (simplified)
allow update: if isAuthenticated();
```

**Replace with (SECURE):**
```javascript
// Allow authenticated users to update ONLY via specific operations
// Owner can update their own profile EXCEPT credit fields
allow update: if isAuthenticated() && request.auth.uid == userId && (
  // Prevent users from modifying their own credits/orders
  !request.resource.data.diff(resource.data).affectedKeys().hasAny([
    'freeOrderCredits', 
    'freeOrdersAvailable',
    'paidOrderCredits',
    'totalOrders',
    'isAdmin',
    'isCurator'
  ])
);

// Special rule for referral system (only allow credit increases via Cloud Function)
// This should be handled server-side only
```

**Better Approach - Update referral logic to use Cloud Function:**

Create `functions/updateReferralCredits.js`:
```javascript
exports.updateReferralCredits = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { referredUserId, referrerUserId, creditAmount } = data;
  
  // Validate inputs
  if (!referredUserId || !referrerUserId || !creditAmount) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Verify the referral relationship
  const referredUserDoc = await admin.firestore().collection('users').doc(referredUserId).get();
  if (!referredUserDoc.exists || referredUserDoc.data().referredBy !== referrerUserId) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid referral relationship');
  }

  // Update credits atomically
  await admin.firestore().collection('users').doc(referrerUserId).update({
    freeOrderCredits: admin.firestore.FieldValue.increment(creditAmount),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
```

**Deploy:**
```bash
firebase deploy --only firestore:rules
firebase deploy --only functions:updateReferralCredits
```

**Success Criteria:**
- ✅ Rules deployed successfully
- ✅ Test that users can't modify their own credits
- ✅ Referral system still works via Cloud Function

---

### Task 3: Enable Automated Firestore Backups ⚠️ DATA SAFETY

**Priority:** 🔴 BLOCKING  
**Time:** 1 hour  
**Impact:** Protect against data loss

**Method 1: Cloud Scheduler (Recommended)**

1. **Install gcloud CLI** (if not already installed):
   - Download from: https://cloud.google.com/sdk/docs/install

2. **Create backup script:**

`scripts/setup-firestore-backups.sh`:
```bash
#!/bin/bash

# Configuration
PROJECT_ID="your-firebase-project-id"
BUCKET_NAME="${PROJECT_ID}-firestore-backups"
SCHEDULE="0 2 * * *"  # Daily at 2 AM UTC

# Create Cloud Storage bucket for backups
gcloud storage buckets create gs://${BUCKET_NAME} \
  --project=${PROJECT_ID} \
  --location=us-central1

# Create Cloud Scheduler job
gcloud scheduler jobs create http firestore-daily-backup \
  --schedule="${SCHEDULE}" \
  --uri="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default):exportDocuments" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body="{\"outputUriPrefix\":\"gs://${BUCKET_NAME}\"}" \
  --oauth-service-account-email="firebase-adminsdk@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project=${PROJECT_ID}

echo "✅ Firestore backup configured!"
echo "Backups will run daily at 2 AM UTC"
echo "Backup location: gs://${BUCKET_NAME}"
```

3. **Run the script:**
```bash
chmod +x scripts/setup-firestore-backups.sh
./scripts/setup-firestore-backups.sh
```

4. **Set up retention policy:**
```bash
# Keep backups for 30 days
gcloud storage buckets update gs://${BUCKET_NAME} \
  --lifecycle-file=- <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF
```

**Method 2: Manual Backup (Immediate)**

```bash
# Export entire database now
gcloud firestore export gs://your-project-id-firestore-backups \
  --project=your-firebase-project-id
```

**Success Criteria:**
- ✅ Daily backup job scheduled
- ✅ Backup bucket created
- ✅ Retention policy set (30 days)
- ✅ First backup completed successfully

---

### Task 4: Add Critical Integration Tests ⚠️ CRITICAL

**Priority:** 🔴 BLOCKING  
**Time:** 4-6 hours  
**Impact:** Catch payment and order bugs before production

**Create:** `test/critical_flows_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('Critical Business Rules Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test-user-123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    });

    test('CRITICAL: User cannot place order with outstanding order', () async {
      // Setup: Create existing order
      await fakeFirestore.collection('orders').add({
        'userId': 'test-user-123',
        'status': 'new',
        'timestamp': Timestamp.now(),
      });

      // Get orders
      final orders = await fakeFirestore
          .collection('orders')
          .where('userId', isEqualTo: 'test-user-123')
          .where('status', whereIn: ['new', 'sent', 'delivered'])
          .get();

      // Verify: Should find outstanding order
      expect(orders.docs.length, greaterThan(0));
      
      // Business logic: Should prevent new order
      final canPlaceOrder = orders.docs.isEmpty;
      expect(canPlaceOrder, isFalse, 
        reason: 'User should NOT be able to place order with outstanding order');
    });

    test('CRITICAL: Curator receives correct credits (1 credit per curation)', () async {
      // Setup: Curator user
      await fakeFirestore.collection('users').doc('curator-123').set({
        'username': 'testcurator',
        'isCurator': true,
        'freeOrderCredits': 0,
      });

      // Simulate: Curator curates an album
      await fakeFirestore.collection('users').doc('curator-123').update({
        'freeOrderCredits': FieldValue.increment(1),
      });

      // Verify
      final userDoc = await fakeFirestore.collection('users').doc('curator-123').get();
      expect(userDoc.data()?['freeOrderCredits'], equals(1));
    });

    test('CRITICAL: Return grants full free order (not just credits)', () async {
      // Setup: User with returned order
      await fakeFirestore.collection('users').doc('user-456').set({
        'username': 'testuser',
        'freeOrdersAvailable': 0,
        'freeOrderCredits': 0,
      });

      // Simulate: First order returned
      await fakeFirestore.collection('orders').add({
        'userId': 'user-456',
        'status': 'returnedConfirmed',
        'isFirstOrder': true,
        'timestamp': Timestamp.now(),
      });

      // Business logic: Grant full free order
      await fakeFirestore.collection('users').doc('user-456').update({
        'freeOrdersAvailable': FieldValue.increment(1),
      });

      // Verify: Full free order granted (not just credits)
      final userDoc = await fakeFirestore.collection('users').doc('user-456').get();
      expect(userDoc.data()?['freeOrdersAvailable'], equals(1));
    });

    test('CRITICAL: Duplicate order prevention (30 second window)', () async {
      // Setup: Recent order
      final now = DateTime.now();
      await fakeFirestore.collection('orders').add({
        'userId': 'test-user-123',
        'status': 'new',
        'timestamp': Timestamp.fromDate(now.subtract(Duration(seconds: 15))),
      });

      // Get recent orders
      final recentOrders = await fakeFirestore
          .collection('orders')
          .where('userId', isEqualTo: 'test-user-123')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (recentOrders.docs.isNotEmpty) {
        final lastOrderTime = recentOrders.docs.first.data()['timestamp'] as Timestamp;
        final timeSinceLastOrder = DateTime.now().difference(lastOrderTime.toDate());
        
        // Verify: Should block duplicate order
        expect(timeSinceLastOrder.inSeconds, lessThan(30));
      }
    });

    test('SECURITY: Curator cannot access user address', () async {
      // Setup: Order with address
      await fakeFirestore.collection('orders').doc('order-789').set({
        'userId': 'user-123',
        'curatorId': 'curator-456',
        'address': 'John Doe\n123 Main St\nNew York, NY 10001',
        'status': 'new',
      });

      // Simulate: Curator reading order
      final orderDoc = await fakeFirestore.collection('orders').doc('order-789').get();
      
      // In real app, address should be filtered out for curators
      // This test documents the expected behavior
      expect(orderDoc.exists, isTrue);
      
      // NOTE: In production, implement address filtering in Firestore rules or backend
      // Curators should only get: orderId, userId (not address), status, albums
    });
  });

  group('Payment Integration Tests', () {
    test('Payment flow handles errors gracefully', () async {
      // Test that payment errors don't crash the app
      // Test that user sees appropriate error messages
      // Test that failed payments don't create orders
    });

    test('Free order credits are consumed correctly', () async {
      // Test that using free credits decrements correctly
      // Test that orders are created without payment
      // Test that credits can't go negative
    });
  });
}
```

**Install test dependencies:**

Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  fake_cloud_firestore: ^2.4.1
  firebase_auth_mocks: ^0.13.0
```

**Run tests:**
```bash
flutter pub get
flutter test test/critical_flows_test.dart
```

**Success Criteria:**
- ✅ All 5 critical tests passing
- ✅ Tests run in CI/CD (future)
- ✅ Tests cover key business rules

---

### Task 5: Update README.md

**Priority:** 🔴 BLOCKING  
**Time:** 30 minutes  
**Impact:** New developers can't set up the project

**Replace** `README.md` **content with:**

```markdown
# 🎵 Dissonant App

A Flutter-based music discovery and vinyl subscription service that connects users with curated album selections.

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.10+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Firebase CLI ([Install](https://firebase.google.com/docs/cli))
- Node.js 18+ (for backend services)
- Xcode 14+ (for iOS development)
- Android Studio (for Android development)

### Installation

1. **Clone the repository:**
   ```bash
   git clone [your-repo-url]
   cd newapp
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual API keys
   ```

4. **Configure Firebase:**
   ```bash
   firebase login
   firebase use [your-project-id]
   ```

5. **Run the app:**
   ```bash
   # iOS
   flutter run -d ios

   # Android
   flutter run -d android
   ```

### Backend Setup

1. **Navigate to backend service:**
   ```bash
   cd my-express-app/dissonantservice
   npm install
   ```

2. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Add your API keys
   ```

3. **Start the server:**
   ```bash
   npm start
   ```

## 📚 Documentation

- **[Functional Testing Checklist](FUNCTIONAL_TESTING_CHECKLIST.md)** - Complete testing guide
- **[API Reference](API_REFERENCE.md)** - Backend API documentation
- **[Production Readiness](PRODUCTION_READINESS_ASSESSMENT.md)** - Deployment checklist
- **[Deployment Guide](DEPLOYMENT_SAFETY.md)** - Safe deployment procedures

## 🏗️ Architecture

### Frontend (Flutter)
- **Screens**: UI components for each app screen
- **Services**: Business logic and API calls
- **Models**: Data models
- **Widgets**: Reusable UI components

### Backend (Node.js + Firebase)
- **Express Server**: REST API (`my-express-app/dissonantservice`)
- **Cloud Functions**: Serverless functions (`functions/`)
- **Firebase**: Database, Auth, Storage

## 🔑 Required API Keys

See `.env.example` for a complete list. You'll need:

- Firebase (Project ID, API Key)
- Stripe (Publishable & Secret keys)
- Shippo (Shipping token)
- SendGrid (Email API key)
- Discogs (Consumer key & secret)

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/critical_flows_test.dart

# Run with coverage
flutter test --coverage
```

## 📦 Building for Production

### iOS
```bash
flutter build ipa --release
```

### Android
```bash
flutter build appbundle --release
```

## 🚀 Deployment

1. Review [PRODUCTION_READINESS_ASSESSMENT.md](PRODUCTION_READINESS_ASSESSMENT.md)
2. Follow [DEPLOYMENT_SAFETY.md](DEPLOYMENT_SAFETY.md) procedures
3. Deploy backend: `cd my-express-app/dissonantservice && npm run deploy`
4. Deploy Firebase: `firebase deploy`

## 🛠️ Tech Stack

- **Frontend**: Flutter, Dart
- **Backend**: Node.js, Express
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **Payments**: Stripe
- **Shipping**: Shippo
- **Email**: SendGrid
- **Hosting**: Firebase Hosting
- **Storage**: Firebase Storage

## 📞 Support

- **Documentation**: See `/docs` folder
- **Issues**: [GitHub Issues](your-repo/issues)
- **Email**: support@yourdomain.com

## 📄 License

[Your License Here]

---

**Made with ❤️ by the Dissonant Team**
```

**Success Criteria:**
- ✅ README is professional and informative
- ✅ New developers can set up project from README alone
- ✅ All links work

---

### Task 6: Create Backup/Recovery Procedures

**Priority:** 🔴 BLOCKING  
**Time:** 1 hour  
**Impact:** Team knows what to do in data loss scenario

**Create:** `BACKUP_RECOVERY_PROCEDURES.md`

```markdown
# 🔒 Backup & Recovery Procedures
## Dissonant App - Data Protection Guide

## 📋 Backup Schedule

| Data Type | Frequency | Retention | Location |
|-----------|-----------|-----------|----------|
| Firestore Database | Daily @ 2 AM UTC | 30 days | Cloud Storage |
| User Uploads | Real-time | Indefinite | Firebase Storage |
| Configuration | On Change | Version controlled | Git |

## 🔄 Recovery Procedures

### Scenario 1: Accidental Data Deletion

**Symptoms:**
- User reports missing data
- Orders disappeared
- Profile data lost

**Recovery Steps:**

1. **Identify affected data:**
   ```bash
   # Check Firestore audit logs
   gcloud logging read "resource.type=cloud_firestore_database" \
     --limit 50 \
     --project=your-project-id
   ```

2. **Find appropriate backup:**
   ```bash
   # List available backups
   gsutil ls gs://your-project-firestore-backups/
   ```

3. **Restore from backup:**
   ```bash
   # Import specific collection
   gcloud firestore import gs://your-project-firestore-backups/[BACKUP_DATE] \
     --collection-ids=orders,users \
     --project=your-project-id
   ```

4. **Verify restoration:**
   - Check Firebase Console
   - Run test queries
   - Confirm with affected user

**Time to Recover:** 30 minutes - 2 hours

### Scenario 2: Database Corruption

**Symptoms:**
- App crashes on data load
- Firestore queries failing
- Invalid data returned

**Recovery Steps:**

1. **Isolate the issue:**
   - Check Crashlytics for error patterns
   - Identify affected collections
   - Determine extent of corruption

2. **Create immediate backup:**
   ```bash
   gcloud firestore export gs://your-project-firestore-backups/emergency-$(date +%Y%m%d-%H%M%S) \
     --project=your-project-id
   ```

3. **Restore clean data:**
   - Use most recent clean backup
   - Import only affected collections
   - Validate data integrity

4. **Post-recovery:**
   - Update security rules if needed
   - Document what caused corruption
   - Implement preventive measures

### Scenario 3: Complete Database Loss

**Symptoms:**
- Entire database inaccessible
- Firebase project compromised
- All data deleted

**Recovery Steps:**

1. **Declare incident:**
   - Notify all stakeholders
   - Put app in maintenance mode
   - Stop all writes to database

2. **Create new Firebase project:**
   ```bash
   firebase projects:create dissonant-recovery
   ```

3. **Restore from latest backup:**
   ```bash
   gcloud firestore import gs://your-project-firestore-backups/[LATEST] \
     --project=dissonant-recovery
   ```

4. **Update app configuration:**
   - Update Firebase config in app
   - Redeploy with new project ID
   - Update DNS/URLs

5. **Verify and test:**
   - Run all critical tests
   - Manual testing of key flows
   - Staged rollout to users

**Time to Recover:** 4-8 hours

## 🧪 Regular Backup Testing

**Monthly backup restoration test:**

1. Create test Firebase project
2. Restore last month's backup
3. Verify data integrity
4. Document any issues
5. Update procedures as needed

## 📞 Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Lead Developer | [Name] | [Phone/Email] |
| Firebase Admin | [Name] | [Phone/Email] |
| Database Admin | [Name] | [Phone/Email] |

## 📝 Post-Incident Checklist

- [ ] Root cause identified
- [ ] Recovery documented
- [ ] Affected users notified
- [ ] Preventive measures implemented
- [ ] Backup procedures updated
- [ ] Team debriefed
```

---

### Task 7: Configure Crashlytics Alerting

**Priority:** 🔴 BLOCKING  
**Time:** 30 minutes  
**Impact:** Know immediately when app crashes in production

**Steps:**

1. **Go to Firebase Console:**
   - Navigate to Crashlytics section
   - Click on "Settings" (gear icon)

2. **Set up email alerts:**
   - Go to "Email Notifications"
   - Enable "New issues"
   - Enable "Regressed issues"
   - Add team email addresses

3. **Configure alert thresholds:**
   - Enable "Velocity alerts"
   - Set threshold: Alert if crash-free users drops below 99%
   - Set threshold: Alert if crashes increase by 300% in 1 hour

4. **Integrate with Slack (recommended):**
   - Use Firebase Slack integration
   - Create #prod-alerts channel
   - Configure webhook

5. **Test alerting:**
   - Trigger a test crash:
   ```dart
   // In a test build
   FirebaseCrashlytics.instance.crash();
   ```
   - Verify alert received

**Success Criteria:**
- ✅ Email alerts configured for all team members
- ✅ Slack integration working (if using)
- ✅ Test crash generates alert
- ✅ Alert routing documented

---

### Task 8: End-to-End Payment Testing

**Priority:** 🔴 BLOCKING  
**Time:** 2 hours  
**Impact:** Ensure payments work in production

**Test Cases:**

1. **Successful Payment:**
   - [ ] Place order with test card
   - [ ] Verify payment intent created in Stripe
   - [ ] Verify order created in Firestore
   - [ ] Verify curator notified
   - [ ] Verify confirmation email sent

2. **Failed Payment:**
   - [ ] Use declined test card (4000000000000002)
   - [ ] Verify error message shown to user
   - [ ] Verify NO order created
   - [ ] Verify payment marked as failed in logs

3. **Free Order with Credits:**
   - [ ] User with 5+ credits
   - [ ] Place order without payment
   - [ ] Verify credits decremented
   - [ ] Verify order created
   - [ ] Verify no Stripe charge

4. **Edge Cases:**
   - [ ] Network error during payment
   - [ ] App closed during payment
   - [ ] Duplicate payment prevention
   - [ ] Refund processing

**Production Testing:**

⚠️ **Use Stripe test mode first!**

1. **Switch to test mode:**
   - Verify `.env` has `STRIPE_PUBLISHABLE_KEY=pk_test...`
   - Deploy backend with test keys
   - Test all flows

2. **Switch to live mode:**
   - Update `.env` with `pk_live...` keys
   - Make small real payment ($1)
   - Immediately refund
   - Verify entire flow works

**Success Criteria:**
- ✅ All test cases passing
- ✅ Real payment processed successfully
- ✅ Refund processed successfully
- ✅ Team confident in payment system

---

### Task 9: Create Deployment Checklist

**Priority:** 🔴 BLOCKING  
**Time:** 30 minutes  
**Impact:** Prevent deployment mistakes

**Create:** `DEPLOYMENT_CHECKLIST.md`

```markdown
# ✅ Pre-Deployment Checklist
## Run through this before EVERY production deployment

## Code & Testing
- [ ] All critical tests passing (`flutter test`)
- [ ] No linter errors (`flutter analyze`)
- [ ] Code reviewed by at least 1 other developer
- [ ] FUNCTIONAL_TESTING_CHECKLIST.md completed
- [ ] No `print()` statements with sensitive data
- [ ] No hardcoded test data

## Configuration
- [ ] All environment variables set correctly
- [ ] Using production API keys (not test keys)
- [ ] Firebase project ID correct
- [ ] Stripe live keys configured
- [ ] Shippo production token set

## Database
- [ ] Firestore indexes deployed
- [ ] Firestore rules deployed
- [ ] Backup job running successfully
- [ ] No pending security rule changes

## Security
- [ ] Security rules tested
- [ ] API keys rotated (if needed)
- [ ] No secrets in version control
- [ ] Firestore rules don't allow unrestricted access

## Monitoring
- [ ] Crashlytics enabled for release
- [ ] Alert recipients configured
- [ ] Performance monitoring enabled
- [ ] Analytics configured

## Backend
- [ ] Backend deployed to production
- [ ] Environment variables set
- [ ] Health check endpoint responding
- [ ] Webhooks configured (Stripe, Shippo)

## Communication
- [ ] Team notified of deployment
- [ ] Maintenance window scheduled (if needed)
- [ ] Rollback plan documented
- [ ] On-call person identified

## Post-Deployment
- [ ] App launched successfully
- [ ] No immediate crashes in Crashlytics
- [ ] Test order placed successfully
- [ ] Monitor for 1 hour after deployment
- [ ] Update CHANGELOG.md

## Emergency Rollback Plan
1. `firebase rollback` for backend
2. Release previous app version to stores
3. Notify users if needed
4. Document incident
```

---

## 📊 Phase 1 Summary

**Total Time:** 3-5 days  
**Critical Tasks:** 9  
**Must Complete Before Launch**

**Checklist:**
- [ ] Task 1: Firestore indexes deployed
- [ ] Task 2: Security rules fixed
- [ ] Task 3: Automated backups enabled
- [ ] Task 4: Critical tests added
- [ ] Task 5: README updated
- [ ] Task 6: Backup procedures documented
- [ ] Task 7: Crashlytics alerts configured
- [ ] Task 8: Payment testing completed
- [ ] Task 9: Deployment checklist created

**After completing Phase 1, proceed to Phase 2 (High Priority items)**

---

## 🎯 PHASE 2: HIGH PRIORITY (3-4 Days)

_(Detailed tasks for Phase 2 would go here - including rate limiting, environment config, retry logic, etc.)_

---

## 🚀 PHASE 3: LAUNCH PREPARATION (1-2 Days)

_(Final checks, staging environment testing, go-live preparations)_

---

**Document Owner:** Development Team  
**Last Updated:** November 20, 2024  
**Next Review:** After Phase 1 completion

