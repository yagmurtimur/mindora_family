# Mindora Family — Technical Audit and Development Roadmap

Audit date: 2026-11-09  
Scope: repository contents only. Firebase project configuration, deployed rules,
App Store/Play Console settings, production infrastructure, and physical devices
were not available; their live state is therefore unverified.

## Executive status

The repository contains a Flutter client with Firebase Authentication/Firestore,
Android usage-stat access, and dashboard UI. It is **not production-ready**. The
most urgent concern is authorization: roles and parent-child links are decided and
written by the client, while Firestore rules are not versioned in this repository.

The FastAPI service, model/data pipeline, FCM delivery implementation, iOS Screen
Time integration, and backend account-deletion implementation are absent. Their
corresponding UI/data consumers must not be represented as working product
capabilities until the server-side components and device verification exist.

## Audited architecture

| Area | Observed state | Result |
| --- | --- | --- |
| Flutter | Screen-centric code; Firebase calls are embedded in screens. | Functional prototype architecture; authorization and data access are duplicated. |
| Firebase | Auth and Firestore client SDKs configured; `firebase.json` only contains Flutter app configuration. | No deployable Firestore rules/indexes found. |
| Android | `UsageStatsManager`, a MethodChannel, and a Device Admin receiver are present. | Usage reading is partially implemented; consumer-device blocking claims are invalid. |
| iOS | Standard Flutter runner only. | No FamilyControls, DeviceActivity, ManagedSettings, entitlement, extension, or App Group implementation. |
| AI/API | Flutter posts to a local HTTP `/predict` endpoint. | No FastAPI server, model, dataset, evaluation, SHAP code, or API authentication exists. |
| Notifications | Local-notification setup exists. | FCM is declared but has no token lifecycle, handlers, or server sender. |
| Testing | One singleton unit test. | No authorization, repository, API, Android-channel, or integration coverage. |

## Findings

### Critical

| ID | Location / component | Finding and impact | Recommended fix | Verification |
| --- | --- | --- | --- | --- |
| C1 | `lib/screens/auth/role_selection_screen.dart`, `_continue`; absent `firestore.rules` | Any signed-in user can write their own `role` as `parent` or `child`. The app uses this client-controlled field for navigation and access decisions. If deployed rules are permissive or similarly trust it, a child can escalate privileges. | Make role assignment and privileged relationship changes server-mediated (Callable Function/secure API with Admin SDK); deploy deny-by-default Firestore rules using immutable server claims/relationship records. | Emulator tests: child cannot create/update role, parent-only documents, or another user document. |
| C2 | `lib/screens/parent/add_child_screen.dart`, `_addChild`; absent `firestore.rules` | Parent-child linking writes `child.parentId` and `parent.childIds` in two separate client operations. A client can attempt arbitrary links; failed/interrupted writes can leave inconsistent data. Email lookup also exposes whether a child account exists. | Replace with authenticated invitation/acceptance flow and an atomic server transaction. Store canonical relationship documents; validate consent, single-parent policy, and rate limits server-side. | Emulator tests for spoofed UID, duplicate/revoked invite, interruption, and unauthorized read/write. |
| C3 | `lib/screens/parent/app_restrictions_screen.dart`, `_setAppBlocked`; `android/.../MainActivity.kt`, `setAppBlocked` | The UI says ordinary Device Admin can block apps, but `setPackagesSuspended` requires Device Owner/Profile Owner authority. Device Admin activation does not grant it. This is a false control on normal consumer Android devices. | Gate this capability by verified device-management enrollment. For ordinary devices expose monitoring/alerts only; document Android Enterprise/provisioning requirements before offering enforcement. | On physical unmanaged and managed devices, assert displayed capability and actual package state agree. |
| C4 | `lib/config/api_config.dart`; `lib/services/ai_service.dart` | AI calls use cleartext HTTP, default to localhost/`10.0.2.2`, send no Firebase ID token, have no timeout, and accept unvalidated response JSON. Android globally allows cleartext traffic. Sensitive child data can be intercepted or endpoint-spoofed. | Require HTTPS production URL via build configuration; remove cleartext in release; attach/verify Firebase ID tokens; add timeout, schema validation, and safe error mapping. | Network-security test rejects HTTP release traffic; API tests reject missing/invalid/foreign-user tokens. |

### High

