# Sprint 7 - Homely Rebrand, Reliability, and Growth Foundations

## Goal
Ship a reliable, testable Sprint 7 baseline that:
1. closes reliability gaps from Sprint 6 (push visibility + map usability),
2. starts the product-facing Homely rebrand,
3. adds growth foundations (Google Sign-In + ES/EN core localization),
without breaking current production behavior.

## Definition of Done
Sprint 7 is done only when all of the following are true:
- All Sprint 7 tasks are marked complete in this file with evidence.
- `CLAUDE.md` has been reviewed before each task and updated when decisions changed.
- Backend tests pass in Docker (`13/13` suites expected baseline).
- `flutter analyze` passes with zero issues.
- Release APK is built, renamed with version/build/date naming, and install-tested.
- No secrets are committed.

---

## Mandatory AI Workflow (Non-Negotiable)
Before starting any Sprint 7 task:
1. Read root `CLAUDE.md`.
2. Confirm task assumptions still match `CLAUDE.md`.
3. If mismatch exists, update `CLAUDE.md` first, then continue implementation.

After finishing each task:
1. Run the task verification commands.
2. Capture result in this file.
3. Commit with one focused message (`sprint7: ...`).
4. Do not start next task until verification passes.

Rule: one task = one commit. No mixed commits.

---

## Sprint 7 Constraints
- Backend commands run in Docker (host has no Node/npm workflow).
- Use `docker compose` v2 syntax only.
- Do not change Android package id/Firebase project ids in Sprint 7.
- Do not introduce FCM legacy-first behavior; HTTP v1 remains the target path.
- No secrets in git (`service-account.json`, private keys, `.env.production`, raw tokens).

---

## Versioning and Artifacts
Source of truth: `app/pubspec.yaml`
- Baseline at Sprint 7 start: `1.3.1+8`.
- If mobile code changes and users need a new install, bump at least `buildNumber`.
- APK naming for handoff:
  - `homely-v<semver>-build<build>-YYYYMMDD-HHMM.apk`

Example:
- `homely-v1.3.2-build9-20260221-1810.apk`

---

## Sprint 7 Status Board

| Task | Scope | Status | Evidence |
|---|---|---|---|
| 7.0 | Pre-sprint hardening and baseline validation | Completed | Commits: `6ac4b5b`, `b09524b`, `894e6a5` |
| 7.1.1 | Foreground push visibility in app | Completed | Commit: `8c13e8b` |
| 7.1.2 | Push observability counters + structured logs | Completed | Commits: `3dbbfc1`, `02ff4c5` |
| 7.1.3 | "Locate me" action in address map flow | Completed | Commit: `1bb3dc2` |
| 7.2.1 | Homely visual foundation (theme/tokens + role accents) | Next | Start here next |
| 7.2.2 | UI revamp of key screens (auth, homes, jobs/requests, addresses) | Planned | Pending |
| 7.3.1 | Google Sign-In for CLIENT and PROVIDER | Planned | Pending |
| 7.3.2 | ES/EN selector and core flow translations | Planned | Pending |

---

## Completed Work Log

### 7.0 - Phase 0 (Completed 2026-02-21)
Security hygiene, split commits, baseline checks completed.

### 7.1.1 - Foreground Push Visibility (Completed 2026-02-21)
Implemented local notifications for FCM foreground messages.
- App dependency: `flutter_local_notifications`
- File: `app/lib/core/notifications/push_notifications_service.dart`

### 7.1.2 - Push Observability (Completed 2026-02-21)
Implemented lightweight observability in backend push pipeline.
- Structured push delivery logs with context/transport/success/failure.
- In-memory counters by transport (`http_v1`, `legacy`, skipped reasons).
- Context counters for business events (new request, accepted request, account state changes).
- New admin-only endpoint: `GET /ops/push-observability`

Files:
- `backend/src/notifications/push-notifications.service.ts`
- `backend/src/admin/admin.controller.ts`
- `backend/src/users/users.service.ts`
- `backend/src/service-requests/service-requests.service.ts`

### 7.1.3 - Locate Me in Address Flow (Completed 2026-02-21)
Added explicit user action to recenter pin with current GPS location.

Files:
- `app/lib/features/client/addresses/addresses_screen.dart`

Behavior:
- New button: `Usar mi ubicacion`
- Requests location permission if needed.
- Updates lat/lng and animates map camera when interactive map is enabled.
- Shows short feedback via snackbar for denied GPS/permission or success.

---

## Remaining Sprint 7 Tasks (Execution Spec)

## Task 7.2.1 - Homely Visual Foundation

### Objective
Create a reusable design base so UI revamp is consistent and incremental, not random per screen.

### Implementation Scope
- Define app-level design tokens (colors, spacing, typography, radii, elevations).
- Add role accents:
  - CLIENT accent palette
  - PROVIDER accent palette
