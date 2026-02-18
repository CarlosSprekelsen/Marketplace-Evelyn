# Sprint 5 — Unblock Real Testing

**Goal:** A provider can register, be approved from the Flutter admin panel, and accept a real job — zero SQL commands required.

**Definition of Done:** Backend tests pass inside Docker. `flutter analyze` returns no issues. An operator can open the admin panel in the Flutter app, approve a provider, and that provider can immediately log in and see available jobs.

---

## Dev Environment

**Node.js/npm are NOT installed on the host.** The backend runs entirely inside Docker.

All `npm` commands must run inside Docker containers. The Dockerfile has three stages:
- **builder** — full deps, compiles TypeScript
- **test** — reuses builder, has jest and all dev deps
- **production** — lean image, no dev deps

**Use Docker Compose v2 syntax only:** `docker compose ...`  
Do not use legacy `docker-compose` commands (v1), as they can fail with
`KeyError: 'ContainerConfig'` during container recreation on this host.

```bash
# Run tests (uses test stage — has jest):
cd /home/carlossprekelsen/Marketplace-Evelyn
docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend
docker run --rm marketplace-test

# Run seeds / migrations (inside the production container):
docker exec infra-backend-1 npm run seed:admin
docker exec infra-backend-1 npx typeorm migration:run -d dist/data-source.js
```

To rebuild and deploy after code changes:
```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend
```

**IMPORTANT:** Never run `npm run test` inside the production container — it has no jest.

Flutter runs on the host (`flutter analyze`, `flutter build apk --release`).

---

## How to Use This File

Execute tasks in order. After each task:
1. Run the verification commands listed at the bottom of the task
2. Commit: `git commit -m "sprint5: <task description>"`
3. Only move to the next task when verification passes

Do not combine tasks. One task = one commit.

---

## Current Codebase State (read this first)

Before starting, understand what already exists. An AI agent that ignores this will break things.

**Already implemented — DO NOT recreate or overwrite:**
- `UserRole` enum in `backend/src/users/user.entity.ts` already has `CLIENT`, `PROVIDER`, `ADMIN`
- `AdminModule` at `backend/src/admin/` with full controller: `GET /admin/users`, `PATCH /admin/users/:id/verify`, `PATCH /admin/users/:id/block`, `PATCH /admin/users/:id/reset-password`, `GET /admin/service-requests`, `PATCH /admin/service-requests/:id/status`
- `AdminController` uses `JwtAuthGuard + RolesGuard` with `@Roles(UserRole.ADMIN)` — guard chain works
- `UsersService.setVerified(userId, boolean)` toggles `is_verified` on the user entity
- Flutter admin panel at `app/lib/features/admin/` with `admin_home_screen.dart` and `admin_repository.dart` — lists users, verifies/blocks providers, manages service requests
- `RegisterDto` at `backend/src/auth/dto/register.dto.ts` with `@IsIn([UserRole.CLIENT, UserRole.PROVIDER])` — ADMIN cannot self-register
- `PushNotificationsService` at `backend/src/notifications/push-notifications.service.ts` — FCM-based push notifications (no module file, injected directly in ServiceRequestsModule)
- Address picker widget at `app/lib/features/client/addresses/address_picker_widget.dart` — ChoiceChip selector with saved addresses + "Nueva" button
- `user_addresses` table with `latitude`/`longitude` decimal(10,7) nullable columns
- `address_id` optional field on `CreateServiceRequestDto` and `CreateRecurringRequestDto` — backend resolves saved address when provided
- `url_launcher` package already in `app/pubspec.yaml`
- `seed:admin` npm script in `backend/package.json` pointing to `src/seeds/admin.seed.ts` — **but the file does not exist yet**
- `.env.example` already has `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `SMTP_*`, and `GOOGLE_MAPS_API_KEY` placeholders

**Provider job flow — how it currently works:**
- `GET /service-requests/available` returns a slim DTO: `{id, district_name, hours_requested, price_total, scheduled_at, expires_at, time_remaining_seconds}` — NO address, NO client info (by design: privacy until accepted)
- `POST /service-requests/:id/accept` checks `is_verified`, `is_blocked`, `is_available`, same district
- `findAssignedForProvider` returns full entity with address fields + district relation, but NOT client relation
- Provider screens: `available_jobs_screen.dart` (card list with accept button), `my_jobs_screen.dart` (card list with start/complete/cancel, client phone shown)

---

## Task 5.1 — Create admin seed script

**Files to create:**
- `backend/src/seeds/admin.seed.ts` — new file (the npm script already references it)

**What to implement:**

Create an idempotent seed that:
- Initializes the TypeORM `AppDataSource` (same pattern as existing `backend/src/seeds/seed.ts`)
- Reads `ADMIN_EMAIL` and `ADMIN_PASSWORD` from environment (with `dotenv` config loaded)
- Checks if a user with that email already exists
- If not, creates one with: `role = ADMIN`, `is_verified = true`, `is_blocked = false`, `district_id` = first district in DB (admin needs a district because the column is NOT NULL)
- Hashes password with bcrypt (salt rounds = 10, same as `UsersService.create`)
- Logs "Admin user created" or "Admin user already exists"
- Destroys the data source connection before exiting

**DO NOT:**
- Modify the `UserRole` enum (ADMIN already exists)
- Create a separate `enums/` directory
- Touch `RegisterDto` (ADMIN registration is already blocked)
- Create a `run-seeds.ts` orchestrator (not needed — `npm run seed:admin` runs the file directly)

**Verification:**
```bash
# Rebuild backend container with the new seed file:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

