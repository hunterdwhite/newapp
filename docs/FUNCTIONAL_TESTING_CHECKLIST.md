# 🧪 Dissonant App - Functional Testing Checklist

**Purpose:** Use this document before and after major updates to ensure no key functionality is broken or altered unexpectedly.

**How to Use:**
1. Run through relevant sections before making major changes (to establish baseline)
2. After changes, run through again to verify everything still works
3. Check off items as you test them
4. Document any issues found in the "Issues Found" section at bottom

---

## 🚨 CRITICAL BUSINESS RULES - TEST THESE ALWAYS

**These are the most important functionalities that must NEVER break:**

### 🔒 **Order Prevention Rule**
- ✅ **Users CANNOT place a new order if they have ANY outstanding order**
- ✅ **Statuses that block new orders:** `new`, `sent`, `delivered`
- ✅ **Only after status changes to `kept` or `returnedConfirmed` can they order again**
- ✅ **This must be enforced on BOTH client and server side**

### 💳 **Curator Credit Rule (NOT Free Order)**
- ✅ **When a curator curates an album, they receive 1 FREE ORDER CREDIT**
- ✅ **This is NOT a full free order - just 1/5th of one**
- ✅ **5 curator credits = 1 free order (same as paid order credits)**
- ✅ **Curator's `freeOrderCredits` field increments by 1**

### 🎁 **Return Free Order Rule (FULL Free Order)**
- ✅ **When a user's album is returned and confirmed, they get 1 FULL FREE ORDER**
- ✅ **User's `freeOrdersAvailable` increments by 1 (not just credits)**
- ✅ **This is separate from the 5-credit system**
- ✅ **Only first-time orders qualify for this return benefit**

### 🔐 **Privacy Rule - Address Security**
- ✅ **Curators NEVER see user shipping addresses**
- ✅ **Address information is STRICTLY for admins only**
- ✅ **Only admins can view addresses for order fulfillment**
- ✅ **Curator order screens must hide all address fields**

**Before ANY major deployment, verify all 4 of these rules are working!**

---

