# Mindora Family — Capability and Privacy Matrix

Assessment date: 2026-11-09
Scope: source code and tracked configuration in this repository. Deployed Firebase
rules/configuration, real devices, Apple entitlement approval, store consoles, and
remote backend infrastructure were not available and are therefore **unverified**.

## Status legend

| Status | Meaning |
| --- | --- |
| **Implemented** | Code for the capability exists in this repository. It is not a claim of device, deployment, or policy validation. |
| **Partially implemented** | A code path exists but has a material functional, security, or platform dependency gap. |
| **UI-only / configuration-only** | UI, dependency, or configuration exists without the required end-to-end implementation. |
| **Not implemented** | No relevant implementation was found in the repository. |
| **Unverified** | Requires external state that cannot be proven from the repository. |

## Executive capability matrix

| Capability | Current status | Evidence | Boundary / missing requirement |
| --- | --- | --- | --- |
| Android same-device daily screen-time collection | **Partially implemented** | `MainActivity.getTodayUsage`; `ChildUsageScreen._syncRealUsageData` | Requires user-granted Usage Access; access check is unreliable and collection runs only when the app invokes it. No physical-device validation. |
| Android installed-app listing | **Implemented, policy-unverified** | `MainActivity.getInstalledApps`; `QUERY_ALL_PACKAGES` manifest permission | Returns launcher activities; broad package visibility requires Play-policy eligibility/justification. |
| Android app suspension/blocking | **UI-only / unsafe for ordinary devices** | `AppRestrictionsScreen._setAppBlocked`; `MainActivity.setAppBlocked` | API requires Device Owner/Profile Owner or an appropriately delegated app; Device Admin is insufficient. No enrollment exists. |
| Android daily-limit enforcement | **Not operational** | `AppLimitWorker` | Worker is never scheduled and requires Device Owner. There is no verified device/child binding. |
| iOS parental controls / usage | **Not implemented** | iOS target inspection and framework search | Requires Family Controls entitlement, authorization, Screen Time extensions, and native implementation. |
| Firebase Auth + Firestore client operations | **Implemented client-side, security-unverified** | Auth screens and Firestore calls throughout `lib/screens/` | No deployable Firestore rules, indexes, emulator configuration, or server-side authorization is tracked. |
| AI prediction | **Partially integrated client-side, non-functional from repository evidence** | `AiService.predict`; `ParentAiAnalysisScreen` | Flutter POST exists, but no FastAPI/model/dataset/deployment is present; endpoint defaults to local cleartext HTTP and is unauthenticated. |
| Local notifications | **Implemented for on-device test notifications** | `NotificationService`; `SplashScreen._sendTestNotification` | Permission flow and local channel exist, but no production trigger/routing design is shown. |
| Firebase Cloud Messaging | **Not implemented end-to-end** | `firebase_messaging` dependency only | No token handling, background handler, foreground handling, sender, or recipient authorization. |

## 1. Android screen-time monitoring

### What source code implements

| Item | Evidence | Status | Limitation / missing requirement |
| --- | --- | --- | --- |
| Usage Access declaration | `android/app/src/main/AndroidManifest.xml` declares `android.permission.PACKAGE_USAGE_STATS`. | **Configuration-only** | The user must still grant special Usage Access in Android Settings. The manifest declaration does not grant it. |
| Settings navigation | `MainActivity` handles `openUsageSettings` with `Settings.ACTION_USAGE_ACCESS_SETTINGS`. | **Implemented native bridge** | `ChildUsageScreen` checks and reads usage, but the inspected source has no call to `openUsageSettings`; a user-facing recovery route is not proven. |
| Access check | `MainActivity.hasUsageAccess()` queries the preceding hour and returns true only when usage stats are non-empty. | **Partially implemented** | This is a heuristic, not a permission-state check; an authorized device with no returned data may appear unauthorized. No `AppOpsManager` check is used. |
| Daily aggregate | `MainActivity.getTodayUsage()` queries `UsageStatsManager.INTERVAL_DAILY` from local midnight to now, groups entries by package, and returns total/social-media/gaming/video minutes. | **Partially implemented** | Stats are device-local and may be incomplete/subject to platform semantics; time-zone/day-boundary and physical-device behavior are untested. Categorization is package-name substring matching, not a maintained taxonomy. |
| Flutter collection and persistence | `lib/screens/child/usage_screen.dart`, `_syncRealUsageData`, invokes `hasUsageAccess` / `getTodayUsage` and writes `users/{uid}/screenTime/{YYYY-MM-DD}`. | **Partially implemented** | Runs when this screen syncs, not as verified background telemetry. Child client writes are untrusted until rules/server validation exist. |
| Parent reporting | `lib/screens/parent/usage_screen.dart`, `_loadUsageData`; parent dashboard reads child documents. | **UI/data consumer only** | Read authorization depends entirely on absent/unverified Firestore rules. Values are not independently verified. |

