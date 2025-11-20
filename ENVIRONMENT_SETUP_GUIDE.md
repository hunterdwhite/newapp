# 🔑 Environment Setup Guide

## Required Environment Variables

Create a `.env` file in the project root with the following variables:

### Firebase Configuration
```bash
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
```

### Payment Processing (Stripe)
```bash
STRIPE_PUBLISHABLE_KEY=pk_test_your_test_key  # Use pk_live_ for production
STRIPE_SECRET_KEY=sk_test_your_test_key        # Use sk_live_ for production
```

### Shipping (Shippo)
```bash
SHIPPO_TOKEN=shippo_test_your_token
```

### Email Service (SendGrid)
```bash
SENDGRID_API_KEY=SG.your_api_key_here
EMAIL_FROM_ADDRESS=noreply@yourdomain.com
```

### Discogs API
```bash
DISCOGS_CONSUMER_KEY=your_consumer_key
DISCOGS_CONSUMER_SECRET=your_consumer_secret
```

## Where to Get API Keys

1. **Firebase**: https://console.firebase.google.com → Project Settings
2. **Stripe**: https://dashboard.stripe.com/apikeys
3. **Shippo**: https://apps.goshippo.com/settings/api
4. **SendGrid**: https://app.sendgrid.com/settings/api_keys
5. **Discogs**: https://www.discogs.com/settings/developers

## Security Notes

⚠️ **NEVER commit .env files to version control**
⚠️ **Use test keys for development, live keys only for production**
⚠️ **Rotate API keys every 90 days**

