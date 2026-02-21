# MarketPlace Evelyn — CLAUDE.md

## What This Is

On-demand cleaning services marketplace. Fixed pricing set by the platform.
Assignment model: first provider to accept a job wins (first accept wins).
Built for pilot validation — avoid over-engineering.

## Current State (post Sprint 6 hotfix — v1.3.1+8)

Sprints 0–6 complete. The following works end-to-end:
- Client registration, login, booking flow, request history, ratings
- Provider registration, job queue (district-filtered), accept/start/complete, cancellation
- Admin panel in Flutter: pending providers queue, verify/block actions
- Web admin panel at `/admin-web/` with session-based auth (Redis), pricing CRUD, user list
- Push notifications on provider verification changes and new job postings (FCM HTTP v1 via Firebase Admin SDK; legacy fallback only if explicitly configured)
- Address geolocation flow with GPS auto-center + Google Maps pin + provider navigation deeplink
- Multi-currency pricing (default AED, configurable per district via web admin)
- Simplified booking form: saved address required, district auto-selected
- BottomNavigationBar for client (3 tabs) and provider (3 tabs) with StatefulShellRoute
- Request expiry window: 20 minutes (aligned with documentation)
- JWT auth with refresh token rotation, role guards, rate limiting
- PostgreSQL + Redis on VPS with Docker Compose, nginx reverse proxy

## Stack

- Backend: NestJS 11 + TypeORM + PostgreSQL 15 + Redis 7
- Runtime: Node.js 22 LTS (node:22-alpine in Docker)
- Mobile: Flutter 3.41 + Riverpod + Dio + go_router
- Admin panel: Flutter-based mobile admin under `app/lib/features/admin/` + web admin at `backend/src/admin-web/` (Handlebars + session auth)
- Infra: VPS Ubuntu + Docker Compose v2 + Nginx + Certbot

## Data Model (current: 6 tables)

- `districts` — closed catalog, client selects from dropdown, never free text
- `users` — roles: CLIENT, PROVIDER, ADMIN; has `fcm_token` for push notifications
- `service_requests` — PENDING → ACCEPTED → IN_PROGRESS → COMPLETED | CANCELLED | EXPIRED
- `pricing_rules` — price per hour per district, set by platform; currency column (default AED)
- `ratings` — 1–5 stars, client rates after COMPLETED, one per request
- `user_addresses` — saved addresses per client, with lat/lng for navigation

## State Transitions

```
PENDING   → ACCEPTED     (provider accepts, first-accept-wins atomic UPDATE)
PENDING   → EXPIRED      (cron job, @Cron('*/1 * * * *'), checks expires_at < NOW())
PENDING   → CANCELLED    (client or admin)
ACCEPTED  → IN_PROGRESS  (assigned provider starts)
ACCEPTED  → CANCELLED    (client, assigned provider, or admin)
IN_PROGRESS → COMPLETED  (assigned provider completes)
IN_PROGRESS → CANCELLED  (admin only)
```

## Business Rules

1. Pricing is set by the platform via `pricing_rules` table — no negotiation
2. First accept wins: atomic conditional UPDATE, no SELECT FOR UPDATE
3. District matching uses `district_id` FK — never string comparison
4. Expiration window: 20 minutes (line 88 in service-requests.service.ts)
5. Only one provider per job
6. Providers must have `is_verified = true` to see or accept jobs
7. Providers with `is_blocked = true` cannot log in
8. Currency is per pricing rule (default AED) — client displays currency from backend response

## Auth

- Access token: JWT, 30 min
- Refresh token: 30 days, bcrypt-hashed in `users.refresh_token_hash`
- `POST /auth/refresh` renews access token
- Flutter Dio interceptor: auto-refresh on 401
- ADMIN users created only via seed migration — no self-registration endpoint
- Web admin panel (Sprint 6): session-based auth with Redis store, restricted to VPN

## Backend Conventions

- DTOs with `class-validator` for all input
- Guards: `JwtAuthGuard` + `RolesGuard` on all protected endpoints
- Services injected by constructor
- Errors: `ConflictException`, `ForbiddenException`, `BadRequestException`, `NotFoundException`
- Rate limiting: `@nestjs/throttler` globally configured
- Tests: at minimum happy path + one error case per endpoint
- Index on `service_requests(status, expires_at)` for expiry cron
- All timestamps UTC in DB and backend — Flutter converts to local for display only
- `setVerified()` validates `role === PROVIDER` before updating; sends FCM notification
- `setBlocked()` sends FCM notification on block/unblock; guards null `fcm_token`
- Push observability is exposed to admins at `GET /ops/push-observability` (in-memory counters + recent delivery events)

