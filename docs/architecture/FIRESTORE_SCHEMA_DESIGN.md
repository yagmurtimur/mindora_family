# Mindora Family — Canonical Firestore Schema Design

Status: R1.1 architecture only. This document changes no code, rules, indexes,
Firebase configuration, or production data. Deployed rules/indexes are
**unverified**, not assumed absent.

## Design principles

- A trusted server (Admin SDK callable/API) is the only writer of roles,
  relationship state, device ownership/trust, aggregates, AI results, delivery
  state, and server timestamps.
- An **accepted relationship** is the sole authorization fact for parent access.
  Arrays, UI state, email lookups, and client fields never authorize access.
- A child cannot assign a parent or change role: clients have no write permission
  to role or relationship fields; invitation acceptance occurs in one server
  transaction.
- One parent can have many accepted child relationships and one child can have
  many registered devices. The schema can support multiple guardians, subject to
  an explicit future policy limit.

```text
Auth UID → accounts/{uid}                 private account and server role
           relationships/{relationshipId} lifecycle/audit record
           children/{childId}/guardians/{parentUid} deterministic active access
           children/{childId}/guardianRevocations/{parentUid} deterministic deny
           parents/{parentUid}/children/{childId}  deterministic parent listing
           children/{childId}/...         child domain data

Parent access requires `get(children/{childId}/guardians/{auth.uid})` with
`status == "accepted"` and no matching guardian-revocation marker. Rules do not
query `relationships` to authorize access.
```

## Current schema evidence

| Current path | Source evidence | Problem |
| --- | --- | --- |
| `users/{uid}`: profile, `role`, `parentId`, `childIds` | `register_screen.dart`, `_register`; `role_selection_screen.dart`, `_continue`; `add_child_screen.dart`, `_addChild` | Role and relationship are client-written; link is two non-atomic writes. |
| `users/{uid}/screenTime/{date}` | `child/usage_screen.dart`, `_syncRealUsageData` | No installation identity or trust state. |
| `dailyStats`, `moods`, `assessments` | child goal/mood/assessment screens | No canonical ownership or retention definition. |
| `goals/current`, `appLimits/{packageName}` | parent goal/restriction screens | Parent authorization rests on caller-supplied child ID. |
| `aiAnalysis/{date}`, `recommendations/{date}` | parent AI and child recommendation screens | Client persists results; no backend provenance. |

Current parent UI uses `childIds.first` or queries `users` by `parentId` and
`role` (`parent_dashboard.dart`, `usage_screen.dart`, `ai_analysis_screen.dart`,
`settings_screen.dart`). This is a migration constraint, not a valid authorization
model.

## Proposed layout

```text
accounts/{uid}
accounts/{uid}/notificationEndpoints/{endpointId}
accounts/{uid}/notifications/{notificationId}
relationshipInvitations/{inviteId}
relationships/{relationshipId}
parents/{parentUid}/children/{childId}
children/{childId}
children/{childId}/guardians/{parentUid}
children/{childId}/guardianRevocations/{parentUid}
children/{childId}/devices/{installationId}
children/{childId}/devices/{installationId}/usageDays/{YYYY-MM-DD}
children/{childId}/devices/{installationId}/usageDays/{date}/apps/{appKey}
children/{childId}/usageDays/{YYYY-MM-DD}
children/{childId}/goals/{goalId}
children/{childId}/appPolicies/{policyId}
children/{childId}/moods/{YYYY-MM-DD}
children/{childId}/assessments/{YYYY-MM-DD}
children/{childId}/analyses/{analysisId}
children/{childId}/recommendations/{recommendationId}
children/{childId}/auditEvents/{eventId} (server-only optional audit)
```

All IDs other than `uid`, `childId`, and date keys are opaque server-generated
strings. Timestamp means Firestore `Timestamp`; all strings/enums are bounded and
allowlisted. `schemaVersion: int`, `createdAt: Timestamp`, and `updatedAt:
Timestamp` are present on mutable documents unless stated otherwise.

## Collection contracts

