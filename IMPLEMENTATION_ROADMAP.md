# ShopaFlow Implementation Roadmap

Created: 2026-06-15  
Source: `POS_AUDIT_REPORT.md`

## Goal

Move ShopaFlow from a promising offline-first POS into a safer production-ready system by prioritizing money/stock correctness, release security, data integrity, and test coverage before larger refactors.

## Priority Levels

- P0: Fix before the next production release.
- P1: Fix before scaling to multiple devices/stores.
- P2: Improve maintainability and operator experience after core risks are controlled.

## Phase 1: P0 POS Correctness And Release Safety

### 1. Prevent Negative Stock At Checkout

Status: Implementation complete on 2026-06-15. Automated database tests are still pending because Dart/Flutter verification tooling timed out during the audit and again during implementation.

Files:

- `lib/services/db_service.dart`
- `lib/main.dart`
- New focused database tests under `test/`

Tasks:

- Update `DatabaseService.addSale` so each sale item checks current stock inside the same SQLite transaction.
- Reject the entire sale if any product is missing, deleted, outside the active store, or has insufficient stock.
- Use either a guarded update such as `stock_quantity >= ?` plus `updated == 1`, or an explicit row read followed by validation and update.
- Return or throw a clear domain error that checkout can show to the cashier.
- Refresh product/cart state after a rejected sale.

Acceptance checks:

- Done: Sale item quantities are validated inside `DatabaseService.addSale`.
- Done: Missing, deleted, or wrong-store products reject the sale inside the SQLite transaction.
- Done: Stock decrement is guarded by current `stock_quantity` inside the transaction.
- Done: Checkout catches insufficient stock, refreshes products, and keeps the cart visible.
- Pending verification: Add and run database tests for exact-stock success, oversell rollback, deleted product rejection, and wrong-store rejection.

### 2. Remove Hard-Coded Release Signing Defaults

Status: Complete on 2026-06-15.

Files:

- `android/app/build.gradle.kts`
- `.gitignore`
- Play Store/release docs as needed

Tasks:

- Remove `shopaflow123` fallback values for `keyPassword` and `storePassword`.
- Fail release builds when signing secrets are absent.
- Confirm keystore files are not tracked and are covered by `.gitignore`.
- Document required environment variables for release builds.

Acceptance checks:

- Done: Debug builds can configure without release signing secrets.
- Done: Release task graph fails with an explicit missing-env message when release signing secrets are absent.
- Done: `KEY_ALIAS`, `KEY_PASSWORD`, and `STORE_PASSWORD` are the required release signing inputs.
- Done: Raw keystore extensions are ignored by `.gitignore`.
- Done: Play Store deployment docs no longer recommend a shared sample keystore password and now describe signing env vars as required.
- Pending verification: Run a release build in an environment with signing secrets.

### 3. Replace Weak Offline Password Storage

Status: Complete on 2026-06-15.

Files:

- `lib/main.dart`
- `pubspec.yaml` if adding secure storage/KDF dependency

Tasks:

- Decide whether offline account-password login is required.
- If not required, remove the stored password hash fallback and rely on Firebase session state.
- If required, implement a separate local device unlock using secure storage and a slow KDF or OS-backed unlock.
- Avoid storing Firebase account password equivalents in shared preferences.

Acceptance checks:

- Done: The unsalted SHA-256 account-password fallback was removed.
- Done: The legacy `auth_password` shared-preferences key is deleted during load, login, registration, and logout.
- Done: New login and company registration now require Firebase to be configured.
- Done: Offline behavior is explicit: only an existing signed-in session can continue offline.
- Pending verification: Add auth/session tests once the test harness is stable.

## Phase 2: P1 Cloud Data Integrity

### 4. Strengthen Firestore Rules

Files:

- `firestore.rules`
- New Firestore rules tests if emulator testing is added

Tasks:

- Add allowed-field checks for products, customers, sales, sale items, inventory movements, users, stores, and memberships.
- Require `company_id == companyId` for company-scoped documents.
- Validate non-negative price, cost, quantity, stock, totals, and minimum stock values.
- Prevent clients from mutating immutable ownership fields such as `created_by`, `company_id`, `owner_user_id`, and role elevation fields outside approved paths.
- Require valid role transitions for team management.

Acceptance checks:

- Cashiers cannot forge totals, write to another company/store, or elevate roles.
- Managers can manage inventory but cannot create admins.
- Owners/admins retain expected management access.
- Invalid schemas are denied by rules.

### 5. Move Sale Finalization Toward Server-Side Validation

Files:

- `functions/index.js`
- `lib/services/firebase_sync_service.dart`
- `lib/services/db_service.dart`
- Checkout flow in `lib/main.dart`

Tasks:

- Design a callable `finalizeSale` function for online sales or sync validation.
- Calculate totals server-side from product data where possible.
- Validate product references, store membership, stock, and role.
- Write sale, sale items, and inventory movements atomically in Firestore.
- Define offline behavior: local sale remains possible, but sync must be idempotent and conflict-aware.

Acceptance checks:

- Online finalized sales cannot be forged by a modified client.
- Re-sending the same sale `sync_id` does not duplicate inventory movement.
- Server rejects insufficient stock when online.
- Offline sales have a documented reconciliation path.

### 6. Define Sync Conflict And Idempotency Policy

Files:

- `lib/services/firebase_sync_service.dart`
- `lib/services/db_service.dart`
- Possibly `functions/index.js`

