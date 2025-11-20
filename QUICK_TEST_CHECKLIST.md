# ⚡ Quick Test Checklist

Use this abbreviated checklist for minor updates and quick smoke tests.

---

## 🚨 **CRITICAL BUSINESS RULES** - Always Verify These First!

### 🔒 **Order Prevention** (2 min)
- [ ] User with order status 'new', 'sent', or 'delivered' CANNOT place new order
- [ ] Only 'kept' or 'returnedConfirmed' status allows new orders
- [ ] Order screen properly blocks/hides order submission when order exists

### 💳 **Curator Credits** (1 min)
- [ ] Curator gets 1 CREDIT (not full free order) when curating
- [ ] Credit adds to `freeOrderCredits` field (need 5 for 1 free order)

### 🎁 **Return Free Orders** (1 min)
- [ ] User gets 1 FULL free order when album returned/confirmed
- [ ] `freeOrdersAvailable` increments (not just credits)

### 🔐 **Address Privacy** (1 min)
- [ ] Curators CANNOT see user shipping addresses
- [ ] Only admins see addresses

**Total: ~5 minutes to verify all critical rules**

---

## 🔥 Critical Path - Test ALWAYS

These are the absolute must-test features before any deployment:

### Authentication (1 min)
- [ ] User can log in with email/password
- [ ] User can log out
- [ ] Email verification works for new users

### Navigation (1 min)
- [ ] All bottom nav tabs work (Home, Order, Curator, Music, Profile)
- [ ] Can navigate between screens without crashes
- [ ] Back button works correctly

### Order Flow (3 min)
- [ ] Can access order screen
- [ ] Address validation works
- [ ] Can place a paid order successfully
- [ ] Can use free order (if available)
- [ ] Duplicate order prevention works (30-sec cooldown)
- [ ] **CRITICAL: User with existing order CANNOT place another**

### Payment (2 min)
- [ ] Payment sheet opens
- [ ] Can enter card details
- [ ] Payment processes successfully
- [ ] Order created after payment

### Profile (1 min)
- [ ] Profile screen loads
- [ ] Username displays correctly
- [ ] Can view order history
- [ ] Settings accessible

### No Errors (1 min)
- [ ] No console errors on app launch
- [ ] No crashes during normal use
- [ ] Error messages display when appropriate

---

## 🚀 Quick Feature Tests

### If You Changed: Authentication
- [ ] Registration works
- [ ] Login works
- [ ] Logout works
- [ ] Password reset works
- [ ] Email verification works

### If You Changed: Orders
- [ ] Address input and validation
- [ ] Payment selection and processing
- [ ] Free order usage
- [ ] Order status display
- [ ] Duplicate prevention

### If You Changed: Curator System
- [ ] Becoming a curator works
- [ ] Curator notifications sent
- [ ] Curator order assignment
- [ ] **CRITICAL: Curator gets 1 CREDIT (not free order) per curation**
- [ ] **CRITICAL: Curator CANNOT see user addresses**
- [ ] Opting out works

### If You Changed: Credits/Free Orders
- [ ] Credit earning (1 per paid order)
- [ ] Credit display (progress bar)
- [ ] Conversion (5 credits → 1 free order)
- [ ] **CRITICAL: Return grants FULL free order (not just credit)**
- [ ] **CRITICAL: Curator curation grants 1 CREDIT (not free order)**
- [ ] Free order usage
- [ ] Anniversary event configuration

### If You Changed: Profile/Settings
- [ ] Profile editing
- [ ] Username change
- [ ] Profile picture upload
- [ ] Settings save correctly
- [ ] Account deletion

### If You Changed: Album/Music Features
- [ ] Wishlist add/remove
- [ ] Library display
- [ ] Album details
- [ ] Discogs sync

### If You Changed: Payment System
- [ ] Stripe integration
- [ ] Payment amounts correct
- [ ] Payment confirmation
- [ ] Payment errors handled

### If You Changed: Navigation/UI
- [ ] All tabs work
- [ ] Deep navigation works
- [ ] Back button behavior
- [ ] Tab state preserved

---

## 🎯 By User Flow

### New User Journey (2 min)
- [ ] Register new account
- [ ] Verify email
- [ ] Complete profile
- [ ] Browse home screen
- [ ] Place first order (use anniversary free order if active)

### Returning User Journey (2 min)
- [ ] Log in
- [ ] View home screen
- [ ] Check current order status
- [ ] Browse album library
- [ ] Navigate between tabs

### Order Journey - Paid (3 min)
- [ ] Navigate to order screen
- [ ] Enter/select address
- [ ] Validate address
- [ ] Select payment amount
- [ ] Complete payment
- [ ] Verify order created

### Order Journey - Free (2 min)
- [ ] Check free order availability
- [ ] Navigate to order screen
- [ ] Select "Use Free Order"
- [ ] Enter/validate address
- [ ] Place free order
- [ ] Verify free order count decremented

### Curator Journey (3 min)
- [ ] Become a curator
- [ ] Receive order notification
- [ ] View pending orders
- [ ] Select album for order
- [ ] Complete curation

---

## 📱 Platform-Specific Quick Checks

### Android
- [ ] Back button behaves correctly
- [ ] Push notifications receive and display
- [ ] Keyboard behavior correct
- [ ] App doesn't crash on rotation (if rotation enabled)

### iOS
- [ ] Safe area respected
- [ ] Push notifications work
- [ ] Keyboard dismisses correctly
- [ ] Swipe back gesture works

---

## 🔍 Common Regression Points

These are areas that tend to break when changes are made elsewhere:

### Data Persistence
- [ ] Free order count persists
- [ ] User preferences save
- [ ] Login state persists
- [ ] Order history accessible

### State Management
- [ ] Provider updates trigger UI updates
- [ ] Navigation state preserved
- [ ] Tab state maintained

### API Integrations
- [ ] Firebase operations work
- [ ] Stripe payment processing
- [ ] Shippo address validation
- [ ] Discogs API calls

### Error Handling
- [ ] Network errors caught
- [ ] Payment errors displayed
- [ ] Form validation works
- [ ] Graceful degradation

---

## ⏱️ Time Estimates

- **Critical Path Only:** ~10 minutes
- **Critical + Affected Features:** ~15-20 minutes  
- **Full Quick Check:** ~25-30 minutes
- **Comprehensive (full checklist):** ~2-3 hours

---

## 🚨 Stop and Investigate If:

- [ ] App crashes on launch
- [ ] Can't log in
- [ ] Can't place an order
- [ ] Payment processing fails
- [ ] Console shows errors
- [ ] Navigation is broken
- [ ] Critical features missing

---

## ✅ Sign-Off

**Tested By:** _______________  
**Date:** _______________  
**Version:** _______________  
**Result:** [ ] Pass [ ] Fail - See issues below  

**Issues Found:**
1. _______________________________
2. _______________________________
3. _______________________________

---

## 💡 Pro Tips

1. **Test on clean state** - Log out and log back in before testing
2. **Clear cache** - Sometimes issues only appear with fresh data
3. **Test both paths** - New user vs existing user, paid vs free, etc.
4. **Use real data** - Test with actual addresses, cards (test mode), etc.
5. **Check console** - Always keep an eye on debug console for errors

---

**For comprehensive testing, use:** `FUNCTIONAL_TESTING_CHECKLIST.md`  
**For guidance on testing with Cursor, see:** `TESTING_WITH_CURSOR.md`