## Flutter Conventions

- Feature-first folder structure under `lib/features/`
- Riverpod for all state (`Notifier`/`AsyncNotifier` — NOT deprecated `StateNotifier`)
- Dio with interceptors: JWT attach, 401 auto-refresh, retry
- `flutter_secure_storage` for tokens
- `go_router` with role-based route guards
- No `localStorage` or `SharedPreferences` for sensitive data
- Do NOT call `initializeWithRenderer` — legacy renderer decommissioned March 2025; new renderer is default
- `DropdownButtonFormField` uses `initialValue:` (NOT `value:` which is deprecated since Flutter 3.33)

## Build and Deployment Conventions

- Release APK files must be renamed from Flutter default `app-release.apk` to:
  `marketplace-evelyn-v<version>-build<buildNumber>-<YYYYMMDD>.apk`
- Example: `marketplace-evelyn-v1.2.3-build6-20260219.apk`
- Keep APK artifacts in `app/build/app/outputs/flutter-apk/` with the renamed filename for handoff.
- Do not deliver or reference `app-release.apk` as the final artifact name.

- Production environment must remain running after verification and deployment.
- Use `docker compose` (v2) commands only. Do not use legacy `docker-compose` (v1).
- Do NOT run `docker compose down` on production as part of routine deploy/validation.
- Rebuild/restart only the service being updated (normally `backend`) and keep `postgres`/`redis` online.
- Final step after deploy must confirm services are healthy and still running (`backend`, `postgres`, `redis`).
- Dockerfile has 3 stages: builder (full deps), test (has jest), production (lean).
- Container names use hyphens: `infra-backend-1`, `infra-postgres-1`, `infra-redis-1`.

### Version Policy (App)

- Source of truth: `app/pubspec.yaml` (`version: <semver>+<buildNumber>`).
- Current hotfix release target is `1.3.1+8`.
- For rebuilds of the same release (no app version change), keep `1.3.1+8` and only change APK filename date/time.
- If mobile app code changes after a released build and users must install an update, increment `buildNumber` at minimum.
- Use semver intent:
  - Patch (`x.y.z+N` -> `x.y.(z+1)+N+1`) for fixes/hotfixes.
  - Minor (`x.y.z+N` -> `x.(y+1).0+N+1`) for sprint-level feature batches.

## Google Maps Configuration

- Android Google Map (interactive map widget) requires an API key in:
  `app/android/app/src/main/AndroidManifest.xml`
  using `com.google.android.geo.API_KEY`.
- Static map thumbnails require a build-time define:
  `--dart-define=GOOGLE_MAPS_API_KEY=<your_key>`
  because the app reads it via `String.fromEnvironment(...)`.
- Do NOT call `initializeWithRenderer()` in `main.dart` — the legacy renderer was decommissioned March 2025 and calling it causes `NullPointerException` crashes on some devices.
- `google_maps_flutter_android` must be >= 2.19.1 (2.19.0 has a marker crash regression).
- Required Google Cloud APIs:
  1. Maps SDK for Android
  2. Static Maps API
- Recommended restrictions:
  1. Create one Android-restricted key for Maps SDK (package `com.evelyn.marketplace` + SHA-1/SHA-256 fingerprints)
  2. Create one HTTP referrer-restricted key for Static Maps (`https://maps.googleapis.com/*`)
  3. For MVP, a single unrestricted key is acceptable only for temporary debugging
- Before release, verify no placeholder remains:
  - `YOUR_GOOGLE_MAPS_API_KEY` must not be present in final build inputs.

### Official Setup Links

- Google Maps Platform Get Started:
  https://developers.google.com/maps/get-started
- Flutter package configuration (Google Maps for Flutter):
  https://developers.google.com/maps/flutter-package/config
- Create Cloud Billing account:
  https://cloud.google.com/billing/docs/how-to/create-billing-account
- Link/enable billing on a project:
  https://cloud.google.com/billing/docs/how-to/modify-project
- Manage payment methods / billing profile:
  https://cloud.google.com/billing/docs/how-to/manage-billing-account
