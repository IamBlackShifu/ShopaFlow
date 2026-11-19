# ShopaFlow Admin Dashboard

React/Vite dashboard for managing company stores, inventory, team roles, and reports against the same Firestore structure used by the POS app.

## Setup

The checked-in Firebase web configuration targets the `shopaflow` project. You can override it for another project with `admin-dashboard/.env.local`:

```bash
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
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

Owners/admins can create employees from the Team page without Cloud Functions. The dashboard creates the Auth account through an isolated secondary Firebase app, then atomically writes the company user and membership mirrors with the owner's/admin's session. The primary user stays signed in.

Role assignment is hierarchical:

- owners can create and assign `admin`, `manager`, and `cashier`
- admins can create and assign `manager` and `cashier`
- managers can manage inventory and reports but cannot manage the team
- cashiers use the POS only

Firestore Security Rules enforce these constraints even if someone bypasses the UI. Employee creation requires Email/Password Authentication to be enabled in Firebase Console.

## Build and deploy

From the repository root:

```bash
npm --prefix admin-dashboard ci
npm --prefix admin-dashboard run build
firebase deploy --only firestore:rules,hosting
```

On this Windows workstation, prefer `./tool/deploy-firebase.ps1`; it performs the same build and deployment while placing npm and temporary caches under the D: workspace.

This deploys only static Hosting and Firestore rules. It does not deploy the legacy `functions/` folder and does not require the Blaze plan. The back office URL is `https://shopaflow.web.app`.

Run the RBAC emulator suite from the repository root with:

```powershell
.\tool\test-firestore-rules.ps1
```

The script keeps the emulator download and temporary files under `.firebase/` on the D: workspace, avoiding the full C: drive.
