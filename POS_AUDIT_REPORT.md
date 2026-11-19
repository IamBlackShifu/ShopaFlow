# ShopaFlow POS Audit Report

Audit date: 2026-06-15

## Scope

This audit reviewed the full visible repository: Flutter POS app, local SQLite service, Firebase sync, Firestore rules, Cloud Functions, Vite admin dashboard, Android kiosk/printing integration, docs, and tests. Generated/build outputs and dependency caches were excluded from source review.

## Executive Summary

ShopaFlow has a strong foundation for an offline-first POS: local SQLite, queued Firebase sync, tenant-scoped data, role-aware navigation, product/sale/customer tables, receipt printing, and an admin dashboard. The main production risks are in POS correctness and release hardening:

- Sales can oversell stock because the final stock decrement does not enforce stock availability inside the database transaction.
- Release signing contains hard-coded fallback passwords.
- Offline authentication stores an unsalted SHA-256 password hash in shared preferences.
- Firestore rules authorize by role but do not validate document invariants, totals, ownership fields, or immutable fields.
- Sync is last-writer-wins with no conflict resolution, idempotency guard, or server-side sale/stock validation.
- Automated test coverage is essentially a single smoke test, and static/test verification timed out in this environment.

## Critical Findings

### 1. Stock Can Go Negative During Checkout

Evidence: [lib/services/db_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/db_service.dart:800), [lib/services/db_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/db_service.dart:851), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:2176)

The checkout UI checks stock while adding items to the cart, but `DatabaseService.addSale` only subtracts stock with:

```sql
UPDATE products SET stock_quantity = stock_quantity - ?
```

There is no `stock_quantity >= ?` guard and no check that exactly one row was updated. If stock changes after the cart is built, if a stale local cart is used, or if remote sync pulls a lower stock value, the database can record a sale and push stock below zero.

Recommended fix:

- In the same transaction, fetch current stock for each product and fail the sale if quantity exceeds stock.
- Or update with `... AND stock_quantity >= ?`, then verify `updated == 1`.
- Add tests for exact-stock sale, oversell prevention, deleted product, and concurrent/stale cart cases.

### 2. Release Signing Uses Hard-Coded Default Passwords

Evidence: [android/app/build.gradle.kts](D:/DELL/Documents/Experiments/ShopaFlow/android/app/build.gradle.kts:38), [android/app/build.gradle.kts](D:/DELL/Documents/Experiments/ShopaFlow/android/app/build.gradle.kts:40)

The release signing config falls back to `shopaflow123` for both key and store passwords. If the checked-in keystore exists or leaks, release signing can be compromised.

Recommended fix:

- Remove fallback passwords.
- Fail release builds when `KEY_PASSWORD` or `STORE_PASSWORD` is missing.
- Ensure keystores are ignored and stored outside the repo or in CI secrets.

### 3. Offline Password Fallback Is Weak

Evidence: [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:133), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:170), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:405)

When Firebase is unavailable, the app stores an unsalted SHA-256 hash in shared preferences. Shared preferences are not a secure credential store, and unsalted SHA-256 is fast to brute-force.

Recommended fix:

- Prefer Firebase/Auth state plus secure token/session storage.
- If an offline unlock is required, use platform secure storage and a slow password KDF such as Argon2id, scrypt, PBKDF2, or OS-backed biometric/PIN APIs.
- Separate "device unlock" from account password so Firebase credentials are not mirrored locally.

## High Findings

### 4. Firestore Rules Do Not Validate Business Invariants

Evidence: [firestore.rules](D:/DELL/Documents/Experiments/ShopaFlow/firestore.rules:96), [firestore.rules](D:/DELL/Documents/Experiments/ShopaFlow/firestore.rules:109), [firestore.rules](D:/DELL/Documents/Experiments/ShopaFlow/firestore.rules:115), [firestore.rules](D:/DELL/Documents/Experiments/ShopaFlow/firestore.rules:121)

Rules limit access by company role, which is good, but they allow clients to create sales, sale items, inventory movements, and product changes without schema validation. A cashier can write arbitrary totals, quantities, product references, timestamps, and store IDs if the client is modified.

Recommended fix:

- Add rule helpers that require `company_id == companyId`, valid `store_id`, immutable `created_by`, allowed fields only, non-negative numeric values, and sane timestamps.
- Consider moving sale finalization to a callable Cloud Function that validates product stock, calculates totals server-side, writes sale/sale_items/inventory movements atomically, and rejects invalid writes.

### 5. Sync Has No Conflict Strategy For Stock Or Products

Evidence: [lib/services/firebase_sync_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/firebase_sync_service.dart:46), [lib/services/firebase_sync_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/firebase_sync_service.dart:173), [lib/services/db_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/db_service.dart:1090)

The sync queue pushes local rows with `set(..., merge: true)` and pulls remote rows into SQLite by `sync_id`. This is straightforward, but it is last-writer-wins. There is a `version` field locally, yet no visible conflict check uses it.

