# Simple Expense - Tester Report & Developer Onboarding Guide

**Date:** February 17, 2026  
**Purpose:** Feature status documentation and file structure guide for new developers

---



## Feature Status Overview

### ✅ Fully Completed Features
- **FR-1**: User Authentication (Sign Up / Sign In)
- **FR-2**: Group Creation (3-step wizard)
- **FR-3**: Adding Expenses
- **FR-5**: Group Dashboard
- **FR-7**: Join Group via Invite Code


---

## Completed Features

### FR-1: User Authentication ✅
**Status:** Fully Implemented & Tested

**Functionality:**
- Email/password sign up with validation
- Email/password sign in
- Firebase Authentication integration
- Form validation (email format, password length ≥6)
- Error handling and user feedback

**Files:**
- `lib/screens/login_screen.dart` - Login UI
- `lib/screens/signup_screen.dart` - Sign up UI
- `lib/providers/auth_provider.dart` - Authentication state management
- `lib/services/auth_service.dart` - Firebase Auth wrapper
- `test/auth_unit_test.dart` - Unit tests for validation logic


---

### FR-2: Group Creation ✅
**Status:** Fully Implemented

**Functionality:**
- 3-step  for creating groups:
  1. **Step 1:** Enter group name (max 50 chars, required)
  2. **Step 2:** Add members by email (optional), generate & share invite code
  3. **Step 3:** Select currency (SEK/USD/EUR), create group in Firestore
- Invite code generation (6-character alphanumeric)
- Share invite code functionality
- Currency selection

**Files:**
- `lib/screens/create_group_step1.dart` - Group name input
- `lib/screens/create_group_step2.dart` - Member invitation & invite code
- `lib/screens/create_group_step3.dart` - Currency selection & group creation
- `lib/services/firestore_service.dart` - `createGroup()` method

---

### FR-3: Adding Expenses ✅
**Status:** Fully Implemented

**Functionality:**
- Add expense button from group dashboard
- Enter expense description and amount
- Select payer (currently defaults to "Me")
- Navigate to split screen
- Validation: description and amount required, amount must be > 0
- Zero amount handling (validation prevents submission)

**Files:**
- `lib/screens/add_expense_screen.dart` - Expense input form
- `lib/screens/expense_split_screen.dart` - Member selection & split configuration
- `lib/services/firestore_service.dart` - `addExpense()` method


---

### FR-4: Equal Split Logic 
(Partially Implemented)
**Functionality:**
- Expenses split equally among selected group members
- Default: All members selected automatically
- Users can toggle members in/out of split
- Split amount displayed next to each member 
- Payer can be different from current user (collaborative entry)
- Other members name are not showing instead showing with user id only
 "Split Equally" button exists in UI but currently has no action handler

**Files:**
- `lib/screens/expense_split_screen.dart` - Split UI with member checkboxes
- `lib/services/balance_service.dart` - `calculateNetBalances()` method
- `lib/models/models.dart` - `Expense` model with `splitWith` field



---

### FR-5: Group Dashboard ✅
**Status:** Fully Implemented

**Functionality:**
- Display all expenses for selected group
- Real-time updates via Firestore streams
- Total balance calculation
- Navigation to expense detail screen
- Add expense button (+ icon)
- Empty state with call-to-action
- Sort by Description/People (UI present)

**Files:**
- `lib/screens/group_dashboard.dart` - Main dashboard screen
- `lib/screens/widgets/expense_widgets.dart` - Reusable expense UI components
- `lib/providers/groups_provider.dart` - Group state management


---


### FR-7: Join Group via Invite Code ✅
**Status:** Fully Implemented

**Functionality:**
- Enter 6-character invite code (case-insensitive)
- Validation: code must exist, user must not already be member
- Add user to group members list in Firestore
- Automatic group list refresh after joining

**Files:**
- `lib/screens/join_group_screen.dart` - Invite code input UI
- `lib/services/firestore_service.dart` - `joinGroupByCode()` method
- `lib/providers/groups_provider.dart` - `joinGroupByCode()` wrapper


---

## Semi-Completed Features

### FR-8: Expense List with Sorting/Filtering 🟡
**Status:** UI Complete, Functionality Partially Implemented

**Functionality:**
- Expense list screen with search bar
- Sort dropdown (Description, People) - UI present
- Filter dropdown (All, etc.) - UI present
- Search by description
- **Note:** Sort/Filter logic may need verification/testing

**Files:**
- `lib/screens/expense_list_screen.dart` - Comprehensive expense list view

**Test Coverage:** ⚠️ No tests

---

### FR-9: Expense Detail View 🟡
**Status:** View Complete, Edit Functionality Status Unknown

