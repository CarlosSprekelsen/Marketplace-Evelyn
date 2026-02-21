# Sprint 7 — Homely Rebrand, Reliability, and Growth Foundations

**Goal:** Start the Homely product identity while improving operational reliability (especially push visibility), and laying growth foundations (Google Sign-In + ES/EN localization core flows) without breaking current production behavior.

**Definition of Done:**
- Sprint 7 Phase 0 is executed and documented as completed (security hygiene, split commits, baseline validations).
- `CLAUDE.md` is reviewed and aligned before Sprint 7 implementation tasks.
- Sprint 7 execution tasks are clearly scoped so AI agents can implement one task per commit.
- No secrets are committed.

---

## Dev Environment

**Host constraints:**
- Node/npm are not installed on host for backend workflow.
- Backend test/runtime actions must run via Docker.
- Flutter commands run on host.

**Compose rule:**
- Use `docker compose` v2 syntax only.
- Do not use legacy `docker-compose` v1.

Useful baseline commands:

```bash
# Backend tests in Docker
cd /home/carlossprekelsen/Marketplace-Evelyn
docker run --rm -v "$PWD/backend:/app" -w /app node:22-alpine sh -lc "npm test -- --runInBand"

# Flutter static check
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
```

---

## How to Use This File

Execute Sprint 7 tasks in order.

After each task:
1. Run the verification commands listed in that task.
2. Commit with one clear message (`sprint7: ...`).
3. Move to next task only when verification passes.

**Rule:** One task = one commit. Do not bundle unrelated changes.

---

## CLAUDE.md Review (Mandatory Before Coding)

Before implementing Sprint 7 tasks, AI agents MUST read root `CLAUDE.md` and verify these items:

| Item in CLAUDE.md | Expected State | Verify Before Work |
|---|---|---|
| Current app version policy | `app/pubspec.yaml` is source of truth (`1.3.1+8` baseline) | YES |
| Rebrand scope for Sprint 7 | Product-visible rename to **Homely**, no package/Firebase ID migration yet | YES |
| Push channel | Firebase HTTP v1 path active, no new legacy path | YES |
| Android package name | `com.evelyn.marketplace` remains unchanged in Sprint 7 | YES |
| Build/deploy conventions | APK must be renamed, Compose v2 only, no destructive prod resets | YES |
| Guardrails | No secrets in git, no destructive git commands, no unnecessary architecture jumps | YES |

If any item is stale, update `CLAUDE.md` first or stop and resolve before implementation.

---

## AI Implementation Guardrails

### AI MUST do
- Read `CLAUDE.md` before writing code.
- Keep one task per commit with verification evidence.
- Use split clean commits.
- Keep secrets out of Git.

### AI MUST NOT do
- Do not commit private keys, service account JSON, `.env.production`, raw tokens, or similar secrets.
- Do not change `applicationId` / package name / Firebase project identifiers in Sprint 7.
- Do not add or reintroduce FCM legacy migration paths as primary flow.
- Do not use destructive git commands (`reset --hard`, force checkout overwrite).
- Do not ship broad UI rewrites in one commit; use incremental slices.

### STOP and ask if
- A task requires changing auth model for ADMIN users.
- A task requires package/Firebase technical rebrand in same sprint.
- A task conflicts with current production deployment guardrails.

---

## Current State Snapshot (Start of Sprint 7)

- Sprint 6 hotfix baseline is active.
- Version baseline in `app/pubspec.yaml`: `1.3.1+8`.
- Fresh APK exists: `marketplace-evelyn-v1.3.1-build8-20260221-1445.apk`.
- Push backend HTTP v1 path is configured and sending in acceptance flow.
- Foreground push visual UX still needs hardening for provider app experience.

---

## Sprint 7 Scope

### 7.1 Reliability Track
- Add visible foreground local notification behavior for FCM on provider/client app when app is open.
- Add push observability (structured delivery logs and lightweight counters).
- Add explicit "Locate me" button in map/address flow.