| ID | Location / component | Finding and impact | Recommended fix | Verification |
| --- | --- | --- | --- | --- |
| H1 | Root configuration; `firebase.json` | No `firestore.rules`, indexes, Storage rules, or emulator test config is version-controlled. Deployed protection cannot be audited or reliably reproduced. | Add rules, indexes, emulator configuration, CI deployment validation, and documented environment separation. | `firebase emulators:exec` rules suite passes; production rules review is recorded. |
| H2 | `android/app/src/main/AndroidManifest.xml` | `QUERY_ALL_PACKAGES` is highly sensitive and requires Play policy eligibility/justification. `usesCleartextTraffic="true"` exposes all HTTP traffic, not only development AI calls. | Remove broad visibility where possible; use launcher queries/package visibility declarations; eliminate cleartext from release. | Manifest review and Play pre-launch/policy checklist. |
| H3 | `android/.../AppLimitWorker.kt` | Worker is never scheduled (`rg` finds no instantiation). It reads a user-selected `childId` directly from Firestore without proving the device belongs to that child, and assumes Device Owner. Limits therefore do not run and could target the wrong data. | Bind a verified local child/device installation identity, schedule constrained periodic/event work, record enforcement state, and keep enforcement managed-device-only. | Android integration test validates scheduling, identity binding, midnight reset, retry, and unenrollment. |
| H4 | `android/.../MainActivity.kt`, `getTodayUsage` / `hasUsageAccess` | `hasUsageAccess` infers access from non-empty usage stats, which can be false-negative. Usage is read only when foregrounded; stats may be incomplete. Package-name substring categories are unreliable and aggregate broad device usage. | Use `AppOpsManager` for access state; capture documented intervals; retain raw/categorized data with a maintained taxonomy; disclose accuracy limits. | Device matrix tests with no access, granted/no usage, timezone/DST, reboot, and app updates. |
| H5 | `ios/Runner/*`, `ios/Runner.xcodeproj/*` | No iOS Screen Time capability exists. FamilyControls, DeviceActivity monitor extension, ManagedSettings, App Group, authorization flow, and family-controls entitlement are all missing. | Treat iOS control as unsupported until Apple grants the entitlement and the native extensions are implemented. Build a separate approved-capability track. | Xcode entitlement/extension build plus real-device FamilyControls authorization test. |
| H6 | `lib/services/ai_service.dart`; no backend/model files | Flutter assumes an AI endpoint, but no FastAPI API, model artifact, training/evaluation data, SHAP explanations, or deployment configuration exists. Risk results cannot be scientifically or operationally verified. | Define an API contract and build the backend only after data-governance approval. Include held-out evaluation, imbalance strategy, leakage checks, versioning, monitoring, and non-clinical wording. | Contract, authentication, validation, regression, calibration, and explanation tests against a versioned model. |
| H7 | `lib/services/notification_service.dart`; `pubspec.yaml` | Firebase Messaging is a dependency only. There is no permission/token acquisition, token refresh/revocation, foreground/background handling, routing, server sender, or parent-child targeting. | Implement FCM lifecycle with server-authorized token registration and remove stale tokens; keep local notifications for device-local reminders. | Device tests for foreground/background/terminated, token refresh, logout, and unauthorized recipient attempts. |
| H8 | `lib/screens/parent/app_restrictions_screen.dart`, `_loadDailyLimits` / `_chooseDailyLimit` | This parent page reads/writes any supplied `childId` and persists limits directly. Only missing server rules stand between a manipulated client and another child’s controls. | Route all parent actions through canonical relationship authorization; use rules/backend validation and audit logs. | Rules emulator test with unrelated parent, child, and unauthenticated sessions. |
| H9 | `lib/screens/parent/settings_screen.dart`; repository-wide search | There is sign-out but no account/data deletion workflow, retention policy, consent record, or child-data access/export process. | Design legally reviewed lifecycle procedures, server-side cascading deletion/anonymization, and in-app deletion request/status UX. | Staging end-to-end deletion test confirms Auth, Firestore, FCM tokens, backend data, and device links are handled. |

### Medium