# Run the admin seed inside the container:
docker exec infra-backend-1 npm run seed:admin
# Expected: "Admin user created" or "Admin user already exists"

# Verify in DB:
docker exec infra-postgres-1 \
  psql -U marketplace -c "SELECT email, role, is_verified FROM users WHERE role = 'ADMIN';"
# Expected: one row with admin email, ADMIN, true

# Run tests:
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test
# Expected: all existing tests still pass
```

---

## Task 5.2 — Add "Pending Providers" filter to admin panel

**Files to edit:**
- `backend/src/admin/admin.controller.ts` — add one new endpoint
- `backend/src/users/users.service.ts` — add one new query method

**Files to edit (Flutter):**
- `app/lib/features/admin/admin_repository.dart` — add method
- `app/lib/features/admin/presentation/admin_home_screen.dart` — add pending providers tab/section

**What to implement:**

### Backend
Add a new endpoint to the **existing** `AdminController` (do NOT create a new controller):

```
GET /admin/providers/pending
- Role: ADMIN (already handled by class-level decorator)
- Returns: list of users where role=PROVIDER AND is_verified=false AND is_blocked=false
- Include relations: ['district']
- Sort: created_at ASC (oldest first = longest waiting)
```

Add to `UsersService`:
```typescript
async findPendingProviders(): Promise<User[]> {
  return this.usersRepository.find({
    where: { role: UserRole.PROVIDER, is_verified: false, is_blocked: false },
    relations: ['district'],
    order: { created_at: 'ASC' },
  });
}
```

### Flutter
Add `getPendingProviders()` to existing `AdminRepository` calling `GET /admin/providers/pending`.

In `AdminHomeScreen`, add a third tab "Pendientes" (or a badge on the Usuarios tab) that shows only pending providers with prominent "Verificar" / "Bloquear" action buttons. Reuse the existing `_toggleVerified` and `_toggleBlocked` methods.

Show a count badge: "X proveedores esperando revisión".

**DO NOT:**
- Create a new `admin.service.ts` — the controller calls `UsersService` directly (existing pattern)
- Add `verification_status` enum columns — `is_verified` boolean is the source of truth
- Create `VerificationLog` entity — out of scope for MVP; the boolean toggle is sufficient
- Replace or rename existing admin endpoints

**Verification:**
```bash
# Rebuild and restart backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

# Run tests:
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# Flutter:
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze

# Manual: register a provider, then check admin panel — provider appears in pending list
# Verify provider, check they disappear from pending, appear in verified list
```

---

## Task 5.3 — Show address on provider's accepted job cards

**Files to edit:**
- `backend/src/service-requests/service-requests.service.ts` — modify `findAssignedForProvider`
- `app/lib/features/provider/my_jobs/my_jobs_screen.dart` — show address in job cards

**What to implement:**

### Backend
In `findAssignedForProvider()` (line ~202), add `'client'` to the `relations` array so the provider sees the client's name and phone after accepting. The method currently loads `['district']` — change to `['district', 'client']`.

**Privacy note:** `findAvailableForProvider` must NOT be changed — available (pre-accept) jobs should continue to hide client info and address. Only after acceptance should the provider see where to go.

### Flutter
In `my_jobs_screen.dart`, add address display to the job card (below the existing client info section):

```
Dirección: {address_street} {address_number}
{address_floor_apt if present}
Ref: {address_reference if present}
```

Use the existing `fullAddress` getter from `ServiceRequestModel` which already concatenates the fields.

**DO NOT:**
- Add lat/lng display here (that's Task 5.5)
- Modify the available jobs screen or its backend query
- Add a new detail screen — keep the inline card layout

**Verification:**
```bash
# Rebuild and restart backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze

