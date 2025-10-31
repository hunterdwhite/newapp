# Creating Notification Icon from app_icon.png

## Quick Instructions

### Using Android Asset Studio (Recommended)

1. Visit: https://romannurik.github.io/AndroidAssetStudio/icons-notification.html

2. Upload: `assets/icon/app_icon_foreground.png` or `assets/icon/app_icon.png`

3. Settings:
   - **Name**: `ic_notification`
   - **Trim**: Yes
   - **Padding**: 25%
   - **Shape**: None (will be white silhouette)

4. Download the generated ZIP file

5. Extract and copy all `drawable-*` folders to:
   ```
   android/app/src/main/res/
   ```

6. Rebuild your app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## Manual Creation (Photoshop/GIMP/Figma)

If you prefer to create it manually:

### Requirements:
- White foreground (#FFFFFF)
- Transparent background
- Simple silhouette of your Dissonant logo
- No colors, gradients, or shadows

### Sizes Needed:

| File | Size (px) | Density | Location |
|------|-----------|---------|----------|
| ic_notification.png | 24 × 24 | mdpi | drawable-mdpi/ |
| ic_notification.png | 36 × 36 | hdpi | drawable-hdpi/ |
| ic_notification.png | 48 × 48 | xhdpi | drawable-xhdpi/ |
| ic_notification.png | 72 × 72 | xxhdpi | drawable-xxhdpi/ |
| ic_notification.png | 96 × 96 | xxxhdpi | drawable-xxxhdpi/ |

### Design Steps:

1. Open your `assets/icon/app_icon.png` in your design tool
2. Convert to grayscale
3. Create a white silhouette (fill with #FFFFFF)
4. Make background transparent
5. Add 2dp padding (about 25% of canvas)
6. Export at all required sizes
7. Name all files `ic_notification.png`
8. Place in respective `drawable-*` folders

---

## What It Will Look Like

Your Dissonant logo will appear as a white silhouette, and Android will automatically tint it with your brand color (#FFA12C - orange).

### Example:
```
Your Logo (white) + Android Tint (orange) = Orange Logo Icon
```

---

## Testing

After adding the files:

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run --release

# Deploy updated cloud function
firebase deploy --only functions

# Test notification
# Create a test order assigned to a curator
```

You should see your custom Dissonant logo in the notification!

---

## Troubleshooting

**Problem**: Icon not showing
- Solution: Make sure all files are named exactly `ic_notification.png`
- Solution: Check files are in `drawable-*` folders (not `mipmap-*`)

**Problem**: Icon looks weird
- Solution: Ensure it's a simple white silhouette, not a colored image
- Solution: Add more padding (25-30% of canvas size)

**Problem**: Still seeing default icon
- Solution: Uninstall and reinstall the app (cached icon)

