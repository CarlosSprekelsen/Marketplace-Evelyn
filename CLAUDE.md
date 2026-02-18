# MarketPlace Evelyn — CLAUDE.md

## What This Is

On-demand cleaning services marketplace. Fixed pricing set by the platform.
Assignment model: first provider to accept a job wins (first accept wins).
Built for pilot validation — avoid over-engineering.

## Current State (post Sprint 5)

Sprints 0–5 complete. The following works end-to-end:
- Client registration, login, booking flow, request history, ratings
- Provider registration, job queue (district-filtered), accept/start/complete, cancellation
- Admin panel in Flutter: pending providers queue, verify/block actions
- Push notifications on provider verification changes (FCM channel)
- Address geolocation flow with Google Maps pin + provider navigation deeplink
- JWT auth with refresh token rotation, role guards, rate limiting
- PostgreSQL + Redis on VPS with Docker Compose, nginx reverse proxy

## Stack

- Backend: NestJS 11 + TypeORM + PostgreSQL 15 + Redis 7
- Mobile: Flutter 3 + Riverpod + Dio + go_router
- Admin panel: Flutter-based admin surface under `app/lib/features/admin/`
- Infra: VPS Ubuntu + Docker Compose + Nginx

## Data Model (current: 6 tables)

- `districts` — closed catalog, client selects from dropdown, never free text
- `users` — roles: CLIENT, PROVIDER, ADMIN
- `service_requests` — PENDING → ACCEPTED → IN_PROGRESS → COMPLETED | CANCELLED | EXPIRED
- `pricing_rules` — price per hour per district, set by platform
- `ratings` — 1–5 stars, client rates after COMPLETED, one per request
- `user_addresses` — saved addresses per client, with lat/lng for navigation

## State Transitions

```
PENDING   → ACCEPTED     (provider accepts, first-accept-wins atomic UPDATE)
PENDING   → EXPIRED      (Redis TTL expiry, 20 min default)
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
4. Expiration window: 20 minutes (configurable per district in pricing_rules or config)
5. Only one provider per job
6. Providers must have `is_verified = true` to see or accept jobs
7. Providers with `is_blocked = true` cannot log in

## Auth

- Access token: JWT, 30 min
- Refresh token: 30 days, bcrypt-hashed in `users.refresh_token_hash`
- `POST /auth/refresh` renews access token
- Flutter Dio interceptor: auto-refresh on 401
- ADMIN users created only via seed migration — no self-registration endpoint

## Backend Conventions

- DTOs with `class-validator` for all input
- Guards: `JwtAuthGuard` + `RolesGuard` on all protected endpoints
- Services injected by constructor
- Errors: `ConflictException`, `ForbiddenException`, `BadRequestException`, `NotFoundException`
- Rate limiting: `@nestjs/throttler` globally configured
- Tests: at minimum happy path + one error case per endpoint
- Index on `service_requests(status, expires_at)` for expiry cron
- All timestamps UTC in DB and backend — Flutter converts to local for display only

## Flutter Conventions

- Feature-first folder structure under `lib/features/`
- Riverpod for all state (`AsyncNotifier` preferred)
- Dio with interceptors: JWT attach, 401 auto-refresh, retry
- `flutter_secure_storage` for tokens
- `go_router` with role-based route guards
- No `localStorage` or `SharedPreferences` for sensitive data

## Build and Deployment Conventions

- Release APK files must be renamed from Flutter default `app-release.apk` to:
  `marketplace-evelyn-v<version>-build<buildNumber>-<YYYYMMDD>.apk`
- Example: `marketplace-evelyn-v1.1.0-build2-20260218.apk`
- Keep APK artifacts in `app/build/app/outputs/flutter-apk/` with the renamed filename for handoff.
- Do not deliver or reference `app-release.apk` as the final artifact name.

- Production environment must remain running after verification and deployment.
- Use `docker compose` (v2) commands only. Do not use legacy `docker-compose` (v1).
- Do NOT run `docker compose down` on production as part of routine deploy/validation.
- Rebuild/restart only the service being updated (normally `backend`) and keep `postgres`/`redis` online.
- Final step after deploy must confirm services are healthy and still running (`backend`, `postgres`, `redis`).

## Google Maps Configuration

- Android Google Map (interactive map widget) requires an API key in:
  `app/android/app/src/main/AndroidManifest.xml`
  using `com.google.android.geo.API_KEY`.
- Static map thumbnails require a build-time define:
  `--dart-define=GOOGLE_MAPS_API_KEY=<your_key>`
  because the app reads it via `String.fromEnvironment(...)`.
- Required Google Cloud APIs:
  1. Maps SDK for Android
  2. Static Maps API
- Recommended restrictions:
  1. Create one Android-restricted key for Maps SDK (package `com.marketplace` + SHA-1/SHA-256 fingerprints)
  2. Create one HTTP referrer-restricted key for Static Maps (`https://maps.googleapis.com/*`)
  3. For MVP, a single unrestricted key is acceptable only for temporary debugging
- Before release, verify no placeholder remains:
  - `YOUR_GOOGLE_MAPS_API_KEY` must not be present in final build inputs.

## Remote/ADB Caveat

- If your IDE terminal is connected to the VPS over SSH, `adb` runs on the VPS and will not see a phone plugged into your local laptop.
- For device install/logcat, run `adb` locally on the machine physically connected to the phone.

## Admin Operations (Current)

- Admin workflows currently run in Flutter under `app/lib/features/admin/`
- Auth: admin logs in via `POST /auth/login` (ADMIN role) with same mobile auth flow
- All admin API routes use `@Roles(UserRole.ADMIN)` guard
- Admin user is created via seed script only (`npm run seed:admin`) — never via public registration

## File Locations (key paths)

```
backend/src/
  auth/                     # JWT strategies, guards, auth endpoints
  users/                    # User entity and service
  service-requests/         # Booking lifecycle
  pricing/                  # Quote and pricing rules
  districts/                # District catalog
  admin/                    # (Sprint 5) Admin module — separate from auth
  notifications/            # (Sprint 6) FCM push notifications

app/lib/features/
  auth/                     # Login, register
  admin/                    # Admin dashboard (users, providers pending, requests)
  client/
    request_form/           # Booking creation
    my_requests/            # Request history and detail
    addresses/              # Address management (with Maps pin)
  provider/
    available_jobs/         # Pending jobs in district
    my_jobs/                # Accepted/in-progress/completed

infra/
  docker-compose.prod.yml
  nginx/api.conf
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
- Do NOT store JWT in localStorage in the admin panel — memory only
- Do NOT create new tables without a validated UX reason

## Red Flags (stop and ask before proceeding)

- Any suggestion to move to a separate admin microservice
- Any suggestion to use WebSockets for real-time job notifications
- Any suggestion to store lat/lng as a PostGIS geometry type
- Any migration that alters `service_requests` status enum values
- Any new endpoint that allows role escalation (e.g., a user setting their own role)
- Adding a third-party KYC API before the manual admin review flow is working
