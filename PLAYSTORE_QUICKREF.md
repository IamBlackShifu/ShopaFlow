# ShopaFlow - Google Play Store Quick Reference

## App Details
- **Package Name**: com.shopaflow.pos
- **App Name**: ShopaFlow - POS System
- **Version**: 1.0.0
- **Version Code**: 1
- **Category**: Business
- **Content Rating**: Everyone

## Store Listing Copy

### Short Description (80 chars max)
```
Modern mobile POS system for shops, bars & wholesalers with offline support
```

### Tags/Keywords
```
pos, point of sale, retail, shop, business, inventory, sales, receipt, barcode, offline, cash register, store management
```

## Required Assets Checklist

### Screenshots (Phone - Required)
- [ ] **2-8 screenshots** (16:9 aspect ratio recommended)
- Dimensions: 720x1280, 1080x1920, or 1440x2560
- Suggested screens to capture:
  1. Checkout/POS screen (main feature)
  2. Product list with search
  3. Product details/add product
  4. Sales history/reports
  5. Settings screen
  6. Receipt/print preview

### Feature Graphic (Required)
- [ ] **1 feature graphic**: 1024w x 500h (exactly)
- Format: PNG or JPEG, 24-bit
- Max size: 1MB
- Design tip: Include app name, tagline, and main visual

