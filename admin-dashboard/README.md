# ShopaFlow Admin Dashboard

React/Vite dashboard for managing company stores, inventory, team roles, and reports against the same Firestore structure used by the POS app.

## Setup

Create `admin-dashboard/.env.local` with your Firebase web app config:

```bash
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_FIREBASE_FUNCTIONS_REGION=us-central1
```

Then run:

```bash
npm install
npm run dev
```

Access is role based:

- `owner`, `admin`: stores, inventory, team, reports
- `manager`: inventory and reports
- `cashier`: POS app only

## Registering Companies And Employees

The dashboard sign-in screen has a **Register** mode for creating a new company. The created account is written as the company `owner`.

Owners/admins can create employees from the Team page. Employee creation uses the Firebase callable function `createEmployee`, so deploy functions before using it:

```bash
cd ../functions
npm install
firebase deploy --only functions
```

For local callable testing, run the Functions emulator and add these to `.env.local`:

```bash
VITE_USE_FIREBASE_EMULATORS=true
VITE_FUNCTIONS_EMULATOR_HOST=127.0.0.1
VITE_FUNCTIONS_EMULATOR_PORT=5001
```

Then start emulators from the repo root:

```bash
firebase emulators:start --only functions
```

Deploy Firestore rules too:

```bash
firebase deploy --only firestore:rules
```