Tasks:

- Document conflict policy per entity:
  - Sales: append-only and idempotent by `sync_id`.
  - Sale items: tied to sale idempotency.
  - Inventory movements: append-only/idempotent.
  - Products/customers: versioned or last-writer-wins with visible conflict metadata.
- Use `version`, `updated_at`, and device/user metadata consistently.
- Avoid replaying inventory movements when sync retries happen.
- Surface failed/conflicted sync items in the UI.

Acceptance checks:

- Retrying sync does not duplicate sales or stock movements.
- Conflicting product edits are detectable.
- Failed sync entries include actionable errors and can be retried safely.

## Phase 3: P1 Data Recovery And Operational Safety

### 7. Guard Destructive Import And Clear Actions

Files:

- `lib/services/db_service.dart`
- Settings/import/export UI in `lib/main.dart`

Tasks:

- Block import/clear when pending sync exists unless the user explicitly discards pending changes.
- Show company name, store name, pending sync count, and affected record counts before destructive actions.
- Create a local backup before import or clear.
- Add role checks at the service boundary, not only the UI boundary.

Acceptance checks:

- Import/clear cannot silently erase unsynced data.
- A backup file is produced before destructive restore/reset.
- Non-admin roles cannot trigger destructive data operations.

### 8. Improve Receipt Failure Handling

Files:

- `lib/main.dart`
- Printer services under `lib/services/`
- Reports/transaction history UI

Tasks:

- Return print success/failure from `_printReceipt`.
- Show "sale saved, print failed" with retry option.
- Add reprint action from recent transactions.
- Consider storing `print_status` or print attempts with each sale.

Acceptance checks:

- Failed printer does not block sale save.
- Cashier sees a clear message and can reprint.
- Reprint uses the saved sale and sale items.

## Phase 4: P1 Test Foundation

### 9. Add POS-Critical Automated Tests

Files:

- `test/`
- Potential test helpers for SQLite and Firebase sync

Tasks:

- Add database tests for product CRUD, sale creation, stock decrement, oversell rejection, sale item creation, inventory movement creation, and sync queue creation.
- Add sync tests for queue ordering, retry handling, idempotency assumptions, and remote upsert behavior.
- Add widget tests for checkout success/failure and RBAC-visible navigation.
- Add import/clear safeguard tests.

Acceptance checks:

- Tests fail against the current oversell behavior and pass after the fix.
- Tests can run without network access.
- CI or local verification command is documented.

### 10. Restore Reliable Verification Commands

Files:

- Project docs
- CI config if available

Tasks:

- Investigate why `flutter analyze` and `flutter test` timed out in the audit environment.
- Add a known-good verification command set.
- Keep generated outputs and long-running daemons out of routine checks.

Acceptance checks:

- `flutter analyze` completes.
- `flutter test` completes.
- The commands are documented for local and CI use.

## Phase 5: P2 Maintainability And UX Polish

### 11. Split `main.dart` Into Focused Modules

Files:

- `lib/main.dart`
- New files under `lib/models/`, `lib/screens/`, `lib/widgets/`, and `lib/services/`

Tasks:

- Extract auth/session model.
- Extract checkout screen and payment dialog.
- Extract products, reports, settings, setup, and shared widgets.
- Move pure calculations into testable Dart helpers.
- Keep behavior unchanged during extraction.

Acceptance checks:

- No user-visible behavior changes.
- Existing tests still pass after each extraction.
- POS-critical logic can be unit tested without pumping the whole app.

### 12. Fix Text Encoding Artifacts

Files:

- `lib/main.dart`
- Any other UI files found by search

Tasks:

- Replace mojibake strings such as `â€¢`/`Ã¢â‚¬Â¢` with ASCII separators or valid UTF-8.
- Search the repo for similar encoding artifacts.
- Run a quick UI smoke check on checkout/product list screens.

Acceptance checks:

- No visible mojibake remains in product list, cart, or reports.
- Text renders cleanly on Android.

### 13. Move Admin Workspace Creation Server-Side

Files:

- `admin-dashboard/src/App.tsx`
- `functions/index.js`
- `firestore.rules`

Tasks:

- Add callable function to create company workspace.
- Move owner/company/store/user/membership creation out of direct dashboard writes.
- Keep dashboard registration UI, but call the function.
- Tighten rules after the client no longer needs broad bootstrap writes.

Acceptance checks:

- New company registration works through the function.
- Direct invalid client writes are denied.
- Membership mirrors are created consistently.

## Suggested Execution Order

1. P0 stock enforcement and tests.
2. P0 signing secret removal.
3. P0 offline password cleanup.
4. P1 Firestore schema/invariant rules.
5. P1 sync idempotency policy and sale reconciliation.
6. P1 import/clear safeguards.
7. P1 receipt failure and reprint workflow.
8. P1 test suite and verification stability.
9. P2 module extraction.
10. P2 encoding cleanup.
11. P2 server-side workspace creation.

## Definition Of Done For A Release Candidate

- No known path allows a sale to create negative stock without explicit manager override.
- Release signing secrets are not present in source and builds fail safely without them.
- No account password equivalent is stored in shared preferences.
- Firestore rules reject malformed or cross-company writes.
- Sync retries are idempotent for sales and inventory movements.
- Import/clear actions protect pending sync and create backups.
- POS-critical tests pass locally.
- `flutter analyze` and `flutter test` complete reliably.