# Manual: accept a job as provider → card shows address and client info
```

---

## Task 5.4 — FCM push notification on provider verification

**Files to edit:**
- `backend/src/users/users.service.ts` — send push after `setVerified`
- `backend/src/users/users.module.ts` — add PushNotificationsService if not already provided
- `backend/src/service-requests/service-requests.module.ts` — check if PushNotificationsService is exported

**What to implement:**

When `setVerified(userId, true)` is called (admin approves a provider), send a push notification to that provider's FCM token:

```
Title: "Cuenta verificada"
Body: "Tu cuenta ha sido aprobada. Ya puedes ver y aceptar trabajos disponibles."
Data: { type: "ACCOUNT_VERIFIED" }
```

When `setVerified(userId, false)` (admin revokes verification):
```
Title: "Verificación revocada"
Body: "Tu verificación ha sido revocada. Contacta soporte para más información."
Data: { type: "ACCOUNT_UNVERIFIED" }
```

Use the existing `PushNotificationsService.sendToTokens()` method. If the user has no `fcm_token`, the service already handles that gracefully (returns without error).

**DO NOT:**
- Create a new email service with nodemailer — FCM push is the existing notification channel
- Create a `NotificationsModule` — `PushNotificationsService` is injected directly where needed
- Add SMTP dependencies

**Verification:**
```bash
# Rebuild and restart backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# Manual: approve a provider → check device receives push notification
# (If FCM_SERVER_KEY not configured, check container logs for "Skipping push notification"):
docker logs infra-backend-1 --tail 20
```

---

## Task 5.5 — Provider navigation deeplink (Waze/Google Maps)

**Files to edit:**
- `app/lib/features/provider/my_jobs/my_jobs_screen.dart` — add Navigate button
- `backend/src/service-requests/service-requests.service.ts` — include `user_address` lat/lng in assigned jobs response (if address_id was used)

**What to implement:**

### Backend
When a service request was created using `address_id`, the address fields are copied to the service_request row but lat/lng are NOT copied (they only live in `user_addresses`). To make lat/lng available to the provider:

Option A (simpler): Add `address_latitude` and `address_longitude` nullable decimal columns to `service_requests` entity + migration. Copy lat/lng from UserAddress during `create()` when `address_id` is provided. This way the data is self-contained.

Option B (join): In `findAssignedForProvider`, also resolve the original `user_address` if one was used. This is fragile if the address is later deleted.

**Use Option A** — add columns + migration, copy during creation.

### Flutter
On provider's accepted/in-progress job cards, add a "Navegar" button that:
1. Only appears when the job has non-null lat/lng
2. Primary: opens Waze `waze://?ll={lat},{lng}&navigate=yes`
3. Fallback: opens Google Maps `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}`
4. Use `url_launcher`'s `launchUrl` with `canLaunchUrl` to detect Waze availability

When lat/lng are null, show grey text: "Ubicación no configurada por el cliente".

**Files to create:**
- `backend/src/migrations/<timestamp>-AddAddressCoordinatesToServiceRequests.ts` — new migration adding `address_latitude` and `address_longitude` to `service_requests`

**Files to edit:**
- `backend/src/service-requests/service-request.entity.ts` — add `address_latitude` and `address_longitude` columns
- `backend/src/service-requests/service-requests.service.ts` — copy lat/lng from UserAddress in `create()`
- `backend/src/recurring-requests/recurring-requests.service.ts` — same copy in recurring create
- `app/lib/shared/models/service_request_model.dart` — add `addressLatitude` and `addressLongitude` fields + fromJson
- `app/lib/features/provider/my_jobs/my_jobs_screen.dart` — add Navigate button