- Keep ADMIN flow functional with existing visual baseline.

### Files Expected
- `app/lib/...` theme/design-system files (new or updated)
- Shared UI primitives used by multiple screens

### Testability Requirements
Automated:
- `flutter analyze` passes.

Manual:
- CLIENT and PROVIDER home screens display different accent treatment.
- Text contrast remains readable across primary surfaces.
- No visual regression that blocks form input or navigation.

### Exit Criteria
- Design tokens are centralized and reused.
- At least 2 role-based screens consume the new tokens.
- No hardcoded ad-hoc color duplication in newly touched widgets.

---

## Task 7.2.2 - UI Revamp of Key Screens

### Objective
Improve perceived quality and clarity of core user journeys without rewriting the whole app.

### Screen Scope (minimum)
- Auth screens
- Client home + my requests list
- Provider home + available jobs list
- Addresses list/form

### Implementation Rules
- Keep existing business flow intact.
- Do not change API contracts in this task.
- Keep navigation structure stable unless a bug requires change.

### Testability Requirements
Automated:
- `flutter analyze` passes.

Manual:
- New user can register/login and reach role home.
- Client can create request from revamped flow.
- Provider can see/accept jobs from revamped flow.
- Address CRUD still works after styling changes.

### Exit Criteria
- All listed screens updated and consistent with 7.2.1 tokens.
- No regression in request lifecycle actions.
- Before/after screenshots collected for changed screens.

---

## Task 7.3.1 - Google Sign-In (CLIENT + PROVIDER)

### Objective
Add lower-friction onboarding while preserving current auth behavior.

### Scope
- Add Google Sign-In for CLIENT and PROVIDER.
- Keep ADMIN login as email/password only.

### Backend Requirements
- Secure token verification and role-safe account linking.
- No route that allows role escalation.

### Testability Requirements
Automated:
- Backend auth tests updated for Google path.
- Existing auth tests still pass.
- `flutter analyze` passes.

Manual:
- New CLIENT can sign in with Google and receive CLIENT role only.
- New PROVIDER can sign in with Google and receive PROVIDER role only.
- Existing email/password accounts still log in.
- ADMIN cannot authenticate through Google path.

### Exit Criteria
- Google auth works for both allowed roles.
- Security guardrails validated (no unauthorized role upgrade).
- Error handling messages are user-readable for canceled/failed login.

---

## Task 7.3.2 - ES/EN Localization Core Flows

### Objective
Enable bilingual MVP usage for core journeys.

### Scope (minimum translated areas)
- Auth
- Client request creation and request status screens
- Provider job queue and my jobs screens
- Common validation and push-facing UI labels

### Implementation Rules
- Keep translation keys centralized.
- Avoid hardcoded strings in newly touched core screens.

### Testability Requirements
Automated:
- `flutter analyze` passes.

Manual:
- Language selector works at runtime.
- Switching language updates visible text without app reinstall.
- Core flow text is complete in ES and EN for scoped screens.

### Exit Criteria
- ES/EN selector available in app settings or onboarding.
- All scoped screens translated both languages.
- No mixed-language critical CTA text in scoped screens.

---

## Verification Commands
Run after each task and again before sprint close.

```bash
# Backend tests (Docker)
cd /home/carlossprekelsen/Marketplace-Evelyn
docker run --rm -v "$PWD/backend:/app" -w /app node:22-alpine sh -lc "npm test -- --runInBand"

# Flutter checks
cd /home/carlossprekelsen/Marketplace-Evelyn/app
/home/carlossprekelsen/development/flutter/bin/flutter analyze
```

Release build checkpoint (when shipping a new app build):

```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/app
/home/carlossprekelsen/development/flutter/bin/flutter build apk --release \
  --dart-define=API_BASE_URL=https://claudiasrv.duckdns.org \
  --dart-define=ENV=production
```

---

## Sprint 7 Exit Checklist
- [ ] All task rows in Status Board are `Completed`.
- [ ] `CLAUDE.md` is up to date with final Sprint 7 decisions.
- [ ] Backend tests pass in Docker.
- [ ] `flutter analyze` passes.
- [ ] Final APK built and renamed with Sprint 7 version/build naming.
- [ ] Release notes updated with user-visible changes.
- [ ] No secrets in tracked files.

---

## Deferred (Still Out of Scope for Sprint 7)
| Item | Reason |
|---|---|
| Full web admin expansion (advanced user/request ops) | Keep Sprint 7 focused on mobile quality + growth |
| End-to-end push analytics stack (BigQuery/dashboarding) | Lightweight observability is enough for this sprint |
| Online payments | Not in MVP scope yet |
| Full technical rebrand (package id/Firebase project rename) | Requires dedicated migration sprint |
