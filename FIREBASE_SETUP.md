# ShopaFlow Firebase Setup

Firebase project: `shopaflow`

Android package name used by this app: `com.shopaflow.pos`

## 1. Install CLI tools

Install Node.js first if `npm` is not available.

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Make sure the Dart global pub cache is on your PATH. On Windows this is usually:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

## 2. Login and select the Firebase project

```powershell
firebase login
firebase use --add
```

Choose the existing `shopaflow` Firebase project.

## 3. Configure FlutterFire

Run this from the ShopaFlow project root:

```powershell
flutterfire configure --project=shopaflow --android-package-name=com.shopaflow.pos
```

This should generate `lib/firebase_options.dart` and register the Android app in Firebase if needed.

## 4. Update `main.dart` after FlutterFire generates options

Change the Firebase initialization from:

```dart
await Firebase.initializeApp();
```

to:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

and add:

```dart
import 'firebase_options.dart';
```

## 5. Enable Firebase services

In the Firebase console:

- Authentication: enable Email/Password sign-in.
- Firestore Database: create a database.
- Storage: enable when product images or backups are needed.
- Hosting: used for the static React back office.
- Functions: not required for the current employee flow. Keeping Functions out of the deployment avoids requiring Blaze.

## 6. Build and deploy the back office and rules

This repo includes `firestore.rules` and `firebase.json`.

```powershell
npm --prefix admin-dashboard ci
npm --prefix admin-dashboard run build
firebase deploy --only firestore:rules,hosting
```

The deployed back office is `https://shopaflow.web.app`. The POS app links owners, admins, and managers to this URL. To use a different Hosting site in a Flutter build, pass `--dart-define=BACK_OFFICE_URL=https://your-site.example`.

## 7. Resolve packages

After the local Flutter toolchain stops hanging, run:

```powershell
flutter pub get
```

Then test:

```powershell
flutter run
```

## Notes

The app can still open before Firebase is configured, but sign-in and registration require Firebase. Once initialized, registration and login use Firebase Authentication, and the sync button can upload queued local changes to Firestore.
