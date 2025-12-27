# Google Play Store Deployment Guide

## App Icon Setup

### Option 1: Use an existing icon
If you have a ShopaFlow logo/icon (1024x1024 PNG), place it at:
```
assets/icon/icon.png
```

Then run:
```bash
flutter pub run flutter_launcher_icons
```

### Option 2: Create a simple icon online
1. Go to https://www.canva.com or https://www.figma.com
2. Create a 1024x1024 px design
3. Add "SF" text or shopping cart icon with green background (#4CAF50)
4. Export as PNG
5. Save to `assets/icon/icon.png`
6. Run: `flutter pub run flutter_launcher_icons`

### Option 3: Use Flutter Icon Generator
1. Visit: https://icon.kitchen/
2. Upload your design or use built-in icons
3. Select "Flutter" as the platform
4. Download and replace the generated icons

## Signing Configuration

### Generate Upload Keystore (First Time Only)

Run this command:
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

When prompted:
- Password: `shopaflow123` (or your own secure password)
- Name: Your name
- Organization: Your company name
- City, State, Country: Your location

**IMPORTANT**: Keep this keystore file secure! You'll need it for all future updates.

### Configure Environment Variables (Optional but Recommended)

For better security, set environment variables:

**Windows:**
```powershell
$env:KEY_ALIAS="upload"
$env:KEY_PASSWORD="your_key_password"
$env:STORE_PASSWORD="your_store_password"
```

**Linux/Mac:**
```bash
export KEY_ALIAS="upload"
export KEY_PASSWORD="your_key_password"
export STORE_PASSWORD="your_store_password"
```

## Build Release APK/Bundle

### Build APK (for testing)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (for Play Store - Recommended)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

## Google Play Console Setup

### 1. Create Developer Account
- Go to: https://play.google.com/console
- Pay one-time $25 registration fee
- Complete account verification

### 2. Create New App
1. Click "Create app"
2. Fill in details:
   - App name: **ShopaFlow - POS System**
   - Default language: English (United States)
   - App or game: App
   - Free or paid: Free (or Paid if charging)
   - Category: Business
   - Accept declarations

### 3. Store Listing
**Required Information:**
- **App name**: ShopaFlow - POS System
- **Short description** (80 chars):
  ```
  Modern mobile POS system for shops, bars & wholesalers with offline support
  ```

- **Full description** (4000 chars):
  ```
  ShopaFlow is a comprehensive mobile Point of Sale (POS) system designed for small to medium businesses including shops, bars, restaurants, and wholesalers.

  🚀 KEY FEATURES:
  
  ✓ Offline-First Design - Works without internet
  ✓ Product Management - Easy catalog with search & filtering
  ✓ Sales Processing - Quick checkout with shopping cart
  ✓ Receipt Printing - Bluetooth/thermal printer support
  ✓ Inventory Tracking - Real-time stock monitoring
  ✓ Customer Management - Track purchases & loyalty
  ✓ Multi-Currency - USD ⇆ ZWL conversion
  ✓ Data Export - CSV backup and reporting
  ✓ Clean Interface - Modern, intuitive design

  📦 INVENTORY MANAGEMENT:
  - Real-time stock tracking
  - Low stock alerts
  - CSV import/export
  - Product categories & SKUs
  - Barcode support

  💳 PAYMENT PROCESSING:
  - Multiple payment methods
  - Cash, card, mobile money
  - Receipt generation & printing

  📊 BUSINESS INSIGHTS:
  - Daily/weekly/monthly sales reports
  - Product performance tracking
  - Customer analytics

  Perfect for retail shops, restaurants, bars, wholesalers, and any business needing reliable POS functionality.
  ```

- **Screenshots**: 
  - Take 2-8 screenshots (720x1280 or 1080x1920)
  - Use device to capture: Checkout, Products, Sales, Settings screens

- **Feature graphic**: 1024x500 px banner image

- **App icon**: Already configured (512x512 will be auto-generated)

### 4. Content Rating
1. Start questionnaire
2. Select category: "Utility, Productivity, Communication or Other"
3. Answer questions (typically all "No" for POS app)
4. Submit for rating

### 5. Privacy Policy
Required for Play Store. Create a simple one:

```
Privacy Policy for ShopaFlow

Last updated: December 4, 2025

Information Collection and Use
ShopaFlow is an offline-first POS application. All data is stored locally on your device.

Data Storage
- Product information
- Sales records
- Customer data

We do not collect, transmit, or share any personal information with third parties.

Contact Us
If you have questions about this Privacy Policy, contact us at: your-email@example.com
```

Host this at: GitHub Pages, your website, or use a service like https://www.freeprivacypolicy.com/

### 6. App Access
- If using special features (Bluetooth), explain in notes
- Provide demo account if needed (not required for POS)

### 7. Upload App Bundle
1. Go to "Production" → "Create new release"
2. Upload `app-release.aab`
3. Add release notes:
   ```
   Initial release of ShopaFlow POS System
   
   Features:
   - Offline POS functionality
   - Product & inventory management
   - Receipt printing
   - Sales tracking
   - Customer management
   ```

### 8. Review and Publish
- Review all sections
- Submit for review
- Approval typically takes 1-3 days

## Testing Before Submission

### Internal Testing
1. Build app bundle: `flutter build appbundle --release`
2. Upload to Internal Testing track
3. Add test users via email
4. Test thoroughly for 1-2 weeks

### Closed Testing
1. Expand to closed testing
2. Add more testers
3. Gather feedback

### Production
Once testing is complete, promote to production.

## Post-Launch

### App Updates
1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # 1.0.1 is version name, 2 is version code
   ```

2. Build new bundle:
   ```bash
   flutter build appbundle --release
   ```

3. Upload to Play Console with release notes

### Monitoring
- Check Play Console for:
  - Crash reports
  - ANRs (App Not Responding)
  - User reviews
  - Performance metrics

## Checklist Before Submission

- [ ] App icon generated and looks good
- [ ] Keystore created and backed up securely
- [ ] Release build tested on physical device
- [ ] All features working in release mode
- [ ] Privacy policy created and hosted
- [ ] Screenshots captured (2-8 images)
- [ ] Feature graphic created (1024x500)
- [ ] Store listing text written
- [ ] Content rating completed
- [ ] App bundle built successfully
- [ ] No crashes in release mode
- [ ] Bluetooth printing tested (if applicable)
- [ ] Database operations verified

## Common Issues

### Issue: Signing failed
**Solution**: Check keystore path and passwords in build.gradle.kts

### Issue: App crashes in release mode
**Solution**: Check ProGuard rules, test with `flutter run --release`

### Issue: Missing permissions
**Solution**: All Bluetooth permissions added to AndroidManifest.xml

### Issue: App bundle rejected
**Solution**: Check target SDK is 33+ (currently 34)

## Support

For issues during deployment:
- Flutter Documentation: https://flutter.dev/docs/deployment/android
- Play Console Help: https://support.google.com/googleplay/android-developer

---

**Current Configuration:**
- Application ID: `com.shopaflow.pos`
- Version: 1.0.0 (Build 1)
- Min SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Signing: Release keystore required