- Manage API keys:
  https://cloud.google.com/docs/authentication/api-keys
- API key security best practices:
  https://developers.google.com/maps/api-security-best-practices
- Maps SDK for Android usage and billing:
  https://developers.google.com/maps/documentation/android-sdk/usage-and-billing
- Maps Static API usage and billing:
  https://developers.google.com/maps/documentation/maps-static/usage-and-billing

## Remote/ADB Caveat

- If your IDE terminal is connected to the VPS over SSH, `adb` runs on the VPS and will not see a phone plugged into your local laptop.
- For device install/logcat, run `adb` locally on the machine physically connected to the phone.

## Admin Operations (Current)

- Admin workflows currently run in Flutter under `app/lib/features/admin/`
- Auth: admin logs in via `POST /auth/login` (ADMIN role) with same mobile auth flow
- All admin API routes use `@Roles(UserRole.ADMIN)` guard
- Admin user is created via seed script only (`npm run seed:admin`) — never via public registration
- Web admin panel at `/admin-web/` (session-based with Redis, Nginx-restricted to VPN) — login, dashboard, pricing CRUD, user list

## File Locations (key paths)

```
backend/src/
  auth/                     # JWT strategies, guards, auth endpoints
  users/                    # User entity (includes UserRole enum) and service
  service-requests/         # Booking lifecycle + expiration cron
  pricing/                  # Quote and pricing rules
  districts/                # District catalog
  admin/                    # Admin API module — separate from auth
  notifications/            # FCM push notifications (HTTP v1 primary + optional legacy fallback)
  seeds/                    # admin.seed.ts (npm run seed:admin)
  admin-web/                # Web admin panel — Handlebars views, session auth
  data-source.ts            # TypeORM CLI data source (explicit entity imports)
  migrations/               # TypeORM migration files

app/lib/
  main.dart                 # Entry point — clean, NO initializeWithRenderer
  config/environment.dart   # API_BASE_URL, ENV, DISABLE_INTERACTIVE_GOOGLE_MAP
  core/routing/app_router.dart  # go_router with role guards
  features/
    auth/                   # Login, register, auth notifier (Notifier, not StateNotifier)
    admin/                  # Admin dashboard (users, providers pending, requests)
    client/
      presentation/         # ClientHomeScreen (hub with nav buttons)
      request_form/         # Booking creation
      my_requests/          # Request history and detail
      addresses/            # Address management (with Maps pin)
      recurring/            # Recurring requests
    provider/
      presentation/         # ProviderHomeScreen (hub with availability toggle)
      available_jobs/       # Pending jobs in district
      my_jobs/              # Accepted/in-progress/completed + Waze/Maps nav
  shared/models/            # User, District, ServiceRequestModel, UserAddress

infra/
  docker-compose.prod.yml   # No version: key (removed, obsolete in compose v2)
  .env.production           # Production environment variables
  nginx/api.conf            # Reverse proxy config
```

## DO NOT Do (guardrails)

- Do NOT add WebSockets — polling is sufficient for this scale
- Do NOT add PostGIS — district matching uses FK, not coordinates
- Do NOT add message queues (RabbitMQ, Kafka)
- Do NOT add microservices — modular monolith only
- Do NOT accept district as free text — always FK to `districts` table
- Do NOT implement online payments — cash or manual record only
- Do NOT add ServiceType abstraction — only cleaning for now
- Do NOT expose an ADMIN registration endpoint — seed only
- Do NOT store JWT in localStorage in the admin panel — session-based auth only
- Do NOT create new tables without a validated UX reason
- Do NOT call `initializeWithRenderer()` — causes crashes, legacy renderer is dead
- Do NOT use `StateNotifier` — use `Notifier`/`AsyncNotifier` (StateNotifier is deprecated)
- Do NOT use `value:` on `DropdownButtonFormField` — use `initialValue:` (value is deprecated)

## Red Flags (stop and ask before proceeding)

- Any suggestion to move to a separate admin microservice
- Any suggestion to use WebSockets for real-time job notifications
- Any suggestion to store lat/lng as a PostGIS geometry type
- Any migration that alters `service_requests` status enum values
- Any new endpoint that allows role escalation (e.g., a user setting their own role)
- Adding a third-party KYC API before the manual admin review flow is working
- Any call to `initializeWithRenderer` in main.dart
- Downgrading `google_maps_flutter_android` below 2.19.1