Recommended fix:

- Define conflict policy per entity. Sales should be append-only/idempotent; products may be last-writer-wins with version checks; stock should be movement-led or server-aggregated.
- Make sale sync idempotent by `sync_id` and avoid replaying inventory movements.
- Store and compare `updated_at`/`version`/device ID to surface conflicts.

### 6. Destructive Import/Clear Can Wipe Local Store Data And Sync Queue

Evidence: [lib/services/db_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/db_service.dart:1147), [lib/services/db_service.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/services/db_service.dart:1191), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:2969)

`importData` deletes products, customers, sales, sale items, inventory movements, and the company sync queue before inserting imported data. `clearAllData` also deletes store-scoped operational data. This is useful for reset/restore, but risky in a POS if backups are stale or pending sync exists.

Recommended fix:

- Block import/clear while pending sync exists unless the user explicitly discards it.
- Create a local backup before destructive restore.
- Add role-gated confirmation that includes company/store name and record counts.

## Medium Findings

### 7. Main App File Is Too Large For Safe Evolution

Evidence: [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:1)

`main.dart` is about 157 KB and contains models, auth, setup, shell navigation, checkout, products, reports, settings, dialogs, and exports. This makes POS-critical changes harder to review and test.

Recommended fix:

- Extract checkout, products, reports, auth/session, setup, and shared widgets into focused files.
- Move business calculations to pure Dart services that can be tested without Flutter widgets.

### 8. Receipt Printing Errors Are Silently Ignored

Evidence: [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:1953), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:2212)

The sale is intentionally saved even if printing fails, which is the right POS default. However, the failure is swallowed, so cashiers get no clear retry/reprint path from the sale they just completed.

Recommended fix:

- Surface a non-blocking "sale saved, print failed" message.
- Store print status and allow reprint from transaction history.

### 9. Text Encoding Artifacts Are Visible In The POS UI

Evidence: [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:2318), [lib/main.dart](D:/DELL/Documents/Experiments/ShopaFlow/lib/main.dart:2378)

Several strings contain `â€¢` instead of a bullet separator. This will look broken in product lists and the cart bar.

Recommended fix:

- Replace mojibake with ASCII separators or valid UTF-8 bullets.
- Add a quick visual smoke pass on Android after replacement.

### 10. Admin Dashboard Can Create Workspaces Client-Side

Evidence: [admin-dashboard/src/App.tsx](D:/DELL/Documents/Experiments/ShopaFlow/admin-dashboard/src/App.tsx:111), [firestore.rules](D:/DELL/Documents/Experiments/ShopaFlow/firestore.rules:45)

The dashboard registration path creates the owner account, company, store, user, and membership directly from the client. The rules attempt to constrain owner creation, but client-side workspace bootstrapping is still a broad trust surface.

Recommended fix:

- Move company creation into a callable Cloud Function.
- Validate required fields and create company/user/membership records as one server-side workflow.

## Strengths

- SQLite writes for sales and stock changes use a transaction.
- Firestore data is nested by company, with role-aware rules rather than an open database.
- Local IDs and cloud `sync_id` are separated, which is helpful for offline-first sync.
- The admin dashboard filters by company and hides cashier access.
- Printer abstraction supports Bluetooth and Sunmi, with PDF fallback.
- Android kiosk mode support is present for managed deployments.

## Test And Verification Notes

- `git -C D:\DELL\Documents\Experiments\ShopaFlow status --short` was blocked by Git dubious-ownership protection because the sandbox user differs from the repo owner.
- `flutter analyze D:\DELL\Documents\Experiments\ShopaFlow` timed out after 120s.
- `flutter test D:\DELL\Documents\Experiments\ShopaFlow` timed out after 120s.
- `flutter analyze --no-pub D:\DELL\Documents\Experiments\ShopaFlow` timed out after 180s.
- `flutter test --no-pub D:\DELL\Documents\Experiments\ShopaFlow\test\widget_test.dart` timed out after 180s.
- Dart/Java worker processes left by the timed-out Flutter commands were stopped afterward.

Current test coverage is limited to [test/widget_test.dart](D:/DELL/Documents/Experiments/ShopaFlow/test/widget_test.dart:8), which only checks that the splash screen renders.

## Recommended Priority Plan

1. Fix checkout stock enforcement in `DatabaseService.addSale` and add database tests around oversell prevention.
2. Remove hard-coded release signing password fallbacks.
3. Replace offline password storage with secure local unlock or remove the fallback path.
4. Move sale finalization and/or stock validation server-side before relying on multi-device sync.
5. Strengthen Firestore rules with schema and invariant validation.
6. Add POS-critical tests: sale totals, stock decrement, sync queue entries, import/clear safeguards, RBAC visibility, and receipt failure behavior.
7. Split `main.dart` into focused modules so future changes are reviewable.