**Technical limitation:** this code measures usage only on the device where Mindora
runs and reports what Android returns. It does not establish a trusted,
continuously synchronized parent-to-child monitoring service.

## 2. Android app blocking and limits

| Item | Evidence | Status | Missing requirement / limitation |
| --- | --- | --- | --- |
| Device Admin declaration | `android/app/src/main/AndroidManifest.xml` registers `MindoraDeviceAdminReceiver`; `res/xml/mindora_device_admin.xml` requests only `force-lock`. | **Implemented legacy admin enrollment prompt** | Activating a Device Admin receiver does not make the app Device Owner or Profile Owner. |
| Admin activation UI | `MainActivity` handlers `isDeviceAdminActive` and `requestDeviceAdmin`; `AppRestrictionsScreen._checkDeviceAdmin` / `_requestDeviceAdmin`. | **Partially implemented** | The UI treats Device Admin as sufficient for restriction, which is false for package suspension. |
| Direct suspension attempt | `MainActivity.setAppBlocked` calls `DevicePolicyManager.setPackagesSuspended`; `_setAppBlocked` shows success/failure. | **UI-only / not available on ordinary consumer installs** | Android documents this API for a Device Owner, Profile Owner, or a delegate with package-access delegation; ordinary Device Admin lacks this authority. [Android API reference](https://developer.android.com/reference/android/app/admin/DevicePolicyManager), [Android Enterprise guidance](https://developer.android.com/work/dpc/security) |
| Limit storage UI | `AppRestrictionsScreen._chooseDailyLimit` writes `users/{childId}/appLimits/{packageName}`. | **Implemented client write, enforcement-unverified** | It accepts any supplied `childId`; authorization is not proven, and a saved limit does not make a device enforce it. |
| Limit worker | `android/app/src/main/kotlin/com/example/mindora_family/AppLimitWorker.kt`, `doWork()`. Reads `appLimits`, calculates use, checks `isDeviceOwnerApp`, then calls `setPackagesSuspended`. | **Not operational** | `MainActivity.kt` imports WorkManager classes but contains no scheduling/enqueue call; repository search finds no `AppLimitWorker` instantiation. It fails without Device Owner and trusts `childId` input without proving device ownership. |

**Required for genuine Android enforcement:** managed-device enrollment that creates a
Device Owner or supported Profile Owner relationship (or documented delegated
package access), a verified child-device registration, server-authorized policy
sync, scheduled enforcement/health reporting, unenrollment behavior, and tests on
managed hardware. Device Admin activation alone is not an acceptable substitute.

## 3. iOS current implementation

| Area | Evidence | Status | Conclusion |
| --- | --- | --- | --- |
| Native runner | `ios/Runner/AppDelegate.swift` registers generated Flutter plugins only. | **Implemented standard Flutter runner** | No Mindora-specific iOS MethodChannel or Screen Time code exists. |
| App metadata | `ios/Runner/Info.plist` contains standard app/scene/orientation metadata. | **Configuration-only** | No parental-control or Screen Time configuration is present. |
| Xcode targets | `ios/Runner.xcodeproj/project.pbxproj` declares only `Runner` and `RunnerTests` targets. | **Not implemented** | No Device Activity Monitor, Device Activity Report, Shield Action, or Shield Configuration extension targets exist. |
| Framework/entitlement search | No `FamilyControls`, `DeviceActivity`, `ManagedSettings`, `FamilyActivityPicker`, `Shield`, App Group, or `com.apple.developer.family-controls` references; no iOS `*.entitlements` file was found. | **Not implemented** | The project cannot request Screen Time authorization, select protected apps/categories, monitor activity, or apply shields. |

## 4. iOS parental-control requirements

Apple’s Screen Time capability is not available through Flutter alone. The
repository would need all of the following before it can claim iOS parental
controls:

1. Family Controls capability and the `com.apple.developer.family-controls`
   entitlement for the app **and applicable extensions**.
2. Apple entitlement/distribution approval and provisioning profiles for the app
   and extensions.
3. A FamilyControls authorization flow and a privacy-preserving
   `FamilyActivityPicker` selection flow.
4. Native `DeviceActivity` schedule/event monitoring and `ManagedSettings`
   shield/settings logic, commonly hosted in Screen Time extension targets.
5. App Group/shared-state design and a secure Flutter-to-native bridge.
6. Real-device testing with the required family/guardian authorization scenario.

Apple documents that Family Controls enables Screen Time app extensions used with
Managed Settings and Device Activity, and that distribution requires entitlement
permission. [Configuring Family Controls](https://developer.apple.com/documentation/Xcode/configuring-family-controls),
[requesting the entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement),
and [Screen Time frameworks](https://developer.apple.com/documentation/screentimeapidocumentation).

## 5. Firebase connectivity and gaps

| Feature | Evidence | Status | Gap / limitation |
| --- | --- | --- | --- |
| Firebase initialization | `lib/main.dart`, `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`; `lib/firebase_options.dart`; platform Google service files. | **Implemented client configuration** | Connectivity to the configured project is not verified by this source review. |
| Email/password registration and login | `RegisterScreen._register`, `LoginScreen._login`; password reset in `LoginScreen`. | **Implemented client flow** | Email verification, MFA, server-side profile provisioning, rate controls, and production Auth settings are not evidenced. |
| User profile data | Registration writes `users/{uid}` fields `uid`, name, email, age, gender, role, createdAt. Role selection merges `role`. | **Implemented client write, critical security gap** | Client selects its own role; no deployed rules are available to prove protection. |
| Parent-child link | `AddChildScreen._addChild` queries child by email/role, updates `parentId`, and separately appends `childIds`. | **Partially implemented and insecure** | Client-controlled two-write relationship; no consent/acceptance, transaction, anti-enumeration, or server authorization. |
| Feature data | Firestore subcollections in use: `screenTime`, `dailyStats`, `moods`, `assessments`, `goals`, `aiAnalysis`, `recommendations`, `appLimits`. | **Implemented client persistence** | Schema/versioning, field validation, authorization, retention, and integrity controls are not versioned. |
| Security rules, indexes, emulator | Repository root contains `firebase.json` Flutter app configuration only; no `firestore.rules`, `firestore.indexes.json`, Storage rules, Firebase Functions, or emulator suite. | **Not implemented in repository** | Deployed rules may exist but are **unverified**; app security must not be inferred from Flutter checks. |

## 6. AI model and backend

| Item | Evidence | Status | Missing requirement / limitation |
| --- | --- | --- | --- |
| Client API contract attempt | `lib/services/ai_service.dart`, `AiService.predict`, POSTs JSON to `$baseUrl/predict`. | **Partially implemented client** | No timeout, Firebase ID token, TLS enforcement, response schema validation, model version, or ownership check. |
| Endpoint configuration | `lib/config/api_config.dart`, `ApiConfig.baseUrl`, defaults to `http://10.0.2.2:8000` (Android) or `http://localhost:8000` (iOS/web); Android manifest enables cleartext traffic. | **Development-only configuration** | Cannot serve a production physical device without an explicitly supplied reachable host; HTTP exposes submitted data. |
| UI invocation/storage | `lib/screens/parent/ai_analysis_screen.dart`, `ParentAiAnalysisScreen` calls `AiService.predict` and persists returned probabilities plus age, gender, usage, sleep/activity/study, assessment, notification-count, and mood data to `aiAnalysis`. | **Partially integrated client-side** | The endpoint/model must exist and be trustworthy for this to work; results are stored from client-controlled values. |
| Model/service/training artifacts | Repository search found no FastAPI app, Python requirements, model artifact, dataset, training/evaluation pipeline, Random Forest, SHAP, Docker/deployment configuration, or backend directory. | **Not implemented** | No model functionality, performance, calibration, leakage controls, imbalance handling, or explainability can be verified. |

**Conclusion:** the client has an API call and display/storage path, but this
repository does not establish a functional AI service. It must not present an AI
output as a clinical diagnosis; the service/model work remains R4.1–R4.3.

## 7. Notifications

| Capability | Evidence | Status | Missing requirement / limitation |
| --- | --- | --- | --- |
| Local notifications | `lib/services/notification_service.dart`, `NotificationService.initialize` configures Android/iOS settings, asks notification permissions, creates `mindora_alerts`; `showNotification` displays a local notification. | **Implemented local notification mechanism** | Permission is requested at startup (`lib/main.dart`) without contextual education; no notification tap/action routing is configured. |
| Local test trigger | `SplashScreen._sendTestNotification` and `NotificationTestScreen` call `showNotification`. | **Implemented test UI** | This proves only an on-device local notification call path, not a parent alert/report system. |
| Firebase Messaging package | `pubspec.yaml` declares `firebase_messaging: ^16.7.0`. | **Configuration-only** | No source references `FirebaseMessaging`, token retrieval/refresh, permission state, foreground/background/terminated handlers, topic/recipient targeting, or token deletion on logout. |
| Remote notification sender | No Cloud Functions/FastAPI/backend sender exists in this repository. | **Not implemented** | No authenticated server trigger exists for usage, limit, goal, or report notifications. |

## 8. Privacy and data inventory

### Data collected/persisted by the client

| Data category | Fields / source evidence | Intended storage / transmission | Status and privacy gap |
| --- | --- | --- | --- |
| Account/profile | Name, email, age, gender, role, UID; `RegisterScreen._register`; display name in Firebase Auth. | Firebase Auth and `users/{uid}` Firestore document. | No consent record, age/guardian verification, retention, export, or deletion implementation. |
| Family relationship | Child email lookup, `parentId`, `childIds`; `AddChildScreen._addChild`. | Firestore `users` documents. | Email enumeration and client-controlled linking; no invitation acceptance or auditable authorization. |
| Device/app usage | Total, social-media, gaming, video minutes; `MainActivity.getTodayUsage`, `ChildUsageScreen._syncRealUsageData`. Installed app labels/package names exposed by `getInstalledApps`. | `screenTime`; app limits in `appLimits`; native memory before upload. | Usage permission is sensitive; collected data can be forged by client; package visibility is broad. No disclosure or data minimization policy is versioned. |
| Routine/activity | Sleep hours, physical activity minutes, work/study minutes; `ChildGoalsScreen` / `GoalsScreen`. | `dailyStats`. | No retention/consent or server validation evidenced. |
| Mood and self-assessment | Mood title/emoji; anxiety, stress, digital-control, phone-discomfort scores; `MoodScreen._saveMood`, `ChildAssessmentScreen._saveAssessment`. | `moods`, `assessments`, then copied/derived in `aiAnalysis`. | Sensitive wellbeing data; no consent, access policy, clinical disclaimer governance, retention, or deletion workflow. |
| AI analysis | Prediction/risk probabilities and input feature copies; `ParentAiAnalysisScreen` write to `aiAnalysis`. | Firestore plus unauthenticated HTTP POST to `/predict`. | HTTP is cleartext by default; no token authentication, minimization, backend privacy controls, or scientific governance evidence. |
| Recommendations/goals/limits | Goal state, recommendations, app-limit selections; relevant parent/child screens. | `goals`, `recommendations`, `appLimits`. | Authorization must be server/rules enforced; it is not proven. |
| Notification-related data | Local notification title/body only in source. `firebase_messaging` package is unused. | Local OS notification service; no FCM token storage found. | No remote-token privacy issue is implemented yet, but no end-to-end notification design exists either. |

### Security and consent gaps

1. **Authorization is not demonstrably enforced outside the client.** No Firestore
   rules are tracked, while the client writes role, parent/child links, child data,
   app limits, and analysis records directly.
2. **No privacy lifecycle is implemented.** Source inspection finds sign-out in
   `ParentSettingsScreen`, but no account deletion, data export, retention policy,
   consent ledger, or cascading cleanup.
3. **Sensitive data are overexposed to an unprotected AI route.** Age/gender,
   behavioral and wellbeing attributes are posted through cleartext HTTP by
   `AiService.predict`, with no identity token or timeout.
4. **The data subject relationship is not securely established.** The parent
   searches a child by email and creates the relation without a child-side
   acceptance record.
5. **No actual production policy can be inferred.** A privacy policy, deployed
   Firebase rules, crash-reporting settings, server logs, and store disclosures are
   outside this repository or absent.

## R0.2 conclusion and next dependency

The app currently provides a Flutter prototype with Firebase client persistence,
partially wired Android same-device usage collection, and local test
notifications. It does **not** yet provide secure parent-child authorization,
ordinary-device Android blocking, iOS parental controls, a verifiable AI backend,
or end-to-end FCM.

This matrix satisfies R0.2’s documentation dependency. R0.3 is deliberately not
started: backup-file quarantine/removal requires separate user approval.