| Path | Fields / types | Owner and access | Server-controlled and validation | Retention |
| --- | --- | --- | --- | --- |
| `accounts/{uid}` | `role: parent|child|pending|disabled`, `status`, `displayName`, `birthYear?` or age band, `locale?`, `timeZone`, lifecycle timestamps | Self reads; self updates only displayName/locale/timeZone. No linked parent reads private account. | Server creates role/status/auth metadata/lifecycle/timestamps. Role immutable to client; UID path matches Auth UID. | Account lifecycle; no duplicate raw email unless required. |
| `relationshipInvitations/{inviteId}` | `parentId`, `childId?`, `target`, `status: pending|accepted|declined|revoked|expired`, `createdAt`, `expiresAt`, resolution timestamps, `resolvedRelationshipId?` | Inviter parent and addressed child read. Parent requests create/revoke; child requests accept/decline. | Server state transitions; recipient must match caller; parent/child differ; expiry and one-way transitions validated. | Short policy-defined expiry/purge (for example 30–90 days). |
| `relationships/{id}` | `parentId`, `childId`, `status: accepted|revoked`, `acceptedAt`, `revokedAt?`, `sourceInviteId`, `revokedBy?`, `consent` | Named parent/child may read audit-safe representation; it is not used by rules for list/query authorization. | Server-only create/revoke. Enforce unique active pair and invitation source. | Relationship/audit policy; soft revoke before eventual purge. |
| `children/{childId}/guardians/{parentUid}` | `parentUid`, `childId`, `relationshipId`, `status: accepted`, `acceptedAt`, `allowedDataScopes: map<bool>`, `consentPolicyVersion`, `updatedAt` | Parent UID named by document and child read. This is the deterministic child-resource authorization lookup. | Trusted backend only. Document ID must equal immutable `parentUid`; path child ID equals field; active document exists only for accepted relationship. | Delete atomically on access revocation; relationship audit remains separately. |
| `children/{childId}/guardianRevocations/{parentUid}` | `parentUid`, `childId`, `relationshipId`, `revokedAt`, `reasonCode`, `updatedAt` | No client read/write needed for product UI; rules use deterministic existence as an explicit deny. | Trusted backend only. Create atomically before/delete alongside active membership on revocation; remove only in a new accepted-link transaction. | Keep through the revocation/re-link policy window; purge only when no historic authorization risk remains. |
| `parents/{parentUid}/children/{childId}` | `parentUid`, `childId`, `relationshipId`, `status: accepted`, `acceptedAt`, `childDisplayName?`, `updatedAt` | Named parent reads/lists its own subcollection; child may read only its own matching mirror if needed. | Trusted backend only. This is a listing projection, never the child-resource authorization fact. | Delete atomically on revocation; no sensitive child profile fields. |
| `children/{childId}` | `childId`, `displayName`, `avatarRef?`, `timeZone`, `status` | Child and accepted parents read. Child updates narrow presentation allowlist. | Server sets ID/status/timestamps; no role, email, parent arrays, or parent ID. | Account lifecycle. |
| `children/{childId}/devices/{installationId}` | `ownerChildId`, `platform`, `appVersion`, `osVersion?`, `enrollmentMode`, `enrollmentState`, `capabilities`, `usageAccessState`, `lastSeenAt?`, `registeredAt`, `serverTrust`, `pushEndpointId?` | Child and linked parent read minimized status. | Server binds/revokes device. Client may submit constrained registration/heartbeat only; cannot set owner, trust, enrollment, policy version, raw push token, or timestamps. One active child per install. | Purge stale/revoked device metadata per policy. |
| `.../devices/{install}/usageDays/{date}` | `date`, `timeZone`, interval timestamps, category seconds, `source`, `sourceTrust`, `clientObservedAt?`, `collectedAt` | Registered child installation submits constrained raw telemetry; child/linked parent read policy-approved detail. | Server verifies installation/child and bounds nonnegative values; writes trust and server times. | Shorter retention for detailed data. |
| `.../usageDays/{date}/apps/{appKey}` | normalized app key, packageName?/displayName?, category, `foregroundSeconds`, source/trust | Same as raw day; package/app detail subject to consent. | Server normalizes key and validates data; package name never arbitrary document ID. | Shortest practical retention. |
| `children/{childId}/usageDays/{date}` | daily aggregate seconds, categories, deviceCount, completeness, aggregationVersion, computedAt | Child and accepted parent read; parent dashboard uses this record. | Server-only aggregation; raw client data is never enforcement proof. | Aggregate may outlive raw data for report period. |
| `children/{childId}/goals/{goalId}` | `type`, `target:{unit,value}`, schedule, `status`, effective dates, `createdBy`, `updatedBy`, `version`, completion | Child/accepted parent read. Parent requests create/update/archive; child only approved progress input. | Server validates limits/schedule/creator/timestamps/completion. | Archive for reports then lifecycle purge. |
| `children/{childId}/appPolicies/{policyId}` | normalized target, `dailyLimitSeconds?`, `blocked`, `enabled`, effective dates, version, delivery state | Parent reads and requests mutation; child reads disclosure. | Server validates link and policy. Device worker/server alone writes delivery state. Do not promise block unless managed device capability exists. | Retain policy audit only as required. |
| `children/{childId}/moods/{date}` | `date`, `timeZone`, allowlisted `moodCode`, optional approved note, `reportedAt` | Child creates/updates own permitted record; linked parent reads only with approved consent policy. | Server time and allowlist validation. | Sensitive wellbeing data: short retention. |
| `children/{childId}/assessments/{date or id}` | `assessmentVersion`, scores map (anxiety/stress/digitalControl/phoneDiscomfort), `derivedScore?`, submittedAt | Child submits bounded scores; linked parent reads only when policy permits. | Server derives score/timestamps/version; no diagnosis field. | Sensitive, minimum retention/export/delete support. |
| `children/{childId}/analyses/{analysisId}` | type, `dateKey`, model `{id,version}`, result `{riskBand,probability}`, explanation, status, computedAt, supersededBy? | Child and linked parent read summarized result. | Backend only writes; probability `[0,1]`; versioned non-clinical disclaimer. | Retain only useful history/provenance. |
| `children/{childId}/recommendations/{id}` | source, analysisId?, contentKey, parameters, audience, status, expiry, dismissal fields | Recipient reads; recipient can request own dismiss. | Server creates/dates/audits. | Expire short-lived advice. |
| `accounts/{uid}/notificationEndpoints/{id}` | platform, raw token (server-readable only), installationId?, status, timestamps | Client submits its own token to trusted endpoint; no client reads tokens. | Server owns endpoint ID, owner, token lifecycle, delivery status. | Revoke logout; quickly purge invalid/stale token. |
| `accounts/{uid}/notifications/{id}` | type, recipient UID, child/relationship ref?, localization keys, delivery map, createdAt, `isRead: bool`, readAt?, expiresAt? | Recipient reads and marks own notification read. | Server creates/sends/delivery updates; parent alert requires accepted relation at send time. | Short operational retention. |

