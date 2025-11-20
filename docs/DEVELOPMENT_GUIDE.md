# Dissonant App 2 - Development Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Development Setup](#development-setup)
5. [Architecture Overview](#architecture-overview)
6. [Key Features](#key-features)
7. [Development Workflow](#development-workflow)
8. [Testing](#testing)
9. [Deployment](#deployment)
10. [Contributing Guidelines](#contributing-guidelines)

## Project Overview

Dissonant App 2 is a Flutter-based mobile application that appears to be a music discovery and ordering platform. The app integrates with Discogs API for music data and uses Firebase for backend services including authentication, database, and cloud functions.

### Key Capabilities
- User authentication and profiles
- Music library management
- Album ordering system
- Social features and feeds
- Integration with Discogs music database
- Payment processing with Stripe
- Administrative dashboard

## Tech Stack

### Frontend
- **Flutter** (3.3.4+) - Cross-platform mobile framework
- **Dart** - Programming language
- **Provider** - State management
- **Google Fonts** - Typography

### Backend & Services
- **Firebase Core** - Backend infrastructure
- **Firebase Auth** - User authentication
- **Cloud Firestore** - NoSQL database
- **Firebase Storage** - File storage
- **Firebase Crashlytics** - Crash reporting
- **Firebase Cloud Functions** (Node.js) - Server-side logic

### Third-Party Integrations
- **Stripe** - Payment processing
- **Discogs API** - Music database integration
- **Google Sign-In** - Social authentication

### Development Tools
- **Flutter Lints** - Code analysis
- **ESLint** - JavaScript linting for Cloud Functions

## Project Structure

```
dissonantapp2/
├── lib/                          # Main Dart source code
│   ├── main.dart                 # App entry point
│   ├── routes.dart               # Route definitions
│   ├── navigator_service.dart    # Navigation service
│   ├── models/                   # Data models
│   │   ├── album.dart            # Album data structure
│   │   ├── order_model.dart      # Order state management
│   │   └── feed_item.dart        # Social feed items
│   ├── screens/                  # UI screens
│   │   ├── welcome_screen.dart   # Onboarding
│   │   ├── login_screen.dart     # Authentication
│   │   ├── home_screen.dart      # Main dashboard
│   │   ├── mymusic_screen.dart   # Music library
│   │   ├── order_screen.dart     # Order management
│   │   ├── profile_screen.dart   # User profiles
│   │   ├── feed_screen.dart      # Social feed
│   │   └── admin_dashboard_screen.dart # Admin panel
│   ├── widgets/                  # Reusable UI components
│   │   ├── retro_button_widget.dart     # Custom buttons
│   │   ├── app_bar_widget.dart          # Navigation bar
│   │   ├── bottom_navigation_widget.dart # Bottom nav
│   │   ├── spinning_cd_widget.dart      # Animated CD
│   │   └── dialog/                      # Modal dialogs
│   └── services/                 # Business logic services
│       ├── firestore_service.dart       # Database operations
│       ├── firebase_service.dart        # Firebase utilities
│       ├── payment_service.dart         # Stripe integration
│       └── usps_address_service.dart    # Address validation
├── functions/                    # Firebase Cloud Functions
│   ├── index.js                  # Function definitions
│   ├── package.json              # Node.js dependencies
│   └── .eslintrc.js              # Linting configuration
├── assets/                       # Static resources
│   ├── images/                   # App images and icons
│   └── videos/                   # Video assets
├── android/                      # Android-specific configuration
├── ios/                          # iOS-specific configuration
├── web/                          # Web platform support
├── test/                         # Unit and widget tests
├── scripts/                      # Build and deployment scripts
├── pubspec.yaml                  # Flutter dependencies
├── firebase.json                 # Firebase configuration
├── analysis_options.yaml         # Dart analysis rules
└── README.md                     # Basic project information
```

## Development Setup

### Prerequisites
1. **Flutter SDK** (3.3.4 or higher)
   ```bash
   flutter --version
   ```

2. **Dart SDK** (included with Flutter)

3. **Node.js** (v22+) for Firebase Cloud Functions
   ```bash
   node --version
   npm --version
   ```

4. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase --version
   ```

5. **Android Studio** (for Android development)
6. **Xcode** (for iOS development, macOS only)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd dissonantapp2
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install Firebase Functions dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

4. **Firebase Configuration**
   ```bash
   firebase login
   firebase use <project-id>
   ```

5. **Configure environment variables**
   Create `functions/.env` file:
   ```env
   DISCOGS_TOKEN=your_discogs_token
   DISCOGS_USERNAME=your_discogs_username
   ```

6. **Configure Stripe**
   - Add Stripe publishable key to your app configuration
   - Configure webhook endpoints for payment processing

### Running the App

1. **Start Firebase emulators (optional for local development)**
   ```bash
   firebase emulators:start
   ```

2. **Run the Flutter app**
   ```bash
   # For Android
   flutter run -d android
   
   # For iOS
   flutter run -d ios
   
   # For web
   flutter run -d chrome
   ```

## Architecture Overview

### Design Patterns

**MVC + Provider Pattern**
- **Models**: Data structures and business logic (`lib/models/`)
- **Views**: UI screens and widgets (`lib/screens/`, `lib/widgets/`)
- **Controllers**: Services handling business logic (`lib/services/`)
- **State Management**: Provider pattern for reactive state updates

**Service Layer Architecture**
- `FirestoreService`: Database operations and data persistence
- `PaymentService`: Stripe payment processing
- `UspsAddressService`: Address validation
- `WaitlistService`: User waitlist management

### Data Flow

1. **User Interaction** → Widget/Screen
2. **Business Logic** → Service Layer
3. **Data Persistence** → Firebase/Firestore
4. **State Updates** → Provider/ChangeNotifier
5. **UI Updates** → Widget Rebuilds

### Firebase Integration

**Authentication Flow**
```
User Input → Firebase Auth → Firestore User Doc → App State Update
```

**Data Synchronization**
```
Local State ↔ Firestore ↔ Cloud Functions ↔ External APIs (Discogs)
```

## Key Features

### 1. User Management
- **Authentication**: Email/password, Google Sign-In
- **Profiles**: Public and private user profiles
- **Username system**: Unique username validation

### 2. Music Library
- **Discogs Integration**: Sync personal music collections
- **Album Discovery**: Browse and search music catalog
- **Wishlist Management**: Save desired albums

### 3. Ordering System
- **CD Ordering**: Physical album ordering workflow
- **Address Management**: USPS address validation
- **Order Tracking**: Status updates and history
- **Payment Processing**: Stripe integration

### 4. Social Features
- **Activity Feeds**: User-generated content
- **Profile Sharing**: Public profile discovery
- **Music Sharing**: Album recommendations

### 5. Administrative Tools
- **Admin Dashboard**: Order management and user oversight
- **Analytics**: User behavior and order statistics

## Development Workflow

### Git Workflow
1. Create feature branch from `main`
2. Implement changes with descriptive commits
3. Test locally across platforms
4. Submit pull request for review
5. Deploy to staging environment
6. Deploy to production after approval

### Code Standards

**Dart/Flutter**
```dart
// Use descriptive variable names
final String userDisplayName = user.displayName ?? 'Anonymous';

// Prefer const constructors where possible
const RetroButton(
  text: 'Submit',
  onPressed: _handleSubmit,
);

// Use proper error handling
try {
  await _firestoreService.saveUserData(userData);
} catch (e) {
  _showErrorDialog('Failed to save data: $e');
}
```

**File Naming**
- Screens: `snake_case_screen.dart`
- Widgets: `snake_case_widget.dart`
- Models: `snake_case.dart`
- Services: `snake_case_service.dart`

### State Management Guidelines

**Provider Pattern**
```dart
// Model class
class OrderModel extends ChangeNotifier {
  bool _hasOrdered = false;
  
  bool get hasOrdered => _hasOrdered;
  
  void placeOrder() {
    _hasOrdered = true;
    notifyListeners();
  }
}

// Widget consumption
Consumer<OrderModel>(
  builder: (context, orderModel, child) {
    return Text('Has ordered: ${orderModel.hasOrdered}');
  },
)
```

### UI/UX Guidelines

**Design System**
- Use `RetroButton` for primary actions
- Implement `Windows95Window` for modal content
- Apply grainy background textures for authentic feel
- Use consistent color scheme throughout app

**Responsive Design**
- Portrait orientation only (configured in main.dart)
- Support multiple screen densities
- Implement proper padding and margins

## Testing

### Test Structure
```
test/
├── widget_test.dart      # Widget testing
├── unit_tests/           # Business logic tests
├── integration_tests/    # End-to-end tests
└── fixtures/             # Test data
```

### Running Tests
```bash
# Unit and widget tests
flutter test

# Integration tests
flutter drive --target=test_driver/app.dart

# Test coverage
flutter test --coverage
```

### Testing Guidelines
- Write unit tests for service classes
- Create widget tests for custom components
- Implement integration tests for critical user flows
- Mock external dependencies (Firebase, APIs)

## Deployment

### Build Configuration

**Android APK**
```bash
flutter build apk --release
```

**iOS App Store**
```bash
flutter build ios --release
```

**Web Deployment**
```bash
flutter build web
```

### Firebase Deployment

**Cloud Functions**
```bash
cd functions
npm run deploy
```

**Firestore Rules**
```bash
firebase deploy --only firestore:rules
```

**Complete Firebase Deployment**
```bash
firebase deploy
```

### Environment Management

**Development Environment**
- Use Firebase emulators for local testing
- Test API integrations with sandbox credentials
- Enable debug logging and crash reporting

**Production Environment**
- Configure production Firebase project
- Enable security rules and authentication
- Set up monitoring and alerting
- Configure proper backup strategies

## Contributing Guidelines

### Before Starting Development

1. **Check existing issues** and roadmap
2. **Discuss major changes** with team before implementation
3. **Follow coding standards** outlined in this guide
4. **Write tests** for new functionality
5. **Update documentation** as needed

### Pull Request Process

1. **Branch naming**: `feature/description` or `fix/description`
2. **Commit messages**: Use conventional commit format
3. **Code review**: Require at least one approval
4. **Testing**: Ensure all tests pass
5. **Documentation**: Update relevant docs

### Code Review Checklist

- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No hardcoded secrets or credentials
- [ ] Performance considerations addressed
- [ ] Security best practices followed
- [ ] Cross-platform compatibility verified

### Development Best Practices

**Security**
- Never commit API keys or secrets
- Use Firebase Security Rules for data protection
- Validate user input on both client and server
- Implement proper authentication checks

**Performance**
- Optimize image assets and loading
- Implement proper caching strategies
- Use Flutter performance best practices
- Monitor app size and memory usage

**Maintenance**
- Keep dependencies updated
- Monitor and fix deprecation warnings
- Implement proper error handling and logging
- Regular code refactoring and cleanup

---

**Need Help?**
- Check existing documentation and code comments
- Review similar implementations in the codebase
- Ask questions in team channels before making assumptions
- Test thoroughly across different devices and platforms

This development guide should be updated as the project evolves and new patterns or tools are adopted.