**DO NOT:**
- Add `google_maps_flutter` dependency (that's Task 5.6)
- Modify the available jobs endpoint or screen
- Create a separate job detail screen — keep the inline card layout

**Verification:**
```bash
# Rebuild and restart backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

# Run migration and tests:
docker exec infra-backend-1 npx typeorm migration:run -d dist/data-source.js
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze

# Manual on physical device:
# 1. Client saves address with lat/lng pin → creates booking using that address
# 2. Provider accepts job → card shows "Navegar" button
# 3. Tap → Waze opens (or Google Maps if Waze not installed)
# 4. Job without lat/lng → shows "Ubicación no configurada por el cliente"
```

---

## Task 5.6 — Google Maps pin in Address Management

**Files to edit:**
- `app/pubspec.yaml` — add `google_maps_flutter: ^2.10.0`
- `app/android/app/src/main/AndroidManifest.xml` — add Maps API key meta-data
- `app/lib/features/client/addresses/addresses_screen.dart` — add map widget to address form

**What to implement:**

In the address form bottom sheet (`_AddressFormSheet` in `addresses_screen.dart`):

1. Add a `GoogleMap` widget below the address text fields
   - Initial position: stored lat/lng if editing, or a default center (Dubai: 25.2048, 55.2708)
   - Single draggable `Marker`
   - Map height: 200px
   - Label above: "Arrastra el pin a la ubicación exacta"
   - When marker is dragged, update internal `_lat` and `_lng` state

2. On save: include `latitude` and `longitude` in the API payload (the backend DTO and entity already accept these fields)

3. In the address card (read-only list item), if lat/lng exist, show a small static map thumbnail:
   ```
   https://maps.googleapis.com/maps/api/staticmap?center={lat},{lng}&zoom=15&size=300x150&markers={lat},{lng}&key={KEY}
   ```
   Use `Image.network` with a fallback for missing API key.

**API key setup:**
- Obtain/recover key from Google Cloud Console (`APIs & Services > Credentials`), then enable:
  - Maps SDK for Android
  - Static Maps API
- Official setup references:
  - https://developers.google.com/maps/get-started
  - https://developers.google.com/maps/flutter-package/config
  - https://cloud.google.com/billing/docs/how-to/create-billing-account
  - https://cloud.google.com/billing/docs/how-to/modify-project
  - https://cloud.google.com/docs/authentication/api-keys
- Flutter key goes in `AndroidManifest.xml` as `<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY"/>` inside `<application>`
- Use a placeholder value like `YOUR_GOOGLE_MAPS_API_KEY` with a comment to replace
- The key should be restricted by package name in Google Cloud Console (document this in a comment)
- Build APK with `--dart-define=GOOGLE_MAPS_API_KEY=<YOUR_KEY>` so static map thumbnails can render

**DO NOT:**
- Add a backend dependency on Google Maps
- Modify the address picker widget (it already works)
- Require lat/lng to be mandatory — keep them optional

**Verification:**
```bash
cd app
flutter analyze
# Expected: no issues

# Manual test (requires valid Google Maps API key in AndroidManifest.xml):
# 1. Open Address Management → tap Add
# 2. Map renders with draggable pin
# 3. Drag pin → save → reopen → pin is in saved position
# 4. Address list shows static map thumbnail for addresses with lat/lng
```

---

## Sprint 5 Final Verification

Run this sequence end-to-end before marking Sprint 5 complete:

```bash
# Backend (all commands run inside Docker):
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker stop infra-backend-1 && docker rm infra-backend-1
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d backend

docker exec infra-backend-1 npx typeorm migration:run -d dist/data-source.js
docker exec infra-backend-1 npm run seed:admin
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test
# Expected: all tests pass, admin user exists

# Flutter (runs on host):
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# End-to-end scenario (manual):
# 1. Seed admin: npm run seed:admin
# 2. Log into admin account in Flutter app → see admin panel
# 3. Register a provider via Flutter → provider appears in "Pendientes" tab
# 4. Admin taps "Verificar" → provider gets push notification
# 5. Provider logs in → sees available jobs in their district
# 6. Client creates booking with saved address (that has lat/lng)
# 7. Provider accepts → job card shows address + "Navegar" button
# 8. Provider taps "Navegar" → Waze/Maps opens with directions
# 9. Provider starts and completes job → status transitions work
# 10. At no point was a SQL command needed
```

---

## Commit Message Convention for This Sprint

```
sprint5: create admin seed script
sprint5: add pending providers filter to admin panel
sprint5: show address on provider accepted job cards
sprint5: FCM push notification on provider verification
sprint5: provider navigation deeplink (Waze/Google Maps)
sprint5: Google Maps pin in address management
```

---

## What Was Removed From the Original Sprint 5 (and why)

| Removed Task | Reason |
|---|---|
| "Add ADMIN to enum" | Already exists in `user.entity.ts` |
| "Scaffold AdminModule with ping endpoint" | Full AdminModule already exists with 6 endpoints |
| "Provider verification fields (verification_status, verified_at, verified_by)" + VerificationLog entity | Over-engineering — `is_verified` boolean already works and is checked everywhere. Adding a parallel enum creates sync bugs. Audit log can be a future task if needed. |
| "Provider verification endpoints (POST /admin/providers/:id/approve)" | `PATCH /admin/users/:id/verify` already does this. Creating parallel endpoints with different URL patterns causes confusion. |
| "Email service with nodemailer" | CLAUDE.md says NO message queues, monolith MVP. FCM push already exists and is the project's notification channel. Email can be added later when there's a real need. |
| "React admin panel (Vite + React + TypeScript)" | Flutter admin panel already exists and works. Adding a second admin UI in a different framework creates maintenance burden and contradicts the monolith approach. |
| "@nestjs/serve-static to serve React panel" | No React panel = no need for static serving. Production uses Nginx. |
| "React provider verification UI" | Flutter admin panel already has verify/block buttons. |
| "Address booking flashcard selector" | `address_picker_widget.dart` already implements this with ChoiceChip + icons + "Nueva" button. |
