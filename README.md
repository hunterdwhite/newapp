# 🎵 Dissonant App

A Flutter-based music discovery and vinyl subscription service connecting users with curated album selections.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.10+
- Firebase CLI
- Node.js 18+

### Setup
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📚 Documentation

All documentation has been organized in the `/docs` folder:

### Essential Docs
- **[Functional Testing Checklist](docs/FUNCTIONAL_TESTING_CHECKLIST.md)** - Comprehensive testing guide
- **[Production Readiness](docs/PRODUCTION_READINESS_SUMMARY.md)** - Deployment readiness assessment
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[Development Guide](docs/DEVELOPMENT_GUIDE.md)** - Development setup and architecture
- **[Deployment Safety](docs/DEPLOYMENT_SAFETY.md)** - Safe deployment procedures

### Key Features
- 🎵 Music discovery with curator system
- 📦 Vinyl subscription service
- 💳 Stripe payment integration
- 🚚 Shippo shipping integration
- 📧 SendGrid email notifications
- 🔐 Firebase authentication & Firestore database

## 🛠️ Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Firebase Functions, AWS Lambda
- **Database:** Cloud Firestore
- **Payments:** Stripe
- **Shipping:** Shippo
- **Email:** SendGrid

## 📦 Project Structure
```
lib/
├── screens/     # UI screens
├── services/    # Business logic
├── models/      # Data models
└── widgets/     # Reusable components

functions/       # Firebase Cloud Functions
my-express-app/  # AWS Lambda backend
scripts/         # Utility scripts
docs/            # Documentation
```

## 🧪 Testing
```bash
flutter test
```

## 🚀 Deployment

### Backend
```bash
# Firebase Functions
cd functions
firebase deploy --only functions

# AWS Lambda
cd my-express-app/dissonantservice
serverless deploy --stage prod
```

### Frontend
```bash
# iOS
flutter build ipa --release

# Android
flutter build appbundle --release
```

## 📞 Support
For detailed documentation, see the `/docs` folder.

---

**Made with ❤️ by the Dissonant Team**
