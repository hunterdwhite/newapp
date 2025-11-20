# API Reference - Dissonant App 2

## Table of Contents
1. [Firebase Services](#firebase-services)
2. [Data Models](#data-models)
3. [Cloud Functions](#cloud-functions)
4. [External APIs](#external-apis)
5. [Authentication](#authentication)
6. [Database Schema](#database-schema)
7. [Error Handling](#error-handling)

## Firebase Services

### FirestoreService
The main service class handling all database operations.

**Location**: `lib/services/firestore_service.dart`

#### Core Methods

##### User Management
```dart
Future<bool> checkUsernameExists(String username)
Future<void> addUsername(String username, String userId)
Future<void> deleteUserData(String userId)
Future<bool> hasOutstandingOrders(String userId)
```

##### Order Management
```dart
Future<void> createOrder(OrderData orderData)
Future<List<Order>> getUserOrders(String userId)
Future<void> updateOrderStatus(String orderId, String status)
```

##### Music Library
```dart
Future<void> addAlbumToLibrary(String userId, Album album)
Future<List<Album>> getUserLibrary(String userId)
Future<void> removeAlbumFromLibrary(String userId, String albumId)
```

### PaymentService
Handles Stripe payment processing.

**Location**: `lib/services/payment_service.dart`

```dart
class PaymentService {
  Future<bool> processPayment(double amount, String currency);
  Future<String> createPaymentIntent(double amount);
  Future<bool> confirmPayment(String paymentIntentId);
}
```

### UspsAddressService
Address validation and formatting service.

**Location**: `lib/services/usps_address_service.dart`

```dart
class UspsAddressService {
  Future<bool> validateAddress(String address);
  Future<String> formatAddress(AddressData address);
  Future<List<String>> getSuggestions(String partialAddress);
}
```

## Data Models

### Album Model
**Location**: `lib/models/album.dart`

```dart
class Album {
  final String albumId;
  final String albumName;
  final String artist;
  final String releaseYear;
  final String albumImageUrl;

  Album({
    required this.albumId,
    required this.albumName,
    required this.artist,
    required this.releaseYear,
    required this.albumImageUrl,
  });

  factory Album.fromDocument(DocumentSnapshot doc);
}
```

**Firestore Document Structure**:
```json
{
  "albumName": "Album Title",
  "artist": "Artist Name",
  "releaseYear": "2023",
  "coverUrl": "https://image-url.com/cover.jpg",
  "discogsId": "12345",
  "genre": ["Rock", "Alternative"],
  "tracklist": [
    {
      "position": "1",
      "title": "Track Name",
      "duration": "3:45"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Order Model
**Location**: `lib/models/order_model.dart`

```dart
class OrderModel extends ChangeNotifier {
  bool hasOrdered = false;
  List<String> previousAddresses = [];

  Future<void> loadOrderData();
  Future<void> saveAddress(String address);
  Future<void> placeOrder(String address, String userId);
  Future<void> resetOrder();
}
```

**Firestore Document Structure**:
```json
{
  "userId": "user_id_string",
  "albumId": "album_id_string",
  "address": {
    "street": "123 Main St",
    "city": "City Name",
    "state": "State",
    "zipCode": "12345",
    "country": "US"
  },
  "status": "new|processing|sent|delivered|returned",
  "paymentIntentId": "stripe_payment_intent_id",
  "amount": 25.99,
  "currency": "usd",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "deliveryDate": "timestamp",
  "trackingNumber": "tracking_number_string"
}
```

### Feed Item Model
**Location**: `lib/models/feed_item.dart`

```dart
class FeedItem {
  final String id;
  final String userId;
  final String type;
  final Map<String, dynamic> content;
  final DateTime timestamp;

  FeedItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    required this.timestamp,
  });

  factory FeedItem.fromDocument(DocumentSnapshot doc);
}
```

**Feed Item Types**:
- `album_review`: User album reviews
- `new_order`: New album orders
- `album_return`: Album returns
- `profile_update`: Profile changes

## Cloud Functions

**Location**: `functions/index.js`

### Core Functions

#### syncDiscogsCollection
Syncs user's Discogs collection with Firestore.

```javascript
/**
 * HTTP Cloud Function to sync Discogs collection
 * Endpoint: /syncDiscogsCollection
 * Method: POST
 * Auth: Required
 */
exports.syncDiscogsCollection = functions.https.onRequest(async (req, res) => {
  // Implementation details in functions/index.js
});
```

**Request Body**:
```json
{
  "userId": "firebase_user_id",
  "discogsUsername": "discogs_username"
}
```

**Response**:
```json
{
  "success": true,
  "albumsProcessed": 150,
  "newAlbums": 25,
  "updatedAlbums": 5
}
```

#### processOrder
Handles order processing and external service integration.

```javascript
exports.processOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    // Order processing logic
  });
```

#### generateFeedItems
Creates feed items when users perform actions.

```javascript
exports.generateFeedItems = functions.firestore
  .document('users/{userId}/activity/{activityId}')
  .onCreate(async (snap, context) => {
    // Feed generation logic
  });
```

### Utility Functions

#### delay
Rate limiting utility for API calls.

```javascript
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
```

#### fetchReleaseData
Retrieves detailed album information from Discogs API.

```javascript
async function fetchReleaseData(releaseId) {
  const url = `https://api.discogs.com/releases/${releaseId}?token=${DISCOGS_TOKEN}`;
  const response = await axios.get(url);
  return response.data;
}
```

## External APIs

### Discogs API Integration

**Base URL**: `https://api.discogs.com`

**Authentication**: Personal Access Token

#### Key Endpoints Used

##### Get User Collection
```
GET /users/{username}/collection/folders/0/releases
Query Parameters:
- token: string (required)
- per_page: number (default: 50, max: 100)
- page: number (default: 1)
```

**Response**:
```json
{
  "releases": [
    {
      "id": 12345,
      "basic_information": {
        "title": "Album Title",
        "artists": [{"name": "Artist Name"}],
        "year": 2023,
        "thumb": "https://thumb-url.jpg",
        "cover_image": "https://cover-url.jpg"
      }
    }
  ],
  "pagination": {
    "pages": 5,
    "page": 1,
    "per_page": 50,
    "items": 250
  }
}
```

##### Get Release Details
```
GET /releases/{release_id}
Query Parameters:
- token: string (required)
```

**Response**:
```json
{
  "id": 12345,
  "title": "Album Title",
  "artists": [{"name": "Artist Name"}],
  "year": 2023,
  "genres": ["Rock", "Alternative"],
  "styles": ["Indie Rock"],
  "tracklist": [
    {
      "position": "1",
      "title": "Track Title",
      "duration": "3:45"
    }
  ],
  "images": [
    {
      "type": "primary",
      "uri": "https://cover-image-url.jpg",
      "width": 600,
      "height": 600
    }
  ]
}
```

### Stripe API Integration

**Base URL**: `https://api.stripe.com/v1`

**Authentication**: Bearer token (secret key)

#### Key Operations

##### Create Payment Intent
```javascript
const paymentIntent = await stripe.paymentIntents.create({
  amount: 2599, // Amount in cents
  currency: 'usd',
  metadata: {
    orderId: 'order_id_string',
    userId: 'user_id_string'
  }
});
```

##### Confirm Payment
```javascript
const confirmedPayment = await stripe.paymentIntents.confirm(
  paymentIntent.id,
  {
    payment_method: paymentMethodId
  }
);
```

## Authentication

### Firebase Auth Integration

#### Supported Sign-In Methods
1. **Email/Password**
2. **Google Sign-In**

#### User Creation Flow
```dart
// 1. Create Firebase Auth user
UserCredential userCredential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(email: email, password: password);

// 2. Create Firestore user document
await FirestoreService().createUserDocument(userCredential.user!.uid, {
  'email': email,
  'displayName': displayName,
  'createdAt': FieldValue.serverTimestamp(),
});

// 3. Reserve username
await FirestoreService().addUsername(username, userCredential.user!.uid);
```

#### Authentication State Management
```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return HomeScreen(); // User is signed in
    } else {
      return LoginScreen(); // User is not signed in
    }
  },
)
```

## Database Schema

### Firestore Collections

#### users
```
users/{userId}
├── email: string
├── displayName: string
├── username: string
├── profileImageUrl: string
├── bio: string
├── isAdmin: boolean
├── createdAt: timestamp
├── updatedAt: timestamp
├── settings: map
│   ├── notifications: boolean
│   ├── privacy: string
│   └── theme: string
└── public/
    └── profile/
        ├── displayName: string
        ├── bio: string
        ├── profileImageUrl: string
        └── albumCount: number
```

#### usernames
```
usernames/{username}
├── userId: string
└── createdAt: timestamp
```

#### albums
```
albums/{albumId}
├── albumName: string
├── artist: string
├── releaseYear: string
├── coverUrl: string
├── discogsId: string
├── genre: array
├── styles: array
├── tracklist: array
├── createdAt: timestamp
└── updatedAt: timestamp
```

#### orders
```
orders/{orderId}
├── userId: string
├── albumId: string
├── status: string
├── address: map
├── paymentIntentId: string
├── amount: number
├── currency: string
├── createdAt: timestamp
├── updatedAt: timestamp
├── deliveryDate: timestamp
└── trackingNumber: string
```

#### feed
```
feed/{feedItemId}
├── userId: string
├── type: string
├── content: map
├── timestamp: timestamp
├── visibility: string
└── interactions: map
    ├── likes: number
    └── comments: number
```

### Security Rules

#### Basic Firestore Rules Structure
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own documents
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Public profiles are readable by all authenticated users
      match /public/{document=**} {
        allow read: if request.auth != null;
      }
    }
    
    // Orders are private to the user who created them
    match /orders/{orderId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
    }
    
    // Albums are readable by all authenticated users
    match /albums/{albumId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

## Error Handling

### Standard Error Response Format
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {
      "field": "specific_field_with_error",
      "value": "invalid_value"
    }
  },
  "timestamp": "2023-12-01T10:00:00Z"
}
```

### Common Error Codes

#### Authentication Errors
- `AUTH_USER_NOT_FOUND`: User account doesn't exist
- `AUTH_WRONG_PASSWORD`: Incorrect password
- `AUTH_EMAIL_ALREADY_IN_USE`: Email already registered
- `AUTH_WEAK_PASSWORD`: Password doesn't meet requirements

#### Database Errors
- `PERMISSION_DENIED`: User lacks required permissions
- `NOT_FOUND`: Requested document doesn't exist
- `ALREADY_EXISTS`: Document already exists (username conflicts)
- `INVALID_ARGUMENT`: Invalid data format or missing required fields

#### Payment Errors
- `PAYMENT_FAILED`: Payment processing failed
- `INSUFFICIENT_FUNDS`: Insufficient funds in payment method
- `PAYMENT_METHOD_INVALID`: Invalid payment method
- `AMOUNT_TOO_SMALL`: Amount below minimum threshold

#### External API Errors
- `DISCOGS_RATE_LIMIT`: Rate limit exceeded for Discogs API
- `DISCOGS_NOT_FOUND`: Release not found in Discogs database
- `USPS_INVALID_ADDRESS`: Address validation failed

### Error Handling Best Practices

#### In Dart/Flutter
```dart
try {
  await _firestoreService.createOrder(orderData);
} on FirebaseException catch (e) {
  switch (e.code) {
    case 'permission-denied':
      _showError('You do not have permission to perform this action.');
      break;
    case 'not-found':
      _showError('The requested item was not found.');
      break;
    default:
      _showError('An unexpected error occurred: ${e.message}');
  }
} catch (e) {
  _showError('An unexpected error occurred.');
  // Log error for debugging
  FirebaseCrashlytics.instance.recordError(e, null);
}
```

#### In Cloud Functions
```javascript
exports.syncCollection = functions.https.onRequest(async (req, res) => {
  try {
    // Function logic here
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error('Error in syncCollection:', error);
    
    if (error.response?.status === 429) {
      res.status(429).json({
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: 'API rate limit exceeded. Please try again later.'
        }
      });
    } else {
      res.status(500).json({
        error: {
          code: 'INTERNAL_SERVER_ERROR',
          message: 'An unexpected error occurred.'
        }
      });
    }
  }
});
```

---

This API reference should be updated whenever new endpoints, data models, or services are added to the application.