## 📋 Table of Contents
1. [Authentication & User Management](#1-authentication--user-management)
2. [User Profile & Settings](#2-user-profile--settings)
3. [Order System](#3-order-system)
4. [Free Order Credits & Anniversary Event](#4-free-order-credits--anniversary-event)
5. [Curator System](#5-curator-system)
6. [Album Library & Wishlist](#6-album-library--wishlist)
7. [Feed & Social Features](#7-feed--social-features)
8. [Payment Processing](#8-payment-processing)
9. [Address Validation](#9-address-validation)
10. [Push Notifications](#10-push-notifications)
11. [Referral System](#11-referral-system)
12. [Admin Dashboard](#12-admin-dashboard)
13. [Home Screen & Navigation](#13-home-screen--navigation)
14. [Discogs Integration](#14-discogs-integration)
15. [Performance & Cache](#15-performance--cache)
16. [Error Handling](#16-error-handling)

---

## 1. Authentication & User Management

### 1.1 User Registration
- [ ] **Email registration works**
  - [ ] User can enter email and password
  - [ ] Password requirements are enforced (minimum length, etc.)
  - [ ] Email validation works (proper email format)
  - [ ] Username selection works and checks for duplicates
  - [ ] Error shown if username already exists
  - [ ] User document created in Firestore (`users` collection)
  - [ ] Username reserved in `usernames` collection
  - [ ] Email verification screen appears after registration

### 1.2 Email Verification
- [ ] **Email verification flow**
  - [ ] Verification email sent automatically
  - [ ] User redirected to EmailVerificationScreen
  - [ ] User can resend verification email
  - [ ] Refresh button checks verification status
  - [ ] User redirected to home after verification confirmed
  - [ ] Unverified users cannot access main app features

### 1.3 Login
- [ ] **Email login works**
  - [ ] User can log in with email and password
  - [ ] Error displayed for wrong password
  - [ ] Error displayed for non-existent email
  - [ ] User redirected to home screen after successful login
  - [ ] Login state persists (doesn't need to log in again on app restart)


### 1.4 Password Management
- [ ] **Forgot password works**
  - [ ] User can request password reset
  - [ ] Password reset email sent successfully
  - [ ] Reset link works and allows password change
  - [ ] User can log in with new password

- [ ] **Change password works**
  - [ ] User can access change password screen
  - [ ] Current password verification works
  - [ ] New password requirements enforced
  - [ ] Password successfully updated
  - [ ] User can log in with new password


### 1.6 Account Deletion
- [ ] **Account deletion works**
  - [ ] User can delete account from profile/settings
  - [ ] Confirmation dialog appears
  - [ ] Outstanding orders checked (prevent deletion if orders exist)
  - [ ] User document deleted from Firestore
  - [ ] Username freed up for reuse
  - [ ] Wishlist items deleted
  - [ ] Public profile deleted
  - [ ] Orders deleted (if allowed)
  - [ ] User redirected to welcome screen
  - [ ] Cannot log in with deleted credentials

---

## 2. User Profile & Settings

### 2.1 Profile Setup
- [ ] **Username configuration**
  - [ ] User can set/change username
  - [ ] Username uniqueness validated in real-time
  - [ ] Username stored in `usernames` collection
  - [ ] Old username freed if changed

- [ ] **Display name**
  - [ ] User can set display name
  - [ ] Display name shows in profile
  - [ ] Display name shows in public profile

- [ ] **Bio**
  - [ ] User can add/edit bio
  - [ ] Bio displays in profile
  - [ ] Bio displays in public profile
  - [ ] Character limit enforced (if any)

- [ ] **Profile picture**
  - [ ] User can upload profile picture
  - [ ] Image picker opens correctly
  - [ ] Image uploaded to Firebase Storage
  - [ ] Profile picture URL stored in Firestore
  - [ ] Profile picture displays in profile
  - [ ] Profile picture displays in public profile
  - [ ] Old image deleted when new one uploaded

### 2.2 Public Profile
- [ ] **Public profile visibility**
  - [ ] Public profile accessible via username
  - [ ] Shows username, display name, bio
  - [ ] Shows profile picture
  - [ ] Shows album count (if applicable)
  - [ ] Shows curator status (if curator)
  - [ ] Privacy settings respected

### 2.3 Profile Settings
- [ ] **Settings accessible**
  - [ ] Settings screen accessible from profile
  - [ ] All setting options displayed

- [ ] **Notification settings**
  - [ ] User can toggle notifications on/off
  - [ ] Setting saved to Firestore
  - [ ] Setting persists across sessions

- [ ] **Privacy settings**
  - [ ] User can set profile to private/public
  - [ ] Setting saved and enforced

---

## 3. Order System

### 3.1 Order Flow - Standard Order
- [ ] **Order initiation**
  - [ ] User can access order screen
  - [ ] Order form displays correctly
  - [ ] All fields present (name, address, city, state, zip)

- [ ] **Address input**
  - [ ] First name field accepts input
  - [ ] Last name field accepts input
  - [ ] Address field accepts input
  - [ ] City field accepts input
  - [ ] State dropdown shows all US states
  - [ ] State selection works
  - [ ] Zipcode field accepts 5-digit input
  - [ ] Zipcode validation works

- [ ] **Address validation**
  - [ ] Address validated via Shippo before submission
  - [ ] Valid addresses accepted
  - [ ] Invalid addresses rejected with error message
  - [ ] Address suggestions provided (if available)
  - [ ] User can accept suggested address

- [ ] **Previous addresses**
  - [ ] Previous addresses displayed (if any)
  - [ ] User can select previous address
  - [ ] Selected address auto-fills form

- [ ] **Payment amount selection**
  - [ ] Payment options displayed correctly ($11.99 standard, $19.99 premium, etc.)
  - [ ] User can select payment amount
  - [ ] Selected amount highlighted
  - [ ] Correct amount used in payment

- [ ] **Order submission**
  - [ ] Order cannot be submitted with invalid address
  - [ ] Order cannot be submitted without payment selection
  - [ ] Loading indicator shows during submission
  - [ ] Duplicate order prevention works (30-second cooldown)

### 3.2 Order Flow - Free Order
- [ ] **Free order availability**
  - [ ] Free order option shows when user has free orders available
  - [ ] Free order count displayed correctly
  - [ ] User informed they can use free order

- [ ] **Free order submission**
  - [ ] User can select "Use Free Order" option
  - [ ] Address validation still required
  - [ ] Order submitted without payment
  - [ ] Free order count decremented by 1
  - [ ] Order status set to 'new'
  - [ ] No curator credit awarded for free orders

### 3.3 Order Flow - Curator Order
- [ ] **Curator selection**
  - [ ] User can access curator order screen
  - [ ] Favorite curators displayed
  - [ ] Featured curators displayed
  - [ ] All curators searchable
  - [ ] Curator profiles viewable
  - [ ] Curator ratings displayed

- [ ] **Curator order placement**
  - [ ] User can select a curator
  - [ ] Order proceeds with selected curator
  - [ ] Curator ID attached to order
  - [ ] Curator notified of new order (push notification)
  - [ ] Order appears in curator's pending orders

### 3.4 Order Status & Tracking
- [ ] **Order status display**
  - [ ] Order status shows correctly: new, processing, sent, delivered, returned
  - [ ] Most recent order status retrieved correctly
  - [ ] User sees appropriate message based on status

- [ ] **Order status: new**
  - [ ] User informed order is being prepared
  - [ ] **CRITICAL: Cannot place another order while status is 'new'**
  - [ ] Order screen blocks/hides new order submission

- [ ] **Order status: sent**
  - [ ] User informed order is shipped
  - [ ] Tracking number displayed (if available)
  - [ ] **CRITICAL: Cannot place another order while status is 'sent'**
  - [ ] Order screen blocks/hides new order submission

- [ ] **Order status: delivered**
  - [ ] User informed order is delivered
  - [ ] User can rate the album
  - [ ] User prompted to keep or return album
  - [ ] **CRITICAL: Cannot place new order until user keeps or returns**

- [ ] **Order status: returned/kept**
  - [ ] User can place new order only after return/keep is confirmed
  - [ ] Return processed correctly
  - [ ] Order prevention lifted after status change

### 3.5 Album Return
- [ ] **Return initiation**
  - [ ] User can access return screen
  - [ ] Current order information displayed
  - [ ] Return options shown

- [ ] **Return submission**
  - [ ] User can mark album for return
  - [ ] Confirmation dialog appears
  - [ ] Order status updated to 'returned'
  - [ ] Shipping label generated (if applicable)
  - [ ] User notified of return instructions

### 3.6 Shipping Labels
- [ ] **Label generation**
  - [ ] Shipping label created automatically via Cloud Function
  - [ ] Client-side backup label creation works
  - [ ] Label stored in order document
  - [ ] Label accessible by admin

- [ ] **Label retry mechanism**
  - [ ] Failed labels retried automatically
  - [ ] Retry script works for failed labels
  - [ ] Labels eventually succeed or flagged for manual review

### 3.7 Duplicate Order Prevention
- [ ] **Duplicate detection**
  - [ ] Orders within 30 seconds blocked
  - [ ] User shown appropriate error message
  - [ ] User can retry after cooldown period
  - [ ] Duplicate check doesn't block legitimate orders

### 3.8 Order Data Integrity
- [ ] **Order document structure**
  - [ ] userId stored correctly
  - [ ] address stored correctly
  - [ ] status initialized as 'new'
  - [ ] timestamp added automatically
  - [ ] curatorId stored (if curator order)
  - [ ] paymentIntentId stored (if paid)
  - [ ] amount stored correctly
  - [ ] flowVersion stored correctly

---

## 4. Free Order Credits & Anniversary Event

### 4.1 Credit System
- [ ] **Credit display**
  - [ ] Current credit count displayed on home screen
  - [ ] Credit progress bar shows correctly (0-5 scale)
  - [ ] Credits displayed in earn credits screen

- [ ] **Earning credits**
  - [ ] 1 credit awarded for paid orders
  - [ ] No credit awarded for free orders
  - [ ] Credit count increments correctly
  - [ ] Credits saved to Firestore (`freeOrderCredits` field)

- [ ] **Credit conversion**
  - [ ] 5 credits automatically convert to 1 free order
  - [ ] Credits reset to remainder after conversion
  - [ ] `freeOrdersAvailable` incremented
  - [ ] `freeOrder` flag set to true
  - [ ] User notified of conversion

### 4.2 Free Order Credits
- [ ] **Free order availability**
  - [ ] `freeOrdersAvailable` count displayed correctly
  - [ ] Free order option appears when available
  - [ ] Free order option hidden when none available

- [ ] **Using free orders**
  - [ ] `useFreeOrder()` method works correctly
  - [ ] `freeOrdersAvailable` decremented by 1
  - [ ] `freeOrder` set to false when count reaches 0
  - [ ] Free order count persists across sessions

### 4.3 Anniversary Event
- [ ] **Event configuration**
  - [ ] `app_config/pricing_config` document exists
  - [ ] `giveNewUsersFreeOrder` flag works
  - [ ] `newUserFreeOrderCount` sets correct count
  - [ ] `showAnniversaryCard` flag controls card visibility

- [ ] **New user free orders**
  - [ ] New users receive free order(s) automatically
  - [ ] Count based on `newUserFreeOrderCount`
  - [ ] Only granted if `giveNewUsersFreeOrder` is true
  - [ ] Free order added during registration

- [ ] **Anniversary card**
  - [ ] Anniversary card displays on home screen
  - [ ] Card shows when `showAnniversaryCard` is true
  - [ ] Card hidden when flag is false
  - [ ] Card displays correct event information

- [ ] **Bulk free order grants**
  - [ ] `grant_anniversary_free_orders.js` script works
  - [ ] Dry-run mode shows preview correctly
  - [ ] Live mode grants orders to eligible users
  - [ ] Only users without existing orders receive grants
  - [ ] Users who already have free orders skipped
  - [ ] Script is idempotent (safe to run multiple times)

### 4.4 Returned Order Free Credits
- [ ] **Return credit system**
  - [ ] **CRITICAL: Users receive 1 FULL FREE ORDER when album is returned and confirmed**
  - [ ] `freeOrdersAvailable` incremented by 1 (not just credits)
  - [ ] Return free order granted automatically upon return confirmation
  - [ ] Free order count updates in user document
  - [ ] freeOrder boolean field is also set to true
  - [ ] Backfill script works for historical returns
  - [ ] Only first-time orders qualify for return credit
  - [ ] Return free orders work independently of credit system (5 credits = 1 free order)

---

## 5. Curator System

### 5.1 Becoming a Curator
- [ ] **Curator signup flow**
  - [ ] User can access curator screen
  - [ ] Non-curators see signup option
  - [ ] Warning/responsibility message shown
  - [ ] User can confirm understanding

- [ ] **Curator activation**
  - [ ] Push notification permission requested
  - [ ] Permission grant required to become curator
  - [ ] FCM token obtained and stored
  - [ ] `isCurator` flag set to true in Firestore
  - [ ] `curatorJoinedAt` timestamp added
  - [ ] User subscribed to curator topic
  - [ ] User notified of successful signup

### 5.2 Curator Profile
- [ ] **Curator information**
  - [ ] Curator status visible in profile
  - [ ] Curator joined date displayed
  - [ ] Curator can view their stats
  - [ ] Curator rating displayed

- [ ] **Curator visibility**
  - [ ] Curator appears in curator list
  - [ ] Curator searchable by username
  - [ ] Curator profile accessible to other users

### 5.3 Curator Orders
- [ ] **Order assignment**
  - [ ] Orders with curator selection have `curatorId`
  - [ ] Curator receives push notification for new order
  - [ ] Order appears in curator's pending list
  - [ ] Order status shows 'curator_assigned'

- [ ] **Curator order fulfillment**
  - [ ] Curator can view order details
  - [ ] Curator can see user's taste profile
  - [ ] **CRITICAL: Curator CANNOT see user's shipping address**
  - [ ] **CRITICAL: Address information hidden from curator view**
  - [ ] Curator can search for albums
  - [ ] Curator can select album for order
  - [ ] Album selection updates order
  - [ ] Curator receives 1 credit (not full free order) after selection

- [ ] **Curator rewards/tracking**
  - [ ] **CRITICAL: Curator receives 1 FREE ORDER CREDIT (not full free order) per curation**
  - [ ] Curator's `freeOrderCredits` incremented by 1 (accumulates toward 5 for full free order)
  - [ ] Credit properly added to curator's account after album selection
  - [ ] 5 curator credits convert to 1 free order (same as paid order credits)
  - [ ] Credit audit script works
  - [ ] Backfill script for curator credits works
  - [ ] Curator reward system functions correctly

### 5.4 Opting Out of Curator
- [ ] **Opt-out flow**
  - [ ] Curator can opt out from curator screen
  - [ ] Confirmation dialog shown
  - [ ] Pending orders converted to standard orders
  - [ ] `isCurator` flag set to false
  - [ ] `curatorOptedOutAt` timestamp added
  - [ ] User unsubscribed from curator topic
  - [ ] User removed from curator list

### 5.5 Curator Discovery
- [ ] **Favorite curators**
  - [ ] Users can favorite curators
  - [ ] Favorites saved to Firestore
  - [ ] Favorites displayed on curator order screen
  - [ ] Can remove favorites

- [ ] **Featured curators**
  - [ ] Featured curators displayed prominently
  - [ ] Featured status configurable

- [ ] **Curator search**
  - [ ] Search by username works
  - [ ] Search by display name works
  - [ ] Search results update in real-time
  - [ ] Search results can be selected

---

## 6. Album Library & Wishlist

### 6.1 Discogs Library
- [ ] **Library sync**
  - [ ] User can link Discogs account
  - [ ] Discogs username saved
  - [ ] Sync button triggers collection sync
  - [ ] Cloud Function processes sync
  - [ ] Albums added to Firestore
  - [ ] Album count updates

- [ ] **Library display**
  - [ ] User's albums displayed in library screen
  - [ ] Album covers load correctly
  - [ ] Album details accessible
  - [ ] Library sortable/filterable

### 6.2 Wishlist
- [ ] **Adding to wishlist**
  - [ ] User can add albums to wishlist
  - [ ] Album added to `users/{uid}/wishlist`
  - [ ] Wishlist icon updates (filled vs outline)
  - [ ] Duplicate albums prevented

- [ ] **Wishlist display**
  - [ ] Wishlist accessible from profile/library
  - [ ] All wishlist items displayed
  - [ ] Album details accessible from wishlist

- [ ] **Removing from wishlist**
  - [ ] User can remove albums from wishlist
  - [ ] Confirmation shown (optional)
  - [ ] Album removed from Firestore
  - [ ] Wishlist icon updates

### 6.3 Album Details
- [ ] **Album information**
  - [ ] Album name displayed
  - [ ] Artist name displayed
  - [ ] Release year displayed
  - [ ] Album cover displayed
  - [ ] Genre/style displayed
  - [ ] Tracklist displayed

- [ ] **Album interactions**
  - [ ] Can add to wishlist from details
  - [ ] Can view on Discogs
  - [ ] Can share album

---

## 7. Feed & Social Features

### 7.1 Feed Display
- [ ] **Feed screen**
  - [ ] Feed accessible from navigation
  - [ ] Recent activity displayed
  - [ ] Feed items load in chronological order
  - [ ] Infinite scroll/pagination works

- [ ] **Feed item types**
  - [ ] Album reviews displayed correctly
  - [ ] New orders displayed
  - [ ] Album returns displayed
  - [ ] Profile updates displayed

### 7.2 Feed Interactions
- [ ] **Viewing content**
  - [ ] Can tap feed item for details
  - [ ] User profile accessible from feed item
  - [ ] Album details accessible from feed item



### 7.3 News & Announcements
- [ ] **News display**
  - [ ] News items displayed on home screen
  - [ ] Auto-scroll works (if enabled)
  - [ ] Can manually swipe news items
  - [ ] News items load from Firestore

- [ ] **News details**
  - [ ] Can tap news for full article
  - [ ] Article detail screen displays correctly
  - [ ] Can navigate back to home

---

## 8. Payment Processing

### 8.1 Stripe Integration
- [ ] **Stripe initialization**
  - [ ] Stripe SDK initialized with publishable key
  - [ ] Stripe settings applied correctly

- [ ] **Payment Intent creation**
  - [ ] API call to create payment intent succeeds
  - [ ] Correct amount passed (in cents)
  - [ ] Idempotency key prevents duplicate charges
  - [ ] Payment intent ID returned

- [ ] **Payment sheet**
  - [ ] Payment sheet opens correctly
  - [ ] Card input fields display
  - [ ] Can enter card details
  - [ ] Can save card for future use (if enabled)

- [ ] **Payment confirmation**
  - [ ] Payment processes successfully
  - [ ] Payment confirmation received
  - [ ] Order created after successful payment
  - [ ] User notified of successful payment

- [ ] **Payment failure**
  - [ ] Payment errors caught and displayed
  - [ ] User informed of failure reason
  - [ ] Order not created on payment failure
  - [ ] User can retry payment

### 8.2 Payment Amounts
- [ ] **Pricing configuration**
  - [ ] Standard order price correct ($11.99 default)
  - [ ] Premium order price correct ($19.99 or as configured)
  - [ ] Pricing pulled from Firestore config (if dynamic)
  - [ ] Anniversary event pricing applied when active

### 8.3 Payment Validation
- [ ] **Amount validation**
  - [ ] Minimum amount enforced
  - [ ] Maximum amount enforced (if any)
  - [ ] Correct currency used (USD)

---

## 9. Address Validation

### 9.1 Shippo Address Service
- [ ] **Address validation**
  - [ ] Shippo API called with address
  - [ ] Valid addresses return success
  - [ ] Invalid addresses return error
  - [ ] Validation message displayed to user

- [ ] **Address suggestions**
  - [ ] Suggested addresses provided
  - [ ] User can select suggestion
  - [ ] Form auto-filled with suggestion

### 9.2 USPS Address Service (Backup)
- [ ] **USPS validation**
  - [ ] USPS service available as backup
  - [ ] Validates US addresses
  - [ ] Returns standardized format

---

## 10. Push Notifications

### 10.1 Notification Setup
- [ ] **FCM initialization**
  - [ ] Firebase Messaging initialized
  - [ ] Background message handler registered
  - [ ] Push notification service initialized

- [ ] **Permission request**
  - [ ] Permission dialog appears
  - [ ] Permissions granted correctly
  - [ ] Permissions denied handled gracefully

- [ ] **Token management**
  - [ ] FCM token obtained
  - [ ] Token stored in Firestore
  - [ ] Token refreshed on change

### 10.2 Notification Reception
- [ ] **Foreground notifications**
  - [ ] Notifications received while app open
  - [ ] Notification displayed to user
  - [ ] Notification data accessible

- [ ] **Background notifications**
  - [ ] Notifications received while app closed
  - [ ] Notification appears in system tray
  - [ ] Tapping notification opens app

- [ ] **Notification handling**
  - [ ] Notification navigation works
  - [ ] Deep links handled correctly
  - [ ] Data payload accessible

### 10.3 Notification Topics
- [ ] **Topic subscription**
  - [ ] Curator topic subscription works
  - [ ] Topic-specific notifications received
  - [ ] Can unsubscribe from topics

### 10.4 Curator Notifications
- [ ] **New order notifications**
  - [ ] Curator receives notification for new order
  - [ ] Notification contains relevant order info
  - [ ] Tapping notification navigates to order

---

## 11. Referral System

### 11.1 Referral Code
- [ ] **Code generation**
  - [ ] Referral code generated for user
  - [ ] Code unique and tied to user
  - [ ] Code displayed in profile/earn credits screen

- [ ] **Code sharing**
  - [ ] User can copy referral code
  - [ ] User can share code via system share sheet

### 11.2 Referral Redemption
- [ ] **Code entry**
  - [ ] New user can enter referral code
  - [ ] Code validated against database
  - [ ] Invalid codes rejected
  - [ ] Already used codes rejected

- [ ] **Referral rewards**
  - [ ] Referrer receives credit/reward
  - [ ] Referee receives bonus (if applicable)
  - [ ] Referral count incremented
  - [ ] Referral tracked in Firestore

### 11.3 Referral Tracking
- [ ] **Referral data**
  - [ ] Referral count displayed
  - [ ] List of referred users accessible
  - [ ] Referral rewards tracked

---

## 12. Admin Dashboard

### 12.1 Admin Access
- [ ] **Admin authentication**
  - [ ] Admin users identified by `isAdmin` flag
  - [ ] Non-admin users cannot access dashboard
  - [ ] Admin dashboard accessible from navigation/profile

### 12.2 Order Management
- [ ] **Order overview**
  - [ ] All orders displayed
  - [ ] Orders filterable by status
  - [ ] Orders sortable by date
  - [ ] Order count displayed

- [ ] **Order details**
  - [ ] Can view full order details
  - [ ] User information displayed
  - [ ] **CRITICAL: Address information displayed (ADMIN ONLY)**
  - [ ] **CRITICAL: Shipping addresses only accessible to admins**
  - [ ] Payment information displayed
  - [ ] Admin can see all sensitive information for fulfillment

- [ ] **Order status updates**
  - [ ] Can change order status
  - [ ] Status update saved to Firestore
  - [ ] User notified of status change (if applicable)

### 12.3 User Management
- [ ] **User list**
  - [ ] All users displayed
  - [ ] User search works
  - [ ] User count displayed

- [ ] **User details**
  - [ ] Can view user profile
  - [ ] User order history displayed
  - [ ] User status visible (curator, etc.)

### 12.4 Album Selection
- [ ] **Admin album selection**
  - [ ] Admin can search albums for orders
  - [ ] Admin can assign album to order
  - [ ] Album selection updates order document

### 12.5 Analytics
- [ ] **Dashboard stats**
  - [ ] Total orders displayed
  - [ ] Orders by status displayed
  - [ ] Revenue stats (if implemented)
  - [ ] User growth stats

---

## 13. Home Screen & Navigation

### 13.1 Home Screen
- [ ] **Screen loading**
  - [ ] Home screen loads without errors
  - [ ] Loading states display correctly
  - [ ] Data loads in reasonable time

- [ ] **Username display**
  - [ ] User's username displayed correctly
  - [ ] Greeting message shows

- [ ] **Free order bar**
  - [ ] Free order credit progress bar displays
  - [ ] Current credits shown (0-5 scale)
  - [ ] Tapping bar navigates to earn credits screen

- [ ] **News carousel**
  - [ ] News items displayed
  - [ ] Auto-scroll works
  - [ ] Manual swipe works
  - [ ] Indicator dots show current position

- [ ] **Latest albums section**
  - [ ] Recent albums from feed displayed
  - [ ] Album covers load correctly
  - [ ] Tapping album opens details

- [ ] **Quick actions**
  - [ ] Place order button works
  - [ ] View library button works
  - [ ] Other quick actions functional

### 13.2 Bottom Navigation
- [ ] **Navigation bar**
  - [ ] All tabs visible: Home, Order, Curator, My Music, Profile
  - [ ] Icons display correctly
  - [ ] Selected tab highlighted

- [ ] **Tab navigation**
  - [ ] Home tab navigates to home screen
  - [ ] Order tab navigates to order selection
  - [ ] Curator tab navigates to curator screen
  - [ ] My Music tab navigates to music library
  - [ ] Profile tab navigates to profile

- [ ] **Tab state**
  - [ ] Selected tab remembered
  - [ ] Tab state persists during session
  - [ ] Tapping active tab pops to root of that tab

### 13.3 App Bar
- [ ] **App bar display**
  - [ ] App name/logo displays correctly
  - [ ] Navigation actions present
  - [ ] Profile picture/icon shows

### 13.4 Navigation Flows
- [ ] **Deep navigation**
  - [ ] Can navigate multiple levels deep
  - [ ] Back button returns to previous screen
  - [ ] Pop to root works correctly

- [ ] **Tab-specific navigation**
  - [ ] Each tab has own navigation stack
  - [ ] Switching tabs doesn't lose navigation state

---

## 14. Discogs Integration

### 14.1 Discogs API Connection
- [ ] **API authentication**
  - [ ] Discogs token configured
  - [ ] API requests authenticated
  - [ ] Rate limiting handled

### 14.2 Collection Sync
- [ ] **Sync trigger**
  - [ ] User can initiate sync
  - [ ] Cloud Function triggered
  - [ ] Sync progress indicated

- [ ] **Collection fetch**
  - [ ] User collection fetched from Discogs
  - [ ] Pagination handled (all pages fetched)
  - [ ] Rate limiting respected

- [ ] **Data processing**
  - [ ] Album data extracted correctly
  - [ ] Album stored in Firestore
  - [ ] Duplicate albums handled
  - [ ] Album images fetched and stored

### 14.3 Album Search
- [ ] **Discogs search**
  - [ ] Can search Discogs database
  - [ ] Search results displayed
  - [ ] Can view album details from search
  - [ ] Can add search results to order/wishlist

---

## 15. Performance & Cache

### 15.1 Caching
- [ ] **Firestore cache**
  - [ ] Offline persistence enabled
  - [ ] Cache size unlimited (or configured)
  - [ ] Cache utilized for queries

- [ ] **Image cache**
  - [ ] Album covers cached
  - [ ] Profile pictures cached
  - [ ] Cache cleared appropriately (on pause)
  - [ ] Cache preloaded on resume

- [ ] **Data cache**
  - [ ] FirestoreService cache works
  - [ ] Cache expiry enforced (5 minutes)
  - [ ] Expired cache cleared

### 15.2 Performance Optimizations
- [ ] **App launch**
  - [ ] App launches quickly
  - [ ] Splash screen displays briefly
  - [ ] Firebase initialized efficiently

- [ ] **Screen transitions**
  - [ ] Page transitions smooth
  - [ ] No lag when switching tabs
  - [ ] Navigation animations perform well

- [ ] **List performance**
  - [ ] Long lists scroll smoothly
  - [ ] Pagination implemented where needed
  - [ ] Images load without stuttering

### 15.3 Memory Management
- [ ] **Memory usage**
  - [ ] App doesn't consume excessive memory
  - [ ] Image cache managed properly
  - [ ] No memory leaks detected

---

## 16. Error Handling

### 16.1 Network Errors
- [ ] **No internet connection**
  - [ ] User informed of no connection
  - [ ] Offline data accessible (cached)
  - [ ] Actions queued for when online (if applicable)

- [ ] **API failures**
  - [ ] API errors caught and handled
  - [ ] User shown appropriate error message
  - [ ] Retry mechanism available

### 16.2 Firebase Errors
- [ ] **Authentication errors**
  - [ ] Wrong password error shown
  - [ ] Email already in use error shown
  - [ ] Weak password error shown
  - [ ] Other auth errors handled gracefully

- [ ] **Firestore errors**
  - [ ] Permission denied errors caught
  - [ ] Not found errors handled
  - [ ] Network errors handled
  - [ ] User shown meaningful error messages

### 16.3 Payment Errors
- [ ] **Stripe errors**
  - [ ] Card declined error shown
  - [ ] Insufficient funds error shown
  - [ ] Invalid card error shown
  - [ ] Network errors handled

### 16.4 Validation Errors
- [ ] **Form validation**
  - [ ] Empty field errors shown
  - [ ] Invalid format errors shown
  - [ ] Validation messages clear and helpful

### 16.5 Crash Reporting
- [ ] **Crashlytics**
  - [ ] Crashlytics initialized
  - [ ] Crashes logged to Firebase
  - [ ] Fatal errors reported
  - [ ] Stack traces captured

---

## 17. Edge Cases & Special Scenarios

### 17.1 Concurrent Actions
- [ ] **Multiple users**
  - [ ] Concurrent orders don't conflict
  - [ ] Username race conditions handled
  - [ ] Payment idempotency works

### 17.2 State Consistency
- [ ] **Order states**
  - [ ] **CRITICAL: User can't place order with ANY outstanding order (new, sent, delivered)**
  - [ ] **CRITICAL: Only after 'kept' or 'returnedConfirmed' status can user place new order**
  - [ ] Order status transitions valid (new → sent → delivered → kept/returned)
  - [ ] Returned/kept orders allow new orders
  - [ ] Multiple order prevention enforced on both client and server

- [ ] **Free order states**
  - [ ] Free order count never goes negative
  - [ ] Credit conversion happens at exactly 5 credits
  - [ ] Free order flag synced with count
  - [ ] Return free orders (full) separate from earned credits

### 17.3 Data Migration
- [ ] **Schema changes**
  - [ ] Old data structures handled gracefully
  - [ ] Missing fields have defaults
  - [ ] Backfill scripts work correctly

---

## 18. Platform-Specific

### 18.1 Android
- [ ] **Android build**
  - [ ] App builds successfully
  - [ ] APK/AAB installs correctly
  - [ ] All features work on Android

- [ ] **Android-specific**
  - [ ] Back button behavior correct
  - [ ] Permissions requested at right time
  - [ ] Push notifications work

### 18.2 iOS
- [ ] **iOS build**
  - [ ] App builds successfully
  - [ ] IPA installs correctly
  - [ ] All features work on iOS

- [ ] **iOS-specific**
  - [ ] Safe area respected
  - [ ] Permissions requested at right time
  - [ ] Push notifications work
  - [ ] Apple sign-in works (if implemented)

---

## ✅ Testing Completion

**Date Tested:** _____________  
**Tester:** _____________  
**App Version:** _____________  
**Platform(s) Tested:** [ ] Android [ ] iOS [ ] Web  

**Overall Status:**  
- [ ] All critical features working  
- [ ] No regressions detected  
- [ ] Ready for deployment  

---

## 🐛 Issues Found

Use this section to document any issues discovered during testing:

### Issue #1
- **Section:** _____________
- **Description:** _____________
- **Severity:** [ ] Critical [ ] High [ ] Medium [ ] Low
- **Steps to Reproduce:**
  1. _____________
  2. _____________
- **Expected Behavior:** _____________
- **Actual Behavior:** _____________
- **Status:** [ ] Open [ ] Fixed [ ] Won't Fix

### Issue #2
- **Section:** _____________
- **Description:** _____________
- **Severity:** [ ] Critical [ ] High [ ] Medium [ ] Low
- **Steps to Reproduce:**
  1. _____________
  2. _____________
- **Expected Behavior:** _____________
- **Actual Behavior:** _____________
- **Status:** [ ] Open [ ] Fixed [ ] Won't Fix

---

## 📝 Notes

Add any additional notes, observations, or comments here:

---

**Document Version:** 1.0  
**Last Updated:** 2024-11-15  
**Maintained By:** Development Team