| ID | Location / component | Finding and impact | Recommended fix | Verification |
| --- | --- | --- | --- | --- |
| M1 | `lib/screens/parent/*`, `lib/screens/child/*` | Data access, parsing, and authorization assumptions are duplicated across large screens. Most reads are one-off rather than streams; stale dashboard/report values are likely. | Introduce repositories/use-cases and typed models; centralize date/time, parsing, and authorized child selection. | Unit tests for repositories plus widget tests for loading/error/realtime updates. |
| M2 | `lib/screens/parent/goals_screen.dart` and `child_goals_screen.dart` | The files are byte-identical, suggesting duplicate navigation/maintenance paths. | Select one canonical screen, redirect imports/routes, then remove copies only after reference and UI tests. | `rg` reference audit and navigation/widget tests. |
| M3 | Backup source files under `lib/screens/parent/` | Four stale `*.backup.dart` / `*.aurora_backup.dart` / `*.before_modern.dart` files are analyzed, duplicate production code, and contribute many diagnostics. | Move vetted historical snapshots out of `lib` or delete only after a checkpoint and user approval. | `flutter analyze` no longer scans backups; app builds from canonical files. |
| M4 | `lib/screens/parent/ai_analysis_screen.dart`; dashboards/recommendations | UI derives and stores risk values in Firestore but no unified unit convention is enforced (some code handles 0–1, other code displays 0–100). Recommendations use categorical language without a model provenance/explanation. | Define a versioned analysis schema, probability scale, model metadata, confidence/limitations, and non-diagnostic copy. | Schema validation and UI fixtures for boundary values. |
| M5 | `android/app/build.gradle.kts`, release build | Release is explicitly signed with the debug signing config. This is not publishable and weakens release identity. | Configure secure release signing through CI/keystore secrets after approval; never commit secrets. | `bundleRelease` signed with a non-debug certificate and verified by `apksigner`. |
| M6 | `lib/services/notification_service.dart` | Notification initialization immediately requests permissions during app startup, before explaining value/context. No deep-link action handling is set. | Use contextual opt-in screens; add notification action routing and platform-specific permission state. | Device tests on fresh install, denial, re-enable, and notification tap. |
| M7 | `lib/screens/child/usage_screen.dart`, `_syncRealUsageData` | Child-device usage is written to Firestore by the child client, so it can be forged and is not reliable evidence for controls or AI. | Mark client telemetry as untrusted; bind to device identity/attestation where appropriate and validate server-side. | Tampered-client/rules tests demonstrate rejection or clear trust labeling. |

### Low

| ID | Location / component | Finding and impact | Recommended fix | Verification |
| --- | --- | --- | --- | --- |
| L1 | `flutter analyze` (2026-11-09) | Analyzer reports 133 issues: unused fields/imports, deprecated UI APIs, style diagnostics, and extensive diagnostics in backup sources. Build has no analyzer errors, but maintenance signal is poor. | Remove/archive backups, then address current-source diagnostics in small changes. | `flutter analyze` is clean or has approved baseline only. |
| L2 | `test/notification_service_test.dart` | The only test asserts singleton identity; it does not exercise notification/platform behavior or product flows. | Add service, rules, repository, widget, integration, and native channel test layers. | CI runs all layers with coverage thresholds appropriate to risk. |
| L3 | `README.md`; `pubspec.yaml` | README is scaffold-level and the pubspec description is generic; production setup, limitations, privacy, and developer workflows are undocumented. | Document architecture, environment setup, platform capability matrix, and release runbook. | New contributor setup succeeds from documentation. |

## Platform capability boundary

Android `UsageStatsManager` can report usage only after the user grants Usage Access.
It does not enforce limits. `DevicePolicyManager.setPackagesSuspended` is suitable
only when Mindora is the Device Owner/Profile Owner, which ordinary app installs
cannot become without managed-device provisioning. Do not market routine
consumer-device app blocking from the existing implementation.

iOS app management must use Apple Screen Time frameworks and Apple-granted
Family Controls entitlement. The current project includes none of those pieces;
ordinary iOS apps cannot enumerate/block arbitrary apps through Flutter alone.

## Delivery roadmap

Each task is intentionally small and independently verifiable. Do not begin a
task marked **approval required** without the indicated decision/checkpoint.

### 0. Establish a safe baseline

1. **[High] R0.1 — Create a Git checkpoint and CI baseline.** Record current
   `flutter analyze` (133 issues) and `flutter test` (1 passing test); add no
   product changes. Verification: clean working tree checkpoint and CI artifacts.
2. **[High] R0.2 — Document a capability/privacy matrix.** Explicitly distinguish
   Android monitoring vs managed-device enforcement and unsupported iOS control.
   Verification: product and legal review. Dependency: R0.1.
3. **[Medium] R0.3 — Quarantine duplicate backup source files.** **Approval
   required (file removal/move).** Confirm canonical screens, checkpoint, then
   move/archive them outside `lib` or delete them. Verification: analyzer scope
   and navigation tests. Dependency: R0.1.

### 1. Secure identity and Firebase data boundaries

4. **[Critical] R1.1 — Define canonical Firestore schema and relationship model.**
   Use a relationship/invitation document, server timestamps, ownership, status,
   and device-installation records; document field-level mutability. Verification:
   schema review with examples. Dependency: R0.2.
5. **[Critical] R1.2 — Add versioned Firestore rules, indexes, emulators, and rules
   tests.** Default deny; authorize parent access only through accepted canonical
   links; children only write explicitly permitted self telemetry. Verification:
   automated role/relationship matrix. Dependency: R1.1.