### App Icon (Handled by Flutter)
- [ ] **Minimalist Icon**: White line-art shopping bag on transparent background.
- [ ] **Theme Color**: Deep Emerald (#004D40) for consistent branding.

### Promotional Assets (Optional but Recommended)
- [ ] **Promo graphic**: 180w x 120h
- [ ] **TV Banner**: 1280w x 720h (if supporting Android TV)

## Privacy Policy Template

```markdown
# Privacy Policy for ShopaFlow

**Effective Date**: December 4, 2025

## Overview
ShopaFlow is an offline-first Point of Sale (POS) application designed for small businesses.

## Information We Collect
ShopaFlow stores all data locally on your device:
- Product catalog and inventory
- Sales transactions
- Customer information (if you choose to add it)
- Business settings and preferences

## Data Storage
- All data is stored locally using SQLite database
- No data is transmitted to external servers
- Backup/export features allow you to control your data

## Data Sharing
We do not collect, transmit, or share any data with third parties.

## Bluetooth Permissions
Bluetooth permissions are used solely for receipt printer connectivity.

## Your Rights
You maintain full control of your data:
- Export data at any time via CSV
- Delete all data from settings
- Uninstalling the app removes all local data

## Contact
For questions about this privacy policy:
- Email: [your-email@domain.com]
- Website: [your-website.com]

## Changes
We may update this policy. Changes will be posted with updated date.
```

## Store Listing Text

### Full Description (Max 4000 characters)
```
ShopaFlow is a comprehensive mobile Point of Sale (POS) system designed for small to medium businesses including retail shops, bars, restaurants, and wholesalers.

🚀 KEY FEATURES

✓ Offline-First Design
Work without internet connectivity. All data stored securely on your device.

✓ Product Management
• Quick product search and filtering
• Barcode scanning support
• Category organization
• Stock tracking with low-stock alerts
• Bulk import via CSV

✓ Sales Processing
• Fast checkout with shopping cart
• Multiple payment methods (cash, card, mobile money)
• Real-time inventory updates
• Receipt generation and printing

✓ Thermal Printer Support
• Bluetooth printer connectivity
• Receipt customization
• Supports 80mm thermal printers
• Standard system printer support

✓ Inventory Management
• Real-time stock monitoring
• Automatic stock deduction on sales
• Low stock warnings
• Product cost tracking for profit analysis

✓ Multi-Currency Support
• USD to ZWL currency conversion
• Customizable exchange rates
• Price display in multiple currencies

✓ Business Analytics
• Daily, weekly, and monthly sales reports
• Product performance tracking
• Export data to CSV for external analysis

✓ Customer Management
• Customer database
• Purchase history tracking
• Loyalty program ready

✓ Modern Interface
• Clean, intuitive design
• Fast performance
• Tablet and phone optimized
• Dark mode support

📱 PERFECT FOR:

• Retail stores
• Restaurants and cafes
• Bars and pubs
• Wholesalers
• Market stalls
• Pop-up shops
• Any business needing reliable POS

🔒 SECURITY & PRIVACY

• All data stored locally on your device
• No cloud servers or external data transmission
• You control your business data
• Regular backup options available

💡 WHY CHOOSE SHOPAFLOW?

Unlike cloud-based POS systems, ShopaFlow works completely offline, ensuring you can always process sales even without internet. No monthly fees, no subscriptions - just a one-time installation.

Perfect for businesses in areas with unreliable internet or those who prefer to keep their business data private and local.

📊 DATA PORTABILITY

• Export all data to CSV
• Easy backup and restore
• Transfer between devices
• Integration-ready data format

Get started with ShopaFlow today and modernize your business operations!
```

## Content Rating Questionnaire Answers

**Does your app contain any of the following?**
- User-generated content: **No**
- User communication: **No**
- Personal information: **No** (stored locally only)
- Location tracking: **No**
- Social features: **No**

**Is your app primarily for children under 13?**
- **No**

**Does your app contain ads?**
- **No**

**Does your app contain in-app purchases?**
- **No**

## Release Notes Template

### Version 1.0.0 (Initial Release)
```
Welcome to ShopaFlow POS System!

✨ Features:
• Complete offline POS functionality
• Product and inventory management
• Bluetooth thermal receipt printing
• Sales tracking and reporting
• Multi-currency support (USD/ZWL)
• Customer database
• CSV data export
• Low stock alerts
• Modern, intuitive interface

This is our first release. We're excited to help streamline your business operations!
```

## Testing Checklist Before Submission

- [ ] Test all features in release mode
- [ ] Verify Bluetooth printer connectivity
- [ ] Test on multiple Android versions (5.0+)
- [ ] Check all permissions work correctly
- [ ] Verify database operations (add, edit, delete)
- [ ] Test CSV export functionality
- [ ] Ensure no crashes during normal operation
- [ ] Verify currency conversion calculations
- [ ] Test print functionality with actual printer
- [ ] Check app behavior with no data
- [ ] Test app behavior with large datasets
- [ ] Verify all navigation flows
- [ ] Test landscape and portrait orientations

## Quick Build Commands

```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Build APK for testing
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Or use the PowerShell script
.\build-release.ps1
```

## Submission Checklist

**Before submitting:**
- [ ] App icon created (1024x1024 PNG in assets/icon/)
- [ ] Icons generated (flutter pub run flutter_launcher_icons)
- [ ] Keystore secure and backed up
- [ ] Privacy policy written and hosted
- [ ] Screenshots captured (2-8 images)
- [ ] Feature graphic created (1024x500)
- [ ] Store listing text ready
- [ ] Release notes written
- [ ] Content rating completed
- [ ] App tested on physical device
- [ ] App bundle built successfully
- [ ] All features working in release mode

**Play Console:**
- [ ] Developer account created ($25)
- [ ] App created in console
- [ ] Store listing completed
- [ ] Content rating submitted
- [ ] Privacy policy URL added
- [ ] App bundle uploaded
- [ ] Release notes added
- [ ] Review submitted

## Common Rejection Reasons to Avoid

1. **Missing Privacy Policy** - Must be hosted and linked
2. **Incomplete Store Listing** - All required fields filled
3. **Low Quality Screenshots** - Use high-res device screenshots
4. **Misleading Description** - Accurately describe features
5. **Missing Permissions Explanation** - Document why Bluetooth is needed
6. **Crashes on Startup** - Test thoroughly in release mode
7. **Target SDK too low** - Must target SDK 33+ (we use 34)

## Support Resources

- **Play Console Help**: https://support.google.com/googleplay/android-developer
- **Flutter Deployment Docs**: https://flutter.dev/docs/deployment/android
- **This Guide**: PLAYSTORE_DEPLOYMENT.md (detailed version)

---

**Quick Contact Info to Include:**
- Developer Email: [your-email]
- Website: [your-website]
- Support: [support-email or link]