## Invitation and access lifecycle

```text
active parent → requestInvite → server creates pending invitation
addressed child → acceptInvite → server transaction verifies identity, expiry,
  role/state and link limits → creates relationship + both active membership mirrors
  → resolves invitation
child guardian membership exists → permits parent read/policy requests for child
revoke → server revokes relationship and deletes both active mirrors atomically
```

No Flutter client writes `parentId`, `childIds`, `role`, or relationship status.
Thus an unrelated child cannot attach themself to a parent, and an unrelated parent
cannot read a child: rules use the deterministic child guardian membership before
granting access. Firebase documents atomic related-write
validation with transactions/`getAfter()`; use it where future rules require a
client atomic operation, while keeping membership creation server-only.
[Firebase transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)

## Proposed indexes (not deployed)

| Scope | Query | Index |
| --- | --- | --- |
| `parents/{parentUid}/children` | parent accepted children | No composite index for owner-scoped listing unless final sort/filter requires one; deterministic parent path is rule-safe. |
| `children/{childId}/guardians` | child accepted guardians | No composite index for deterministic `get()`; only add one if an approved UI lists/sorts guardians. |
| `relationshipInvitations` | parent pending invitations | `parentId ASC, status ASC, createdAt DESC` |
| `relationshipInvitations` | child pending invitations | `childId ASC, status ASC, createdAt DESC` |
| child `devices` | active devices by seen time | `enrollmentState ASC, lastSeenAt DESC` |
| child `analyses` | analysis history | `type ASC, status ASC, computedAt DESC` |
| child `recommendations` | active audience items | `audience ASC, status ASC, createdAt DESC` |
| account `notifications` | unread/latest inbox | `isRead ASC, createdAt DESC` |