**Functionality:**
- Display expense details (description, amount, payer, split info)
- View which members are included in split
- **Note:** Edit/delete functionality may be pending

**Files:**
- `lib/screens/expense_detail_screen.dart` - Expense detail display
- `lib/services/firestore_service.dart` - `updateExpense()` method exists

**Test Coverage:** ⚠️ No tests

---

## File Structure & Responsibilities

### 📁 Core Application Files

#### `lib/main.dart`
- Application entry point
- Firebase initialization
- Provider setup (AuthProvider, GroupsProvider)
- Auth state stream handling (routes to LoginScreen or HomeScreen)

#### `lib/firebase_options.dart`
- Firebase configuration (auto-generated)

---

### 📁 Screens (`lib/screens/`)

#### Authentication Screens
- **`login_screen.dart`** - User login form with email/password
- **`signup_screen.dart`** - User registration form

#### Home & Navigation
- **`home_screen.dart`** - Main screen after login, displays user's groups list
  - Shows "Create Group" and "Join Group" buttons
  - Lists all groups user belongs to
  - Navigates to GroupDashboardScreen when group selected

#### Group Management Screens
- **`create_group_step1.dart`** - Step 1: Enter group name
- **`create_group_step2.dart`** - Step 2: Add members by email, generate/share invite code
- **`create_group_step3.dart`** - Step 3: Select currency, create group in Firestore
- **`join_group_screen.dart`** - Join existing group via invite code

#### Expense Management Screens
- **`group_dashboard.dart`** - Main dashboard showing expenses for a group
  - Displays expense list
  - Shows total balance
  - Add expense button
  - Navigation to expense detail
- **`add_expense_screen.dart`** - Form to add new expense (description, amount, payer)
- **`expense_split_screen.dart`** - Select members for expense split, save expense
- **`expense_list_screen.dart`** - Comprehensive expense list with search, sort, filter
- **`expense_detail_screen.dart`** - View expense details (description, amount, payer, split members)

#### Balance & Settlement
- **`balance_screen.dart`** - Display net balances and settlement suggestions

#### Widgets
- **`widgets/expense_widgets.dart`** - Reusable UI components (ExpenseHeaderWidget, GroupInfoWidget, etc.)

---

### 📁 Providers (`lib/providers/`)

#### `auth_provider.dart`
- Manages authentication state
- Methods: `login()`, `signUp()`, `logout()`
- Getters: `currentUserId`, `currentUserEmail`, `currentUserName`
- Password visibility toggles for UI

#### `groups_provider.dart`
- Manages group state and data
- Streams user's groups from Firestore
- Tracks selected group, balances, member counts
- Methods: `selectGroup()`, `joinGroupByCode()`, `startListening()`

---

### 📁 Services (`lib/services/`)

#### `auth_service.dart`
- Firebase Authentication wrapper
- Methods: `signUp()`, `signIn()`, `signOut()`
- Stream: `authStateChanges` for auth state monitoring
- Getter: `currentUser`

#### `firestore_service.dart`
- All Firestore database operations
- **User operations:** `saveUser()`
- **Group operations:** 
  - `createGroup()` - Create new group
  - `streamUserGroups()` - Stream groups for a user
  - `getGroupMembers()` - Fetch group members
  - `joinGroupByCode()` - Add user to group via invite code
- **Expense operations:**
  - `addExpense()` - Create new expense
  - `updateExpense()` - Update existing expense
  - `streamGroupTotalBalance()` - Stream total expenses for group
  - `streamGroupMembersCount()` - Stream member count

#### `balance_service.dart`
- Business logic for balance calculations
- **Methods:**
  - `calculateNetBalances()` - Calculate net balance per member
  - `calculateSettlements()` - Generate settlement suggestions (minimized transactions)
  - `getUserBalance()` - Get balance for specific user
  - `getTotalPaid()` - Total amount user has paid
  - `getTotalOwed()` - Total amount user owes
  - `getUserSettlements()` - Settlements involving specific user
- **Model:** `Settlement` class (fromUserId, toUserId, amount)

---



### 📁 Theme (`lib/theme/app_theme.dart`)
- App-wide color scheme and styling
- Light/dark theme definitions
- Reusable color constants

---




## Quick Start for New Developers

### 1. Understanding the Flow
```
Login/Signup → HomeScreen (group list) → 
  Create Group (3 steps) OR Join Group (invite code) → 
  GroupDashboard → Add Expense → ExpenseSplitScreen → 
  BalanceScreen (view settlements)
```

### 2. Key Dependencies
- **Firebase:** Authentication & Firestore
- **Provider:** State management
- **Cloud Firestore:** Database


---


---