6. **[Critical] R1.3 — Move role assignment and link/unlink flows server-side.**
   **Approval required (Firebase production/server security change).** Implement
   Callable Functions or an authenticated FastAPI service with Admin SDK,
   invitation acceptance, transactions, audit events, and anti-enumeration.
   Verification: emulator/API integration tests. Dependency: R1.2.
7. **[High] R1.4 — Refactor Flutter to typed repositories.** Replace screen-level
   privileged writes and duplicated authorization checks with the secure APIs and
   typed reads. Verification: unit/widget tests. Dependency: R1.3.
8. **[High] R1.5 — Implement data lifecycle.** **Approval required (privacy/legal
   policy).** Add consent, deletion/export requests, retention, and backend data
   cleanup. Verification: staging deletion test. Dependency: R1.1, R1.3.

### 2. Android: truthful monitoring and managed enforcement

9. **[High] R2.1 — Correct usage-permission and telemetry collection.** Implement
   `AppOpsManager` access checks, timezone-safe intervals, error states, and a
   documented taxonomy. Verification: physical-device matrix. Dependency: R1.4.
10. **[Critical] R2.2 — Split monitoring from enforcement.** Hide/disable blocking
    unless verified managed enrollment exists; remove Device Admin wording that
    promises blocking. Verification: unmanaged device cannot show success.
    Dependency: R0.2.
11. **[High] R2.3 — Design device enrollment and sync.** Server-register a child
    device with explicit authorization, bind limits to it, then implement worker
    scheduling, health/last-sync, and remote changes. Verification: managed-device
    end-to-end test. Dependency: R1.3, R2.2.
12. **[High] R2.4 — Minimize permissions and harden networking.** Remove global
    cleartext release traffic and justify/minimize package visibility. Verification:
    release manifest and Play policy review. Dependency: R2.1.

### 3. iOS feasibility track

13. **[High] R3.1 — Obtain and validate Apple Family Controls entitlement.**
    **Approval/external authority required.** Do not promise enforcement until
    granted. Verification: entitlement appears in provisioning profile.
14. **[High] R3.2 — Build Screen Time extensions.** Add FamilyControls
    authorization and picker, DeviceActivity monitor/report extensions,
    ManagedSettings shield store, App Group, and secure Flutter bridge.
    Verification: real device/family configuration tests. Dependency: R3.1,
    R1.3.

### 4. AI/API and notifications

15. **[High] R4.1 — Specify a privacy-reviewed AI contract.** Define data
    minimization, consent, authenticated identity, schema, rate limits, and
    non-clinical disclosures. Verification: threat model + API contract review.
    Dependency: R1.3, R1.5.
16. **[High] R4.2 — Build or import the FastAPI/model service.** **Approval
    required (new backend/dependency deployment).** Include Pydantic validation,
    Firebase token verification, HTTPS, timeouts, model versioning, evaluation,
    calibration, leakage/imbalance assessment, SHAP safeguards, and audit logs.
    Verification: reproducible model/API test suite. Dependency: R4.1.
17. **[Medium] R4.3 — Integrate typed AI results in Flutter.** Remove localhost
    default for release, validate responses, show provenance/limitations, and
    standardize probability values. Verification: API contract/widget tests.
    Dependency: R4.2.
18. **[High] R4.4 — Implement FCM end-to-end.** Secure token registration,
    parent-child targeting through backend authorization, foreground/background
    handlers, stale-token cleanup, and report/limit/goal triggers. Verification:
    multi-device delivery and authorization tests. Dependency: R1.3.

### 5. Quality and release

19. **[Medium] R5.1 — Add tests per risk.** Rules emulator tests, repositories,
    widgets, FastAPI contracts, Android MethodChannel/managed-device integration,
    and iOS device tests where available. Verification: CI-required checks.
    Dependency: R1–R4 work.
20. **[Medium] R5.2 — Resolve analyzer diagnostics and code duplication.** Clean
    current-source warnings after R0.3; modernize deprecated APIs. Verification:
    `flutter analyze` clean. Dependency: R0.3.
21. **[High] R5.3 — Production release hardening.** **Approval required (signing,
    Firebase/API production changes).** Configure non-debug Android signing,
    iOS signing/provisioning, HTTPS/production environment, crash reporting,
    privacy policy, account deletion, Play declarations, and Apple review
    materials. Verification: signed release build and store compliance checklist.
    Dependency: R1–R5.2.

## Validation record

- `flutter analyze` executed on 2026-11-09: completed with **133 issues**, no
  analyzer errors. Many findings are from duplicate backup source files; current
  sources also contain warnings/deprecations.
- `flutter test` executed on 2026-11-09: **1 test passed** (`NotificationService`
  singleton only).
- No Firebase emulator, FastAPI, Android device, iOS device, FCM delivery, or
  store-submission verification was possible because the required implementation
  or external configuration is absent from the repository.
