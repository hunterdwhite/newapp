# 🤖 Testing with Cursor - Usage Guide

This guide explains how to use the `FUNCTIONAL_TESTING_CHECKLIST.md` document to prevent Cursor from breaking existing functionality when adding new features.

---

## 📖 Table of Contents
1. [Why This Matters](#why-this-matters)
2. [Before Making Changes](#before-making-changes)
3. [While Cursor is Working](#while-cursor-is-working)
4. [After Changes Are Complete](#after-changes-are-complete)
5. [Quick Testing for Minor Changes](#quick-testing-for-minor-changes)
6. [Tips for Working with Cursor](#tips-for-working-with-cursor)

---

## Why This Matters

**The Problem:**  
When you ask Cursor to add new features, it sometimes:
- Removes existing functionality to make room for new code
- Changes logic in unexpected ways
- Alters behavior of critical features
- Removes error handling or validation

**The Solution:**  
Use the `FUNCTIONAL_TESTING_CHECKLIST.md` as a reference document for Cursor to understand what must remain functional.

---

## Before Making Changes

### Step 1: Identify Relevant Sections
Look at `FUNCTIONAL_TESTING_CHECKLIST.md` and identify which sections relate to the changes you're planning.

**Example:**
- Adding a new payment method → Check Section 8 (Payment Processing)
- Modifying profile screen → Check Section 2 (User Profile & Settings)
- Changing order flow → Check Section 3 (Order System)

### Step 2: Set Context for Cursor
When starting a conversation with Cursor about changes, provide context:

```
I need to add [NEW FEATURE]. Before we start, please read 
FUNCTIONAL_TESTING_CHECKLIST.md sections [X, Y, Z] to understand 
what existing functionality must be preserved.
```

**Example:**
```
I need to add PayPal payment support. Before we start, please read 
FUNCTIONAL_TESTING_CHECKLIST.md Section 8 (Payment Processing) to 
understand the existing Stripe integration that must remain functional.
```

### Step 3: Baseline Check (Optional but Recommended)
For major changes, run through the relevant checklist sections before making changes to establish a baseline:

```
Before we make changes, let's verify the baseline functionality:
- Can you help me test Section 3.1 (Order Flow - Standard Order)?
- Let's make sure address validation is currently working
```

---

## While Cursor is Working

### Give Cursor the Context Document
When asking Cursor to make changes, explicitly reference the testing document:

```
As you implement this feature, please ensure you don't break any 
functionality listed in FUNCTIONAL_TESTING_CHECKLIST.md. 

Specifically, maintain:
- [Specific functionality 1]
- [Specific functionality 2]
- [Specific functionality 3]
```

### Use Checkpoints
For complex changes, break them into steps and check functionality after each:

```
Let's implement this in steps:

Step 1: Add the new payment provider integration
→ After this step, verify Section 8.1 (Stripe Integration) still works

Step 2: Update the UI to show both payment options
→ After this step, verify both old and new payment flows work

Step 3: Add validation for the new payment method
→ After this step, verify all error handling still works
```

### Remind Cursor About Critical Features
If you notice Cursor starting to modify critical code, remind it:

```
Wait - before modifying the _handlePlaceOrder method, please review 
FUNCTIONAL_TESTING_CHECKLIST.md Section 3.7 (Duplicate Order Prevention).
We need to ensure the 30-second cooldown mechanism is preserved.
```

---

## After Changes Are Complete

### Step 1: Code Review with Cursor
Ask Cursor to review its own changes against the checklist:

```
Now that changes are complete, please review your modifications against 
FUNCTIONAL_TESTING_CHECKLIST.md. 

Check specifically:
- Section 3 (Order System) - does everything still work?
- Section 8 (Payment Processing) - are both payment methods functional?
- Section 16 (Error Handling) - is error handling still robust?

List any functionality that might have been affected.
```

### Step 2: Manual Testing
Open `FUNCTIONAL_TESTING_CHECKLIST.md` and test the relevant sections:

1. Go through each checkbox in the affected sections
2. Test the functionality described
3. Mark items as checked if working
4. Document any issues in the "Issues Found" section

### Step 3: Quick Sanity Tests
Even if you did comprehensive testing, do a final quick check:

```
Quick sanity check - can you walk me through:
1. Can users still log in? (Section 1.3)
2. Can users still place orders? (Section 3.1)
3. Do payment methods work? (Section 8.1)
4. Are errors handled gracefully? (Section 16)
```

### Step 4: Document What Changed
In the checklist's "Notes" section, document:
- What feature was added
- Which sections were potentially affected
- Any new functionality to add to the checklist

---

## Quick Testing for Minor Changes

For small changes, you don't need the full checklist. Use this quick workflow:

### Minimal Testing Template

```
I'm making a small change to [COMPONENT/FEATURE].

Before we start:
1. What existing functionality in FUNCTIONAL_TESTING_CHECKLIST.md 
   might this affect?
2. After the change, what are the 3-5 most critical things to test?

After the change:
3. Help me verify those critical items still work
```

### Critical Path Testing
For any change, always test these core paths:
- [ ] User can log in
- [ ] User can navigate the app
- [ ] User can place an order (if order flow was touched)
- [ ] User can access their profile
- [ ] No crashes or errors in console

---

## Tips for Working with Cursor

### 🎯 Be Specific About Preservation

**Bad:**
```
Add a new payment method
```

**Good:**
```
Add Apple Pay as a payment method while preserving:
- Existing Stripe integration (Section 8.1)
- Payment amount validation (Section 8.3)
- Order creation flow after payment (Section 3.1)
- Error handling for failed payments (Section 16.3)

Reference FUNCTIONAL_TESTING_CHECKLIST.md for details on what must be maintained.
```

### 🔄 Use Iterative Approach

Break large changes into smaller chunks and test after each:

```
Let's add this feature in 3 phases:

Phase 1: Add UI components only (no logic changes)
→ Test: Verify existing functionality still works

Phase 2: Add new logic alongside existing logic
→ Test: Verify both old and new paths work

Phase 3: Refactor if needed
→ Test: Final comprehensive test of all flows
```

### 📋 Reference Specific Sections

Instead of:
```
Make sure orders still work
```

Use:
```
Ensure Section 3.1 (Order Flow - Standard Order) remains functional:
- Address input works
- Address validation works  
- Payment selection works
- Order submission works
- Duplicate prevention works (Section 3.7)
```

### 🛡️ Protect Critical Code

For mission-critical functionality, explicitly tell Cursor not to modify:

```
We're adding [NEW FEATURE]. 

⚠️ CRITICAL BUSINESS RULES THAT MUST BE PRESERVED:
1. Users CANNOT place order if they have outstanding order (new/sent/delivered status)
2. Curators get 1 CREDIT (not full free order) per curation
3. Returns grant FULL free order (not just credit)
4. Curators NEVER see user shipping addresses (admin only)

DO NOT MODIFY these critical functions without explicit approval:
- _handlePlaceOrder() in order_screen.dart
- useFreeOrder() in home_screen.dart  
- processPayment() in payment_service.dart
- Address display logic in curator screens

If you need to modify any of these, explain why and show me the 
changes before making them.
```

### 📝 Keep a Change Log

For each Cursor session, keep notes:

```
Session: [Date]
Goal: [What you're adding/changing]
Sections Affected: [Checklist sections]
Critical Functions Modified: [List]
Testing Status: [Sections tested and results]
```

### 🚨 Red Flags to Watch For

If Cursor suggests any of these, review carefully:

- Removing existing error handling
- Simplifying complex logic (may remove edge case handling)
- Consolidating similar functions (may lose functionality)
- "Cleaning up" code (may remove necessary checks)
- Changing data models (may break existing data)
- **Modifying order placement logic (could break order prevention)**
- **Changing credit/free order logic (could break reward system)**
- **Altering curator screens (could expose user addresses)**

Ask Cursor:
```
Before we proceed with this change, explain:
1. What functionality are we removing/simplifying?
2. What edge cases were being handled that won't be anymore?
3. What items from FUNCTIONAL_TESTING_CHECKLIST.md might break?
4. Do any of the 4 CRITICAL BUSINESS RULES get affected?
   - Order prevention for users with outstanding orders?
   - Curator credit vs full free order distinction?
   - Return free order granting?
   - Address privacy for curators?
```

---

## Example Workflows

### Scenario 1: Adding a New Feature

```
Me: I want to add a feature that lets users favorite albums. Before we start, 
    please review FUNCTIONAL_TESTING_CHECKLIST.md Section 6 (Album Library & 
    Wishlist) and Section 7 (Feed & Social Features) to understand existing 
    functionality that must be preserved.

Cursor: [Reviews sections and confirms understanding]

Me: Great. As you implement this:
    1. Don't modify the existing wishlist functionality (Section 6.2)
    2. Ensure album details screen still works (Section 6.3)
    3. Maintain feed display functionality (Section 7.1)
    
    Implement the favorite feature as an addition, not a replacement for anything.

[After Cursor implements]

Me: Now let's test. Walk me through:
    1. Can users still add albums to wishlist? (Section 6.2)
    2. Can users still view album details? (Section 6.3)
    3. Does the new favorite feature work?
    4. Do both features work together without conflicts?
```

### Scenario 2: Fixing a Bug

```
Me: There's a bug in the order submission. Before we fix it, let's understand
    the current behavior documented in FUNCTIONAL_TESTING_CHECKLIST.md Section 3.1
    (Order Flow - Standard Order) and Section 3.7 (Duplicate Order Prevention).

Cursor: [Reviews sections]

Me: The bug is [DESCRIPTION]. As you fix it:
    1. Maintain all validation checks listed in Section 3.1
    2. Preserve the duplicate order prevention (Section 3.7)
    3. Keep all error handling (Section 16.3)
    
    Only change what's necessary to fix the bug.

[After fix]

Me: Let's verify:
    1. Is the bug fixed?
    2. Does order submission still work end-to-end? (Section 3.1)
    3. Does duplicate prevention still work? (Section 3.7)
    4. Are all error messages still showing? (Section 16)
```

### Scenario 3: Refactoring Code

```
Me: I want to refactor the order flow to be cleaner. This is risky because
    order flow is critical. Please:
    
    1. Read FUNCTIONAL_TESTING_CHECKLIST.md Section 3 (entire Order System)
    2. List every piece of functionality that must be preserved
    3. Propose a refactoring approach that maintains ALL of it
    
    Don't implement yet - just propose the approach.

Cursor: [Proposes approach]

Me: [Review proposal] Looks good, but ensure these are also maintained:
    - [Additional item 1]
    - [Additional item 2]
    
    Implement the refactoring in small steps so we can test after each.

[After each step]

Me: Test checkpoint - verify Section 3.X still works before continuing.
```

---

## Maintaining the Checklist

### When to Update the Checklist

Update `FUNCTIONAL_TESTING_CHECKLIST.md` when:
- You add new major features
- You change critical user flows
- You add new validation or error handling
- You implement new integrations
- You discover functionality that wasn't documented

### How to Update

Ask Cursor to help:

```
We just added [NEW FEATURE]. Please update FUNCTIONAL_TESTING_CHECKLIST.md 
to include testing for this new functionality. 

Add a new section or subsection that covers:
- How to test the feature works
- Integration points with existing features
- Edge cases to verify
- Error scenarios to test

Follow the same format as existing sections.
```

### Keep It Current

After each major update cycle:

```
Review FUNCTIONAL_TESTING_CHECKLIST.md and:
1. Mark any sections that are outdated
2. Add any new features that were implemented
3. Remove any deprecated functionality
4. Update version number and date at bottom
```

---

## Quick Reference Commands

### Before ANY Changes
```
Read FUNCTIONAL_TESTING_CHECKLIST.md sections [X, Y, Z] AND the 
CRITICAL BUSINESS RULES section to understand what must be preserved.

The 4 rules that MUST NEVER break:
1. Order prevention (no new order with outstanding order)
2. Curator credits (1 credit, not free order)
3. Return free orders (full free order on return)
4. Address privacy (curators never see addresses)
```

### During Changes
```
As you implement this, maintain all functionality in 
FUNCTIONAL_TESTING_CHECKLIST.md Section [X].
```

### After Changes
```
Review your changes against FUNCTIONAL_TESTING_CHECKLIST.md. 
What functionality might have been affected?
```

### Testing
```
Walk me through testing Section [X] of FUNCTIONAL_TESTING_CHECKLIST.md
to verify nothing broke.
```

---

## Remember

1. **Prevention is easier than fixing** - Give Cursor context upfront
2. **Test incrementally** - Don't wait until the end to test
3. **Be specific** - Reference exact sections and functionality
4. **Document changes** - Keep notes on what was modified
5. **Update the checklist** - Keep it current as your app evolves

---

**Happy coding! 🚀**

Let Cursor help you build features while this checklist helps you maintain quality.

