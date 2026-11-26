# ShopaFlow

ShopaFlow is an offline-capable mobile point-of-sale (POS) app for shops, bars, and wholesalers, with a web dashboard for store administration. The Flutter app keeps operational data locally and can sync changes to Firebase when online.

## Features

- Create sales and manage products, customers, and inventory from the POS app.
- View sales, inventory, and financial reports.
- Continue using an existing signed-in session while offline; queued changes can sync when connectivity returns.
- Print receipts on Bluetooth ESC/POS printers or supported Sunmi built-in printers, with PDF printing as a fallback.
- Import and export product data as CSV and export a local data backup.
- Manage stores, inventory, team roles, and reports from the role-based React admin dashboard.

## Requirements

- Flutter 3.10 or later and Dart 3.0 or later.
- Android Studio or another Flutter-supported development setup for your target platform.
- Node.js and npm if you want to run the admin dashboard.

## Run the mobile app

From the repository root:

```bash
flutter pub get
flutter run
```

Firebase Authentication is required for sign-in and registration. The app can be opened before Firebase is configured, but offline access is available only to a session that was already signed in. The checked-in Firebase configuration targets the `shopaflow` project; to configure another Firebase project, follow [Firebase setup](FIREBASE_SETUP.md).

## Run the admin dashboard

From the repository root:

```bash
npm --prefix admin-dashboard ci
npm --prefix admin-dashboard run dev
```

The development server prints the local URL to open in your browser. The dashboard uses the Firebase project configuration described in [the admin dashboard README](admin-dashboard/README.md); see that guide for environment overrides and role permissions.

## Tests

Run Flutter tests from the repository root:

```bash
flutter test
```

The admin dashboard's Firestore rules test and build instructions are documented in [admin-dashboard/README.md](admin-dashboard/README.md).

## Documentation

- [Firebase setup](FIREBASE_SETUP.md)
- [Admin dashboard setup and deployment](admin-dashboard/README.md)
- [Printer integration guide](PRINTER_INTEGRATION_GUIDE.md)
- [Play Store deployment](PLAYSTORE_DEPLOYMENT.md)
- [Implementation roadmap](IMPLEMENTATION_ROADMAP.md)