### 7.2 Homely Brand + UI Revamp (Incremental)
- Rebrand visible app name/text to Homely.
- Introduce warm-homey design direction.
- Introduce dual role accents (Client vs Provider) on shared design system.
- Revamp key screens first: auth, role homes, jobs/requests lists, addresses.

### 7.3 Growth Foundations
- Add Google Sign-In for CLIENT and PROVIDER.
- Keep ADMIN authentication as existing email/password path.
- Add ES/EN selector and translate core flows first.

---

## Phase 0 — Execution (Completed)

### Objective
Close pending pre-Sprint-7 work in safe commits, enforce security hygiene, and validate baseline quality before Sprint 7 coding.

### Checklist
- [x] Security scan performed (no private keys found in tracked files).
- [x] Sensitive local files protected by ignore rules.
- [x] Pending repo changes grouped and committed in clean batches.
- [x] Backend tests validated in Docker.
- [x] Flutter analyze validated.
- [x] Version/APK baseline verified.

### Completed On
- 2026-02-21

### Evidence

**Security / hygiene checks**

```bash
rg -n "BEGIN PRIVATE KEY|private_key\"\s*:|FIREBASE_SERVICE_ACCOUNT_BASE64=|AIza..." -S .
```

Result summary:
- No private key material found in tracked files.
- `google-services.json` kept local-only and now ignored by `.gitignore`.

**Phase 0 commit groups executed**

1. `6ac4b5b` — `sprint7: align android package and firebase/maps build wiring`
   - Android package consistency, Google services plugin wiring, manifest placeholder map key wiring.

2. `b09524b` — `sprint7: harden docs and infra defaults for phase 0`
   - `.gitignore` hardening, docs consistency updates, VPN allowlist update in Nginx.

3. `894e6a5` — `sprint7: document firebase http v1 push runbook`
   - Added/updated `PUSH_NOTIFICATIONS_GUIDE.md`.

**Baseline validation commands**

```bash
# Backend
cd /home/carlossprekelsen/Marketplace-Evelyn
docker run --rm -v "$PWD/backend:/app" -w /app node:22-alpine sh -lc "npm test -- --runInBand"
# Result: 13/13 suites, 99/99 tests passed

# Flutter
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Result: No issues found
```

**Version / artifact verification**

```bash
rg -n "^version:" app/pubspec.yaml
ls -lt app/build/app/outputs/flutter-apk | head
```

Result summary:
- Version baseline confirmed: `1.3.1+8`.
- Latest release artifact present with timestamped name.

### Phase 0 Status

**COMPLETED**

---

## Sprint 7 Final Verification Template

Run this before closing Sprint 7:

```bash
# Backend tests
cd /home/carlossprekelsen/Marketplace-Evelyn
docker run --rm -v "$PWD/backend:/app" -w /app node:22-alpine sh -lc "npm test -- --runInBand"

# Flutter checks
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze

# Release APK (example)
flutter build apk --release --dart-define=API_BASE_URL=https://claudiasrv.duckdns.org --dart-define=ENV=production
# Rename to homely-v<version>-build<build>-YYYYMMDD-HHMM.apk
```

---

## Commit Message Convention for Sprint 7

```text
sprint7: harden foreground push visibility with local notifications
sprint7: add push delivery observability counters and logs
sprint7: add locate-me action to address map flow
sprint7: rebrand client/provider core UI to Homely visual system
sprint7: add Google Sign-In for client and provider
sprint7: add ES/EN localization for core flows
```

---

## Deferred Items Carried Forward

| Deferred Item | Reason |
|---|---|
| Full web admin (user management, request management) | Foundation exists; expand incrementally in Sprint 7+ |
| Recurring requests in bottom nav | Low usage; keep available via dedicated screen |
| Full i18n across every screen | Sprint 7 focuses core flows first (ES/EN) |
| Online payments | Still out of scope for current MVP phase |
| Full technical rebrand (IDs/package/Firebase rename) | Deferred to dedicated migration sprint |