Simple date-range daily records normally use automatic single-field indexes;
declare composites only after final query testing. Firestore requires indexes for
supported queries and recommends adding composites based on actual query errors.
[Firebase index overview](https://firebase.google.com/docs/firestore/query-data/index-overview)

## Field-level permission summary

| Data | Self client | Accepted parent | Child client | Server |
| --- | --- | --- | --- | --- |
| Roles/status/lifecycle | No | No | No | All changes |
| Safe account preferences | Own only | No | Own only | Validate |
| Invitation | Request/act only | Request/revoke only | Accept/decline only | State transition |
| Relationship | No | Revoke request | Accept/revoke request | Create/revoke atomically |
| Device ownership/trust | Heartbeat request | Read status | Register/heartbeat request | Bind/revoke |
| Usage raw/aggregate | Read own allowed view | Read linked view | Registered-device submit | Validate/aggregate |
| Goals/policies | Read | Request mutate | Read/permitted progress | Validate/write |
| Mood/assessment | Own only | Consent-limited read | Own bounded write | Validate/derive/delete |
| AI/recommendations | Read/dismiss own | Read/dismiss allowed | Read/dismiss allowed | Create/update |
| Notification endpoints | Submit own only | No | Submit own only | Store/send/revoke |

Future R1.2 rules must default deny, check accepted relationship on every child
resource, enforce field allowlists/type/range validation, and constrain queries
to permitted documents. Flutter role checks are never authorization.

## Migration and compatibility

1. Inventory existing `users` documents and deployed configuration read-only;
   reconcile contradictory `parentId`/`childIds` rather than choosing silently.
2. Add v2 accounts, invites, and relationships in parallel. Never authorize new
   requests from legacy fields.
3. Migrate only verified/accepted links; ambiguous records remain pending review.
4. Update clients to read v2 relationship and child data first. During a limited
   bridge, only the server may project legacy display data for old clients.
5. Backfill telemetry with `schemaVersion` and `sourceTrust: legacy_unverified`;
   preserve source/time-zone and do not treat it as enforcement evidence.
6. After rule/API tests and staged rollout, remove legacy authorization reads,
   including all `childIds.first` assumptions. Decommission legacy fields only
   after approved retention/backups.

Migration risks: conflicting current links; screens assuming exactly one child;
inconsistent local-date/minute records; AI documents lacking backend provenance;
and unknown deployed rules/indexes. No migration is authorized by R1.1.

## R1.1 exit criteria for R1.2/R1.3

- Rules tests can deny direct role and relationship writes.
- Parent reads/policy mutations fail before acceptance and succeed only after an
  accepted matching relationship exists.
- Unrelated parents cannot access another child; a second device cannot claim a
  different child.
- Production rule/index deployment, server endpoints, migration, and Flutter
  refactoring remain explicitly outside this task.

## Final R1.1 architecture review

This review distinguishes a **fully specified design** from an implemented
feature. None of the proposed server endpoints, rules, indexes, migration, or
cleanup jobs are implemented by this document.

### Review classification

| Area | Classification | Review outcome |
| --- | --- | --- |
| Invitation security | **Fully specified** | Token, expiry, single-use, acceptance, rate-limiting, and concurrency requirements are defined below. Implementation and testing remain R1.2/R1.3. |
| Device ownership | **Fully specified** | Registration, one-child binding, revocation, re-enrollment, and managed-device distinction are defined below. Device attestation/vendor support remains a product decision. |
| Privacy and consent | **Partially specified** | Access/minimization/revocation requirements are defined; the legal basis, age thresholds, guardian verification, and final retention periods require legal/product approval. |
| Account deletion and retention | **Partially specified** | Lifecycle and cleanup responsibilities are defined; legally approved retention durations, legal holds, and export format/SLA remain decisions. |
| Notification security | **Fully specified** | Recipient resolution, accepted-link verification, token lifecycle, and client restrictions are defined below. Sender implementation remains future work. |
| Final schema consistency | **Fully specified** | Paths, field types, ownership, multi-child/device support, index/query alignment, and migration risks are reviewed below. Rules/index deployment is intentionally not performed. |

### A. Invitation security — fully specified

`relationshipInvitations/{inviteId}` additionally requires:

| Field / control | Requirement |
| --- | --- |
| Token generation | Server generates at least 256 bits from a cryptographically secure RNG. `inviteId` is separate from the secret token and is not itself an authenticator. |
| Storage | Store `tokenHash: string`, `hashAlgorithm: "HMAC-SHA-256"`, `tokenKeyVersion: int`, and `tokenIssuedAt: Timestamp`. HMAC uses a server-side pepper in a secret manager. Never store raw token in Firestore, analytics, logs, notification payloads, or client preferences. |
| Delivery | Send raw token once over the approved invitation channel or require the addressed authenticated account to approve inside the app. Deep links carry only an opaque, short-lived token and must not be logged. |
| Expiry / use | `expiresAt` is mandatory and server-compared. Acceptance consumes the token permanently: `status` becomes `accepted`, `consumedAt` is server-set, and further attempts return a generic “unavailable” response. |
| Brute-force defense | Apply backend rate limits by parent, child/account, IP/device risk signal, and token attempt; use constant-time hash comparison; monitor failures. Token lookup must not reveal whether a child email/account exists. |
| Enumeration defense | Parent invite requests always return a generic queued/next-step response. The server performs account lookup internally and sends an invitation only if policy permits. No client Firestore query by child email is allowed. |
| Atomicity | One server transaction reads invitation, account states, deterministic relationship lock, and active-link policy; it then creates the relationship and consumes the invite. If any precondition changes, retry/return generic conflict. |
| Duplicate/concurrency | Use a server-secret HMAC of `(parentId, childId)` as an opaque deterministic relationship lock/document ID, or a separate server-only `relationshipKeys/{hmac}` lock. The transaction rejects an existing active relationship and cannot create two accepted links during concurrent acceptance. |

An invitation may be accepted only by its authenticated addressed child account.
The transaction must verify `status == pending`, unexpired token, matching token
hash, matching `childId`, active parent/child statuses, and all product guardian
limits before it writes `relationships/{relationshipId}`.

### B. Device ownership — fully specified

1. A signed-in child requests registration; server issues a one-time,
   short-lived challenge bound to `uid`, intended platform, and requested
   installation public identifier.
2. The app returns the challenge with platform evidence. Evidence can be basic
   authenticated registration initially and later platform attestation where
   supported; it must not be represented as proof of parental-control capability.
3. Server creates `devices/{installationId}` only after validating the challenge
   and writes immutable `ownerChildId`. Rules/endpoints never permit a client to
   change `ownerChildId`, `installationId`, trust, or enrollment mode.
4. A second registration of the same installation to another child is rejected.
   Reassignment requires server revocation of the prior record followed by a new
   registration; it is audited and requires a deliberate owner/guardian flow.
5. Revocation sets `enrollmentState: revoked`, records `revokedAt` and reason,
   invalidates its registration credentials and notification endpoint, stops
   accepting telemetry/policy acknowledgements, and removes it from aggregation.
6. Re-enrollment always uses a new challenge and normally a new installation ID;
   historical records retain the old ID for audit, subject to retention.

`enrollmentMode: monitor_only` is the default for ordinary Android/iOS installs.
`managed_enforcement` can be server-assigned only after an independent managed
device enrollment verification. Registered, authenticated, or attested devices
are still not proof that Android app blocking works; only verified Device
Owner/Profile Owner (or supported iOS Screen Time) capability may report an
enforcement state.

### C. Privacy and consent — partially specified

The following is mandatory in the architecture:

- Mood and assessment records are sensitive. Parent read access is **off by
  default** until the product adopts an approved consent policy. If enabled, it
  must be represented by server-controlled relationship/consent scope such as
  `scopes.moodRead` and `scopes.assessmentRead`, with policy version, grantor,
  effective date, and withdrawal time.
- Child self-report must use age-appropriate disclosure. Guardian authorization,
  child assent where applicable, and a jurisdiction-specific age threshold must
  be decided before enabling collection or parent visibility.
- Collect the minimum required fields: age band rather than exact age where
  possible; coded mood instead of free-text notes; aggregate usage rather than
  indefinite app-level history; no raw FCM tokens in parent-readable data.
- Relationship revocation immediately denies parent reads, policy writes,
  notifications, and new backend processing for that child. It does not grant the
  former parent access during a retention window.
- The server must support a data export request covering the authenticated
  account, accepted relationship records, child-domain data permitted to the
  requester, device metadata, and notification history. Exports must be
  authorized at generation time and delivered through a protected, expiring link.

### D. Account deletion and retention — partially specified

#### Server-only deletion workflow

```text
authenticated request → re-authentication/risk checks → deletion_pending
  → optional export / grace window → server revokes relationships and devices
  → idempotent cascade cleanup → Auth deletion / tombstone / final audit
```

| Data | Required action when account deletion completes |
| --- | --- |
| `accounts/{uid}` | Set `deletion_pending` immediately; purge private fields at completion; retain only minimum tombstone/audit identifier if legally required. |
| Relationships/invites | Revoke active relationships synchronously before cleanup; cancel pending invites; retain minimal non-identifying audit event only for approved period. |
| Devices/endpoints | Revoke devices and delete/purge endpoint tokens before Auth deletion; stop telemetry and delivery. |
| Usage / app detail | Delete raw per-device/app records and aggregates unless an approved legal retention obligation applies. |
| Goals/policies | Disable immediately; delete configuration/history during cascade unless approved retention requires a minimal audit. |
| Moods/assessments | Delete as sensitive data; no continued former-parent access. |
| Analyses/recommendations | Delete input snapshots and result documents; preserve model-wide non-personal metrics only if de-identified. |
| Notifications/audit | Delete user notification content; redact/pseudonymize operational audit records; keep only lawful minimum security evidence. |

The deletion worker must use a durable server-side deletion job document with
`jobId`, `subjectUid`, `state`, `startedAt`, `lastCheckpoint`, `retryCount`, and
an idempotency key. It traverses every known child subcollection and relationship
direction, so partial retries cannot create orphaned documents. It must not rely
on a mobile client to delete descendants. A recovery/cancellation is possible only
during a disclosed grace period before Auth deletion and must not reactivate a
revoked relationship without new authorization.

Final exact retention durations, legal-hold handling, backup expiration,
export file format, and deletion/export service-level targets remain unresolved
legal/product decisions.

### E. Notification security — fully specified

- Clients never write a recipient UID, child ID, parent ID, or FCM delivery state
  into notification records. They can submit only their own raw endpoint token to
  a trusted authenticated registration endpoint.
- Before every child-related send, server resolves recipients from the canonical
  accepted relationship and verifies the matching active guardian membership at
  send time. It never trusts a cached `childIds` array or request-supplied
  recipient list.
- The sender creates recipient-specific `accounts/{uid}/notifications/{id}`
  records and sends only to that account’s active endpoints. Notification payloads
  contain opaque navigation IDs/minimal text, not sensitive mood, assessment, or
  detailed usage content.
- Token rotation, logout, delivery-provider invalid-token responses, device
  revocation, inactivity threshold, and account deletion all mark endpoints
  `revoked`/`invalid` and schedule token purge. Sending is idempotent by event
  ID plus recipient and respects suppression/consent preferences.

### F. Final schema consistency check — fully specified

| Check | Result |
| --- | --- |
| Path hierarchy | Account-private resources stay under `accounts`; child-domain resources stay under `children/{childId}`; canonical lifecycle records are top-level while deterministic guardian/listing mirrors provide rule-safe access. |
| Field types | IDs are strings; enums are allowlisted strings; timestamps are Firestore Timestamps; numeric usage/limits are nonnegative integers in seconds; AI probability is bounded `[0,1]`. |
| Multi-child / multi-device | Parent lists `parents/{parentUid}/children`, while child access checks use `children/{childId}/guardians/{parentUid}`; each child owns many `devices/{installationId}` records; no first-child assumption exists. |
| Ownership | Each client-write candidate is bound to authenticated UID and installation; privileged fields are server-only. |
| Query/index alignment | Final index list covers invitations, deterministic owner-scoped membership listing, devices, analyses, recommendations, and `isRead` notification inboxes. Indexes are proposed only and must be tested against final queries. |
| Migration compatibility | Legacy `users` remains read-only compatibility data during migration; v2 is authoritative; conflicting legacy links are not auto-accepted. |

### G. Deterministic relationship membership — fully specified

Firestore Security Rules cannot safely discover an arbitrary parent-child link by
querying `relationships/{opaqueId}`. The active authorization representation is
therefore a deterministic, server-managed membership document:

```text
children/{childId}/guardians/{parentUid}
```

The fixed document path lets a rule for any child resource call `exists()` or
`get()` directly with the requested child ID and `request.auth.uid`, without a
collection query. The relationship document remains the durable lifecycle/audit
record; membership is the revocable access projection.

#### Child-side authorization membership

| Field | Type | Rule significance |
| --- | --- | --- |
| `parentUid` | string | Must equal `{parentUid}` document ID. |
| `childId` | string | Must equal `{childId}` path segment. |
| `relationshipId` | string | Server reference to the canonical lifecycle record. |
| `status` | string literal `"accepted"` | Active membership only; rules require this exact value. |
| `acceptedAt` | Timestamp | Server timestamp of acceptance. |
| `allowedDataScopes` | map of booleans | Server-controlled least-privilege scope, for example `usageRead`, `goalsWrite`, `moodRead`, `assessmentRead`, `policyWrite`. |
| `consentPolicyVersion` | string | Server-set policy version governing scopes. |
| `updatedAt` | Timestamp | Server timestamp. |

No client, including the named parent or child, may create, update, or delete this
document. Rules for `children/{childId}` and every descendant call a conceptual
helper such as `guardianMembership(childId, request.auth.uid)` and require both
an active document/explicit scope and no deterministic
`guardianRevocations/{parentUid}` document. The actual rule syntax is
reserved for R1.2.

#### Parent-side listing projection

```text
parents/{parentUid}/children/{childId}
```

This mirror solves safe multi-child listing: a parent lists only the collection
under their own deterministic UID path, which rules can authorize directly from
the path (`parentUid == request.auth.uid`) without trying to prove each result by
an unconstrained collection query. It contains only a minimized projection:
`parentUid`, `childId`, `relationshipId`, `status: "accepted"`, `acceptedAt`,
`updatedAt`, and optional non-sensitive display name. It is never used to grant
access to child domain data; the child-side guardian document remains mandatory.

#### Server transaction requirements

Acceptance creates, in one transaction:

1. `relationships/{relationshipId}` with accepted lifecycle state.
2. `children/{childId}/guardians/{parentUid}` active membership.
3. `parents/{parentUid}/children/{childId}` listing projection.
4. The consumed invitation update with `resolvedRelationshipId`.

Revocation atomically marks the relationship revoked, creates
`guardianRevocations/{parentUid}`, and deletes both active membership documents.
Deleting, rather than merely changing `status`, makes an `exists()` authorization
check fail immediately; the revocation marker is a defense-in-depth deterministic
deny if a stale guardian document is ever observed. A future accepted relationship
must remove its matching marker and create a new membership in the same server
transaction. Historical audit remains in the canonical relationship/server audit.

The transaction uses the existing deterministic HMAC relationship lock described
in invitation security. It verifies that neither active membership path exists
before acceptance, so duplicate/concurrent attempts cannot create two active
access grants.

#### Consistency and repair behavior

Server transactions are the preventive control. A server-only scheduled
reconciler is the recovery control and compares relationship state with both
mirrors:

| Condition | Conservative behavior | Repair authority |
| --- | --- | --- |
| Accepted relationship, one or both mirrors missing | Deny parent child-data access because guardian path is absent; parent listing may be incomplete. | Server recreates only after validating relationship and consent. |
| Guardian mirror exists, relationship missing/revoked/mismatched | If the revocation marker exists, rules deny access. If no marker exists, this is an active security incident because deterministic rules can see only the membership projection. | Server immediately creates revocation marker, deletes mirrors, and records audit event. |
| Parent listing mirror exists but guardian mirror missing | Parent may see stale list entry but cannot read child data. | Server removes/rebuilds listing from valid accepted relationship. |
| Field/path mismatch | Deny; no client repair. | Server removes invalid projection and investigates. |

The reconciler is not a substitute for atomic writes. It is idempotent, server
only, rate-controlled, and must alert on any active guardian mirror inconsistent
with its relationship.

#### R1.2 membership test additions

1. Parent read of every child-domain document succeeds only with
   `children/{childId}/guardians/{parentUid}` containing accepted status and the
   required scope.
2. Parent listing `parents/{auth.uid}/children` succeeds; listing any other
   parent UID or a collection-group equivalent fails.
3. A parent with a listing mirror but no guardian mirror cannot read child data.
4. Direct create/update/delete of either mirror by parent, child, unrelated user,
   or unauthenticated user fails.
5. Before acceptance and after expiry, both active mirrors are absent. After
   revocation, both active mirrors are absent and the deterministic revocation
   marker exists; parent child-data reads/policy writes fail.
6. Concurrent acceptance tests prove exactly one relationship plus exactly two
   mirrors are created; repeat acceptance is idempotent/generic conflict.
7. Scope tests prove a linked parent can read usage but cannot read mood or
   assessments without their explicit scopes.
8. Reconciliation fixtures prove revocation markers deny stale guardian mirrors;
   only trusted server repair can recreate an accepted membership.

## Unresolved decisions before R1.2

1. Legal guardian verification, supported countries, age thresholds, and child
   assent/consent wording.
2. Whether multiple active guardians are permitted and the maximum relationships
   per child/parent.
3. Exact retention, backup, legal-hold, deletion grace, and export requirements.
4. Whether parents may ever read mood/assessment data, and which server-controlled
   consent scopes are required.
5. Device attestation approach, supported Android Enterprise enrollment modes,
   and iOS entitlement availability.
6. Which detailed app usage/package data can be stored/read, for how long, and
   under which consent/disclosure.
7. Trusted backend choice, invitation delivery channel, abuse/rate-limit service,
   and secrets/key rotation ownership.
8. Final notification types/content and local regulatory requirements for push
   consent and delivery.

## R1.2 acceptance criteria

R1.2 must not deploy until its emulator rules tests demonstrate all of the
following:

1. Direct client create/update/delete of roles, invitations, relationships,
   device ownership/trust, aggregates, AI analyses, policy delivery, and
   notification delivery state is denied.
2. A parent can read only a child with a matching accepted, unrevoked lifecycle
   relationship, deterministic active guardian membership, and no deterministic
   revocation marker; access fails before acceptance and immediately after revoke.
3. A child cannot self-link, self-promote, invite another child, or access another
   child/device. An unrelated parent cannot query/list protected child data.
4. A registered device can submit only to its bound child/installation path and
   cannot reassign itself.
5. Parent policy writes and sensitive mood/assessment reads obey accepted-link
   and explicit consent-scope requirements.
6. Notification endpoint and inbox access is limited to the authenticated owner.
7. Field allowlists, types, limits, immutable IDs, server timestamps, query
   constraints, and all proposed composite indexes are verified.

R1.2 is not started by this review.
