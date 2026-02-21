# Sprint 6 — UX Fixes, Currency, Navigation & Web Admin Foundation

**Goal:** Fix all UX bugs found during real-device testing (Sprint 5 validation). Improve navigation, fix currency, simplify the booking form, and lay the foundation for a proper web-based admin panel.

**Definition of Done:** All 7 fix tasks verified on two physical phones. Backend tests pass inside Docker. `flutter analyze` returns no issues. Web admin panel serves locally and is accessible via VPN. APK `v1.3.0+7` built and installed on both test devices.

---

## Dev Environment

**Node.js/npm are NOT installed on the host.** The backend runs entirely inside Docker.

All `npm` commands must run inside Docker containers. The Dockerfile has three stages:
- **builder** — full deps, compiles TypeScript
- **test** — reuses builder, has jest and all dev deps
- **production** — lean image, no dev deps

**Use Docker Compose v2 syntax only:** `docker compose ...`
Do not use legacy `docker-compose` commands (v1).

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
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend
```

This pattern avoids hardcoding container names (`infra-backend-1`) and lets Compose handle container lifecycle. The `--no-deps` flag prevents restarting postgres/redis. The `--force-recreate` flag ensures the new image is used.

**IMPORTANT:** Never run `npm run test` inside the production container — it has no jest.

Flutter runs on the host (`flutter analyze`, `flutter build apk --release`).

---

## How to Use This File

Execute tasks in order. After each task:
1. Run the verification commands listed at the bottom of the task
2. Commit: `git commit -m "sprint6: <task description>"`
3. Only move to the next task when verification passes

Do not combine tasks. One task = one commit.

---

## CLAUDE.md Review (read before execution)

Before starting Sprint 6, verify that `CLAUDE.md` at the repo root is up to date. It was refreshed at the end of Sprint 5 hotfix (v1.2.3+6). Key items an AI agent MUST cross-check:

| Item in CLAUDE.md | Actual codebase state | Correct? |
|---|---|---|
| Stack: NestJS 11 | Check `backend/package.json` `@nestjs/core` version | Verify |
| Stack: Node.js 22 LTS (node:22-alpine) | Check `backend/docker/Dockerfile` FROM line | YES — upgraded from 20 in Sprint 5 |
| Expiry: "15 minutes in code" | Check line 88 in `service-requests.service.ts` | YES — Task 6.4 changes to 20 |
| `initializeWithRenderer` must NOT be called | Check `app/lib/main.dart` has no such call | YES — removed in v1.2.3 |
| `google_maps_flutter_android` >= 2.19.1 | Check `app/pubspec.lock` | YES — 2.19.0 has marker crash |
| `DropdownButtonFormField` uses `initialValue:` not `value:` | `value:` is deprecated since Flutter 3.33 | YES |
| `StateNotifier` is deprecated | Use `Notifier`/`AsyncNotifier` instead | YES — migrated in Sprint 5 |
| Docker Compose v2 only | Container names use hyphens: `infra-backend-1` | YES |
| `docker-compose.prod.yml` has no `version:` key | Removed as obsolete in compose v2 | YES |
| Data model: 6 tables | districts, users, service_requests, pricing_rules, ratings, user_addresses | YES |
| Pricing: currency column on `pricing_rules` | Does NOT exist yet — added in Task 6.1 | Task 6.1 creates it |
| FCM: legacy HTTP API | `push-notifications.service.ts` uses `fcm.googleapis.com/fcm/send` | YES — migrating to v1 is Sprint 8 |
| Admin web panel at `/admin-web/` | Does NOT exist yet — added in Task 6.7 | Task 6.7 creates it |

If any item is wrong, fix CLAUDE.md FIRST before proceeding with tasks. CLAUDE.md is the source of truth for all AI agents.

---

## Current Codebase State (read this first)

Before starting, understand what already exists. An AI agent that ignores this will break things.

**Already implemented — DO NOT recreate or overwrite:**
- `google_maps_flutter: ^2.14.2` in `app/pubspec.yaml` — interactive map works (crash fixed in v1.2.3+6 via `google_maps_flutter_android` 2.19.1)
- `main.dart` is clean — NO `initializeWithRenderer` call (legacy renderer decommissioned March 2025)
- `disableInteractiveGoogleMap` defaults to `false` in `app/lib/config/environment.dart`
- `PushNotificationsService` at `backend/src/notifications/push-notifications.service.ts` — uses FCM legacy HTTP API
- `notifyProvidersForNewRequest()` already exists as a private method in `backend/src/service-requests/service-requests.service.ts` (line ~498) — called after request creation (line ~111)
- Provider `my_jobs_screen.dart` already has a "Navegar" button with Waze/Google Maps deeplink (lines 117-140, method `_navigateTo` at line 367)
- Provider `my_jobs_screen.dart` already shows `addressLatitude`/`addressLongitude` when present
- `AddressPickerWidget` at `app/lib/features/client/addresses/address_picker_widget.dart` — ChoiceChip selector, working
- Both `ClientHomeScreen` and `ProviderHomeScreen` use `context.push()` for navigation — no `BottomNavigationBar` currently
- All routes are flat top-level `GoRoute` entries in `app/lib/core/routing/app_router.dart` — no `ShellRoute` nesting
- `AdminHomeScreen` at `app/lib/features/admin/presentation/admin_home_screen.dart` — 3 tabs (Solicitudes, Usuarios, Pendientes)
- Admin user created via `npm run seed:admin` only — no self-registration
- `url_launcher` already in `pubspec.yaml`
- Backend expiry window is **15 minutes** (line 88 in service-requests.service.ts) — CLAUDE.md says 20 min; this is a known discrepancy

**Model fields already available (no backend changes needed for most tasks):**
- `ServiceRequestModel` has: `addressStreet`, `addressNumber`, `addressFloorApt`, `addressReference`, `addressLatitude`, `addressLongitude`, `priceTotal`, `status`, `district`, `provider`, `client`
- `ServiceRequestModel.fullAddress` getter concatenates address fields
- `ServiceRequestStatus` enum: `pending`, `accepted`, `inProgress`, `completed`, `cancelled`, `expired`
- Provider relation is loaded in `findMine()` via `relations: ['district', 'provider']`

---

## Task 6.1 — Multi-currency support on pricing rules (default AED)

**Problem:** Price is shown with hardcoded `$` in some screens and missing entirely in others. The platform needs to support multiple currencies because districts may operate in different markets (UAE = AED, Europe = EUR, etc.). Currency should be configurable per pricing rule and default to AED.

**This task has 3 parts:** backend migration, backend API change, Flutter display.

### Part A — Backend: add `currency` column to `pricing_rules`

**Files to create:**
- `backend/src/migrations/<timestamp>-AddCurrencyToPricingRulesAndServiceRequests.ts` — single migration adding `currency` to both `pricing_rules` and `service_requests`

**Files to edit:**
- `backend/src/pricing/pricing-rule.entity.ts` — add `currency` column
- `backend/src/data-source.ts` — add migration import if needed (currently uses glob pattern `__dirname + '/migrations/*{.ts,.js}'` — verify it auto-discovers)

**What to implement:**

Add a `currency` column to `pricing_rules`:
```typescript
@Column({ type: 'varchar', length: 3, default: 'AED' })
currency: string;
```

- Type: `varchar(3)` — ISO 4217 currency code (AED, EUR, USD, etc.)
- Default: `'AED'` — existing rows get AED automatically via migration default
- NOT NULL with default — no existing data breaks

Migration (single file, both tables):
```typescript
public async up(queryRunner: QueryRunner): Promise<void> {
  await queryRunner.addColumn('pricing_rules', new TableColumn({
    name: 'currency',
    type: 'varchar',
    length: '3',
    default: "'AED'",
    isNullable: false,
  }));
  await queryRunner.addColumn('service_requests', new TableColumn({
    name: 'currency',
    type: 'varchar',
    length: '3',
    default: "'AED'",
    isNullable: false,
  }));
}

public async down(queryRunner: QueryRunner): Promise<void> {
  await queryRunner.dropColumn('service_requests', 'currency');
  await queryRunner.dropColumn('pricing_rules', 'currency');
}
```

### Part B — Backend: include `currency` in quote and request responses

**Files to edit:**
- `backend/src/pricing/pricing.service.ts` — include `currency` in the quote response
- `backend/src/service-requests/service-request.entity.ts` — add `currency` column (copy from pricing rule at creation time, so it's immutable per request)
- `backend/src/service-requests/service-requests.service.ts` — copy `currency` from pricing rule during `create()`

Add a `currency` column to `service_requests` entity (**same single migration file** — both columns go in one migration named `AddCurrencyToPricingRulesAndServiceRequests`):
```typescript
@Column({ type: 'varchar', length: 3, default: 'AED' })
currency: string;
```

**Important:** Use ONE migration file for both `pricing_rules.currency` and `service_requests.currency`. The migration's `up()` method should run two `addColumn()` calls. Do NOT create separate migration files for each table.

This way each service request remembers the currency it was priced in, even if the pricing rule changes later.

Update the quote endpoint response to include `currency`:
```typescript
return {
  district,
  hours,
  price_per_hour: rule.price_per_hour,
  price_total: rule.price_per_hour * hours,
  currency: rule.currency,  // <-- add this
};
```

### Part C — Flutter: display currency from backend response

**Files to edit:**
- `app/lib/shared/models/service_request_model.dart` — add `currency` field + `fromJson`
- `app/lib/shared/models/provider_available_job.dart` — add `currency` field + `fromJson` (this model is separate from `ServiceRequestModel` and used by the provider's available jobs screen)
- `app/lib/features/client/request_form/request_form_screen.dart` — use `currency` from quote response
- `app/lib/features/client/my_requests/my_requests_screen.dart` — use `currency` from request model
- `app/lib/features/client/my_requests/request_detail_screen.dart` — use `currency` from request model
- `app/lib/features/provider/available_jobs/available_jobs_screen.dart` — use `currency` from job model
- `app/lib/features/provider/my_jobs/my_jobs_screen.dart` — use `currency` from job model

**What to implement:**

1. Add `currency` field to `ServiceRequestModel`:
   ```dart
   final String currency; // e.g. 'AED', 'EUR', 'USD'
   ```
   Parse from JSON with fallback: `currency: json['currency'] ?? 'AED'`

2. Add `currency` field to `ProviderAvailableJob` (at `app/lib/shared/models/provider_available_job.dart`):
   ```dart
   final String currency;
   ```
   Parse from JSON with fallback: `currency: json['currency'] ?? 'AED'`
   This model currently has `priceTotal` but no currency — the available jobs screen needs it too.

3. Ensure the backend's `/service-requests/available` endpoint includes `currency` in its response. Check `service-requests.service.ts` — the `findAvailable()` method must select/return the `currency` column.

5. Create a format helper in `service_request_model.dart`:
   ```dart
   String formatPrice(double amount, [String currency = 'AED']) =>
       '$currency ${amount.toStringAsFixed(2)}';
   ```

6. Replace every hardcoded `$` or missing currency display across all 6 Flutter screens (5 client/provider screens + ProviderAvailableJob):
   - Request form (quote card): `formatPrice(quote.priceTotal, quote.currency)`
   - My requests list: `formatPrice(request.priceTotal, request.currency)`
   - Request detail: `formatPrice(request.priceTotal, request.currency)`
   - Available jobs: `formatPrice(job.priceTotal, job.currency)`
   - My jobs: `formatPrice(job.priceTotal, job.currency)`

**Search pattern to find all occurrences that need changing:**
```
grep -rn 'toStringAsFixed(2)' app/lib/features/
```

**DO NOT:**
- Add a localization framework (flutter_intl, intl package) — the currency code string is sufficient
- Create a separate `currencies` table — currency is a simple string column on existing tables
- Add currency conversion logic — the platform shows prices in the currency they were set in
- Validate currency codes against a list — admin sets them via web panel (Task 6.7), trust the data

**Verification:**
```bash
# Rebuild backend with migration:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend

# Run migration:
docker exec infra-backend-1 npx typeorm migration:run -d dist/data-source.js

# Verify column exists with default:
docker exec infra-postgres-1 psql -U marketplace -c "
  SELECT id, district_id, price_per_hour, currency FROM pricing_rules;"
# Expected: all rows show currency = 'AED'

# Run tests:
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# Flutter:
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# Grep to verify no remaining hardcoded "$" or "AED" in price displays:
# Search for Dart string interpolation patterns like '\$' or '$' used as currency prefix:
grep -rn 'toStringAsFixed' app/lib/features/ | grep -v 'formatPrice'
# Expected: no matches — all price formatting should go through formatPrice()
# Also manually check: no literal '$' or 'AED' strings appear next to price values in widgets

# Manual: open booking form, check quote shows "AED X.XX"
# Check all screens display currency from backend, not hardcoded
```

---

## Task 6.2 — Simplify booking form: remove redundant address fields

**Problem:** When a saved address is selected, 4 address fields (street, number, floor, reference) are shown as read-only. This is redundant — the data is already in the saved address. The form should only require selecting a saved address (or prompt to create one first).

**Files to edit:**
- `app/lib/features/client/request_form/request_form_screen.dart`

**What to implement:**

1. **Remove the 4 TextFormField widgets** for street (line ~201), number (line ~220), floor/apt (line ~239), and reference (line ~254). Also remove their controllers and state variables.

2. **When a saved address is selected via AddressPickerWidget**, show a compact read-only summary card below the picker instead:
   ```
   ┌────────────────────────────────┐
   │ 🏠 Casa                       │
   │ Calle Principal 42, Piso 3    │
   │ Dubai Marina                  │
   └────────────────────────────────┘
   ```
   Use `address.fullAddress` and `address.displayLabel` from the `UserAddress` model.

3. **If no addresses exist**, show a message: "Primero agrega una dirección" with a button that navigates to `/client/addresses`. Do NOT show the 4 address fields as a fallback — saved addresses are now required.

4. **Remove query parameter prefill for address fields** from `RequestFormScreen` constructor (`prefillAddressStreet`, `prefillAddressNumber`, `prefillAddressFloorApt`, `prefillAddressReference`). Keep only `prefillDistrictId` and `prefillHours`.

5. **Update the "retry expired" flow** in `request_detail_screen.dart` — the retry button navigates to `/client/request/new` with query params. Remove the address field query params; keep `district_id` and `hours` only.

6. **The district dropdown becomes auto-selected** from the saved address's `districtId`. When user selects an address, auto-set the district dropdown to match. Keep the dropdown visible but disabled (greyed out) so the user sees which district applies.

**DO NOT:**
- Modify the backend `CreateServiceRequestDto` — it still accepts individual address fields. The Flutter form will populate them from the selected saved address before submission.
- Remove `address_id` from the DTO — it's already optional and used to link the saved address
- Change the AddressPickerWidget itself — it already works
- Remove the addresses screen or its form — that's where users create addresses

**Verification:**
```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# Manual:
# 1. Open "Solicitar Limpieza" with no saved addresses → see "Primero agrega una dirección" message
# 2. Add an address via Addresses screen → return to booking
# 3. Select saved address → compact summary card shown, no individual address fields
# 4. District dropdown auto-selects from address
# 5. Complete booking → request created successfully with correct address data
# 6. Expire a request → tap "Reintentar" → form opens with district and hours prefilled, address must be re-selected
```

---

## Task 6.3 — Fix map pin default location: use device GPS

**Problem:** When creating a new address, the map pin defaults to Dubai center (`25.2048, 55.2708`) instead of the device's current location.

**Files to edit:**
- `app/pubspec.yaml` — add `geolocator: ^13.0.2` and `permission_handler: ^11.3.1` (or use geolocator's built-in permission handling)
- `app/lib/features/client/addresses/addresses_screen.dart` — update `_AddressFormSheetState.initState()` to request location

**What to implement:**

1. **Add `geolocator` dependency** to `pubspec.yaml` under `# Maps`:
   ```yaml
   geolocator: ^13.0.2
   ```

2. **Add Android permissions** to `app/android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```
   **Note:** This app is Android-only (no iOS target). If iOS support is added later, you would also need to add `NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist`. For now, only configure Android.

3. **In `_AddressFormSheetState.initState()`** (currently at line 358), when creating a new address (i.e., `widget.existing == null`), attempt to get the device's current position:
   ```dart
   if (widget.existing == null) {
     _fetchCurrentLocation();
   }
   ```

4. **Implement `_fetchCurrentLocation()`:**
   - Check if location services are enabled (`Geolocator.isLocationServiceEnabled()`)
   - Check/request permission (`Geolocator.checkPermission()`, `Geolocator.requestPermission()`)
   - If granted, get current position (`Geolocator.getCurrentPosition()`)
   - Update `_latitude` and `_longitude` with the device position
   - If denied or unavailable, keep the Dubai default silently (no error shown)
   - The `GoogleMap` widget will automatically show the new position because `setState` triggers rebuild

5. **Keep the existing defaults** (`_defaultLatitude`, `_defaultLongitude`) as fallback — used when editing an existing address or when location permission is denied.

**DO NOT:**
- Add background location tracking — only request location once when opening the new address form
- Add a "locate me" button (nice-to-have for a future sprint, not now)
- Make location permission mandatory — if denied, fall back to Dubai center silently
- Add `ACCESS_BACKGROUND_LOCATION` permission — not needed
- Modify the map widget behavior — it already supports dragging the pin

**Verification:**
```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# Manual on physical device with GPS enabled:
# 1. Open Addresses → tap Add → map pin centers on your current location (not Dubai)
# 2. Deny location permission when prompted → map pin falls back to Dubai center
# 3. Edit an existing address → map pin shows the saved lat/lng (not current location, not Dubai)
```

---

## Task 6.4 — Fix status display: accepted requests showing as expired

**Problem:** After a provider accepts a request, the client still sees it as "expired" in their requests list.

**Investigate first — two possible root causes:**

### Root cause A: Expiry window too short (likely)
The backend expires requests after **15 minutes** (line 88 in `service-requests.service.ts`). If a provider doesn't accept within 15 minutes, the cron job marks it expired. This is correct behavior, but may feel too short during testing.

**Check:** Run this query to see if requests are genuinely expired vs. wrongly expired:
```bash
docker exec infra-postgres-1 psql -U marketplace -c "
  SELECT id, status, created_at, expires_at, accepted_at,
         EXTRACT(EPOCH FROM (expires_at - created_at))/60 AS window_minutes
  FROM service_requests
  ORDER BY created_at DESC LIMIT 10;"
```

### Root cause B: Client polling not updating status (possible)
The client detail screen polls every 5 seconds (`request_detail_screen.dart`), and the list screen polls every 10 seconds (`my_requests_screen.dart`). If polling fails silently or the provider relation isn't populated after acceptance, the UI may show stale data.

**Check:** Verify `findMine()` in `service-requests.service.ts` loads the `provider` relation (it does — `relations: ['district', 'provider']`). Then verify the Flutter model parses `status` correctly from the JSON response.

### What to implement (based on findings):

**If root cause A (expiry too short):**
- Change the expiry window from 15 to 20 minutes in `backend/src/service-requests/service-requests.service.ts` (line 88):
  ```typescript
  // Before:
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  // After:
  const expiresAt = new Date(Date.now() + 20 * 60 * 1000);
  ```
  This aligns with the 20-minute default documented in CLAUDE.md.

**If root cause B (stale UI):**
- The client and provider run on SEPARATE devices — `ref.invalidate()` on the provider's app does NOT affect the client's app state. The client relies on periodic polling (10s in list, 5s in detail) to pick up status changes.
- Verify the client's polling actually works: check that `my_requests_screen.dart` timer fires and calls `ref.refresh()` or equivalent
- Verify the client's `ServiceRequestStatus.fromJson()` correctly maps `'ACCEPTED'` to `accepted`
- If the client poll response returns stale data, check that the backend `findMine()` query has no caching or stale read issues

**Files to edit:**
- `backend/src/service-requests/service-requests.service.ts` — fix expiry window (line 88)

**DO NOT:**
- Add WebSockets for real-time updates — polling is sufficient
- Change the `ServiceRequestStatus` enum values
- Add a new status value

**Verification:**
```bash
# Rebuild backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend

# Run tests:
cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# Check expiry window in code:
grep -n 'expiresAt' backend/src/service-requests/service-requests.service.ts
# Expected: shows 20 * 60 * 1000

# Manual E2E test:
# 1. Client creates request → status shows PENDING with ~20 min countdown
# 2. Provider accepts within 20 min → client's list updates to ACCEPTED (within 10s polling)
# 3. Wait 20+ min without accepting → request correctly shows EXPIRED
```

---

## Task 6.5 — Improve navigation: add BottomNavigationBar

**Problem:** Client and provider home screens are button-based hubs. Once a user navigates into a sub-screen (My Requests, My Jobs, etc.), they must rely on the AppBar back button or close the app. There's no persistent navigation for core sections.

**Files to edit:**
- `app/lib/features/client/presentation/client_home_screen.dart` — add BottomNavigationBar
- `app/lib/features/provider/presentation/provider_home_screen.dart` — add BottomNavigationBar
- `app/lib/core/routing/app_router.dart` — restructure client and provider routes under `StatefulShellRoute`

**What to implement:**

### Client BottomNavigationBar (3 tabs):
```
┌─────────────┬──────────────┬──────────────┐
│   🏠 Inicio  │ 📋 Solicitudes │ 📍 Direcciones │
└─────────────┴──────────────┴──────────────┘
```

| Tab | Icon | Route | Screen |
|-----|------|-------|--------|
| Inicio | `Icons.home` | `/client/home` | ClientHomeScreen (booking button + quick actions) |
| Solicitudes | `Icons.list_alt` | `/client/requests` | MyRequestsScreen |
| Direcciones | `Icons.place` | `/client/addresses` | AddressesScreen |

### Provider BottomNavigationBar (3 tabs):
```
┌──────────────┬──────────────┬──────────────┐
│   🏠 Inicio   │ 🔍 Disponibles │ 📋 Mis Trabajos │
└──────────────┴──────────────┴──────────────┘
```

| Tab | Icon | Route | Screen |
|-----|------|-------|--------|
| Inicio | `Icons.home` | `/provider/home` | ProviderHomeScreen (availability toggle + summary) |
| Disponibles | `Icons.search` | `/provider/jobs/available` | AvailableJobsScreen |
| Mis Trabajos | `Icons.work` | `/provider/jobs/mine` | MyJobsScreen |

### Router changes:
Use `StatefulShellRoute.indexedStack` from go_router for tab persistence. This preserves each tab's scroll position and state when switching between them.

Example structure for the client:
```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return ClientShell(navigationShell: navigationShell);
  },
  branches: [
    StatefulShellBranch(routes: [
      GoRoute(path: '/client/home', builder: ...),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: '/client/requests', builder: ...),
      GoRoute(path: '/client/requests/:id', builder: ...),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: '/client/addresses', builder: ...),
    ]),
  ],
)
```

Create a `ClientShell` widget that wraps the `navigationShell` child with a `Scaffold` containing the `BottomNavigationBar`. Same pattern for `ProviderShell`.

### Sub-screen navigation:
- Navigating within a branch (e.g., requests list → request detail) stays in the same tab
- The request detail screen keeps its AppBar back button to return to the list
- Booking form (`/client/request/new`) should be a push ON TOP of the shell (not a tab) so it gets a full back button

**DO NOT:**
- Add more than 3 tabs per role — keep it simple
- Add a Drawer — BottomNavigationBar is sufficient
- Move admin routes into a shell — admin panel already has its own tab bar
- Add a tab for "Recurring" — it's low usage and can stay accessible from the home screen
- Break existing deep linking (`/client/requests/:id` must still work from push notifications)

**Verification:**
```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# Manual (client):
# 1. Login as client → bottom nav visible with 3 tabs
# 2. Tap "Solicitudes" tab → see requests list
# 3. Tap a request → detail screen opens WITH back button
# 4. Back button returns to requests list (still in same tab)
# 5. Tap "Direcciones" tab → addresses screen
# 6. Tap "Inicio" tab → home screen (booking button visible)
# 7. Tap "Solicitar Limpieza" → booking form opens on top (no bottom nav)

# Manual (provider):
# 1. Login as provider → bottom nav visible with 3 tabs
# 2. Tap "Disponibles" → available jobs list
# 3. Tap "Mis Trabajos" → my jobs list with start/complete buttons
# 4. Tab switching preserves scroll position
```

---

## Task 6.6 — Verify push notifications for new job postings

**Problem:** Provider reports not receiving push notifications when a client publishes a new job. The backend code for `notifyProvidersForNewRequest()` exists and is called — the issue may be configuration or device-specific.

**Investigate first:**

1. **Check if HTTP v1 push credentials are configured in production:**
   ```bash
   docker exec infra-backend-1 printenv | grep -E 'FIREBASE_PROJECT_ID|FIREBASE_SERVICE_ACCOUNT'
   # Expected: FIREBASE_SERVICE_ACCOUNT_* vars present
   ```

2. **Check if provider has an FCM token stored:**
   ```bash
   docker exec infra-postgres-1 psql -U marketplace -c "
     SELECT id, full_name, role, fcm_token IS NOT NULL AS has_fcm_token
     FROM users WHERE role = 'PROVIDER';"
   ```

3. **Check backend logs for notification activity after creating a request:**
   ```bash
   docker logs infra-backend-1 --tail 50 | grep -i 'notif\|fcm\|push'
   ```

4. **Check the `notifyProvidersForNewRequest` method** in `backend/src/service-requests/service-requests.service.ts` — verify it:
   - Queries providers in the SAME district as the request
   - Filters for `is_verified = true` AND `is_blocked = false`
   - Filters for `fcm_token IS NOT NULL`
   - Passes tokens to `PushNotificationsService.sendToTokens()`

### What to fix (based on findings):

**If HTTP v1 credentials are missing:**
- Generate a Firebase service account JSON: Firebase Console → Project Settings → Service accounts → "Generate new private key"
- Set in `infra/.env.production`:
  - `FIREBASE_PROJECT_ID=<your_project_id>`
  - `FIREBASE_SERVICE_ACCOUNT_BASE64=<base64_of_service_account_json>`
- Rebuild backend

**If provider has no fcm_token:**
- The backend already has `PUT /auth/fcm-token` (in `auth.controller.ts` line 129) and `DELETE /auth/fcm-token` (line 146). These endpoints exist and work.
- Check if the Flutter app calls this endpoint after login. Look in `app/lib/features/auth/` for `FirebaseMessaging.instance.getToken()` and a PUT to `/auth/fcm-token`.
- If the Flutter call is missing, implement it:
  - After successful login, get FCM token via `FirebaseMessaging.instance.getToken()`
  - Send to backend via `PUT /auth/fcm-token` with body `{ "fcm_token": "<token>" }` (uses existing `SetFcmTokenDto`)
  - Do NOT create a new endpoint — use the existing one

**If notifications are sent but not received:**
- Check that `firebase_messaging` is initialized in `main.dart` or `app.module`
- Check that the device has notification permissions granted
- Check Firebase Console for delivery reports

**Files to potentially edit:**
- `backend/src/service-requests/service-requests.service.ts` — if notification query is wrong
- `app/lib/features/auth/` — if FCM token is not being sent to backend on login
- `infra/.env.production` — if HTTP v1 credentials are missing

**DO NOT:**
- Add email notifications — FCM is the notification channel
- Add WebSockets — push notifications handle this use case

**Verification:**
```bash
# Rebuild backend (if code changed):
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend

cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# E2E test with 2 phones:
# 1. Provider logged in on phone A → app in background
# 2. Client creates request on phone B in provider's district
# 3. Phone A receives push notification: "Nueva solicitud disponible"
# 4. Provider taps notification → opens available jobs list
# 5. Check logs:
docker logs infra-backend-1 --tail 50
# Note: push-notifications.service.ts now logs both successes and failures.
# HTTP v1 path logs:
#   - "FCM v1 sent. success=... failure=... total=..."
#   - per-token warnings for failed deliveries
```

### Task 6.6 Status (as of 2026-02-21)

**Status:** `PENDING (external configuration/data still required)`

**Implemented in code/infrastructure:**
- `infra/docker-compose.prod.yml` now passes `FCM_SERVER_KEY` into backend container env
- `infra/.env.production.example` now documents HTTP v1 env vars
- Backend now logs warnings when no eligible provider tokens are found
- Backend supports HTTP v1 send path via Firebase Admin SDK (`FCM v1 sent...`)

**Remaining blockers to close Task 6.6:**
- `infra/.env.production` still has no active HTTP v1 credential (`FIREBASE_SERVICE_ACCOUNT_*`)
- Current provider rows in DB still have `fcm_token = NULL` — provider app must re-login and register token via `PUT /auth/fcm-token`
- End-to-end validation with 2 physical devices still needs to be executed

**Completion criteria (must all pass):**
1. Backend has active HTTP v1 credentials (`FIREBASE_SERVICE_ACCOUNT_*`) configured
2. `SELECT ... fcm_token IS NOT NULL ... FROM users WHERE role='PROVIDER'` shows at least one `true`
3. 2-device test delivers "Nueva solicitud disponible" to provider
4. Backend logs show no FCM configuration warning for that request flow
5. Backend logs show success (`FCM v1 sent...`)

---

## Task 6.7 — Web admin panel: foundation

**Problem:** The current admin interface is in the Flutter APK — limited, requires a phone, and has weak auth (same JWT flow as mobile). A web-based admin panel is needed for:
- Pricing management (view/edit `pricing_rules`)
- User management with better overview
- Accessible from the server locally or via VPN
- Stronger auth model (session-based, not JWT)

**This is a foundation task.** It sets up the web panel structure and pricing CRUD. Full admin features will be expanded in future sprints.

**Files to create:**
- `backend/src/admin-web/` — new directory for web admin (ask user before creating)
- `backend/src/admin-web/admin-web.module.ts`
- `backend/src/admin-web/admin-web.controller.ts`
- `backend/src/admin-web/views/` — Handlebars templates (or EJS)

**What to implement:**

### Option A: Server-rendered with Handlebars (recommended for MVP)
Use `@nestjs/platform-express` with `hbs` (Handlebars) templates. This keeps the admin panel inside the existing NestJS container — no new containers, no SPA build step, no separate deployment.

1. **Install Handlebars:**
   Add `hbs` package to `backend/package.json`.

2. **Configure NestJS to serve views:**
   In `main.ts`, add:
   ```typescript
   app.setBaseViewsDir(join(__dirname, 'admin-web', 'views'));
   app.setViewEngine('hbs');
   ```

3. **Admin web routes** (separate from the API routes):
   ```
   GET  /admin-web/login          → login form
   POST /admin-web/login          → authenticate, set session cookie
   GET  /admin-web/dashboard      → overview (user counts, request stats)
   GET  /admin-web/pricing        → list all pricing rules
   POST /admin-web/pricing/:id    → update price_per_hour for a district
   GET  /admin-web/users          → user list with filters
   POST /admin-web/logout         → clear session
   ```

4. **Session-based auth** (not JWT):
   - Use `express-session` with Redis as session store (`connect-redis`)
   - Session cookie is `httpOnly`, `secure` (in production), `sameSite: strict`
   - Only ADMIN role users can log in
   - Sessions expire after 8 hours of inactivity
   - This is NOT exposed to the public API — only accessible on the server's local network or via VPN

5. **Nginx restriction:**
   Add to `infra/nginx/api.conf`:
   ```nginx
   location /admin-web/ {
       # Only allow from localhost and VPN subnet
       allow 127.0.0.1;
       allow 10.200.201.0/24;     # VPN subnet
       deny all;
       proxy_pass http://backend:3000;
   }
   ```

6. **Pricing management UI:**
   Simple table showing districts with their current `price_per_hour` and `currency`. Each row has inline edit fields. Submit updates via POST form.

   | District | Price/Hour | Currency | Min Hours | Max Hours | Action |
   |----------|-----------|----------|-----------|-----------|--------|
   | Dubai Marina | 50.00 | AED | 1 | 8 | [Save] |
   | JBR | 45.00 | AED | 1 | 8 | [Save] |

   Currency field: text input restricted to 3 uppercase letters (ISO 4217). Common values: AED, EUR, USD, GBP.

### Backend pricing endpoint:
Add to the existing `PricingController` or `AdminController`:
```
PATCH /admin/pricing-rules/:id   (role: ADMIN)
Body: { price_per_hour: number, currency?: string }
```
Validate `currency` is exactly 3 uppercase letters if provided. Use `@Matches(/^[A-Z]{3}$/)` from class-validator.

**DO NOT:**
- Create a React/Vue/Angular SPA — server-rendered templates are simpler and sufficient
- Add a separate Docker container for the admin panel
- Expose the admin panel to the public internet — restrict via Nginx
- Remove or modify the existing Flutter admin panel — it continues to work for mobile admin ops
- Add user creation/registration from the admin panel — admin is seed-only
- Add payment processing

**Verification:**
```bash
# Rebuild backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend

cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test

# Access admin panel locally on VPS:
curl -v http://localhost:3000/admin-web/login
# Expected: 200 with HTML login form

# Login (use the ADMIN_EMAIL from .env.production, default: admin@marketplace.local):
curl -c cookies.txt -X POST http://localhost:3000/admin-web/login \
  -d "email=${ADMIN_EMAIL:-admin@marketplace.local}&password=<admin_password>"
# Expected: 302 redirect to /admin-web/dashboard
# Note: admin email is set via ADMIN_EMAIL env var in admin.seed.ts, not hardcoded

# View pricing:
curl -b cookies.txt http://localhost:3000/admin-web/pricing
# Expected: 200 with HTML table of pricing rules

# Update a price:
curl -b cookies.txt -X POST http://localhost:3000/admin-web/pricing/<pricing_rule_id> \
  -d "price_per_hour=55.00"
# Expected: 302 redirect back to pricing page with updated value

# Verify Nginx restriction (from external IP):
curl https://claudiasrv.duckdns.org/admin-web/login
# Expected: 403 Forbidden
```

---

## Sprint 6 Final Verification

Run this sequence end-to-end before marking Sprint 6 complete:

```bash
# Backend:
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend

cd /home/carlossprekelsen/Marketplace-Evelyn && docker build -f backend/docker/Dockerfile --target test -t marketplace-test backend && docker run --rm marketplace-test
# Expected: all tests pass

# Flutter:
cd /home/carlossprekelsen/Marketplace-Evelyn/app
flutter analyze
# Expected: no issues

# Build APK:
flutter build apk --release
# Rename to (avoid overwrite): marketplace-evelyn-v1.3.0-build7-YYYYMMDD-HHMM.apk

# End-to-end scenario (manual, 2 phones):
# 1. Install APK on both phones
# 2. Client: login → bottom nav visible (3 tabs: Inicio, Solicitudes, Direcciones)
# 3. Client: create new address → map pin starts at current GPS location (not Dubai)
# 4. Client: tap "Solicitar Limpieza" → compact form with address picker (no redundant fields)
# 5. Client: select address → district auto-fills → see price with currency from backend (e.g. "AED 50.00")
# 6. Client: submit → request shows as PENDING with ~20 min countdown
# 7. Provider (phone B): receives push notification "Nueva solicitud disponible"
# 8. Provider: bottom nav visible (3 tabs: Inicio, Disponibles, Mis Trabajos)
# 9. Provider: tap Disponibles tab → see job with price in AED
# 10. Provider: accept → Mis Trabajos tab → job card shows address + "Navegar" button
# 11. Client: request list updates to ACCEPTED (not expired)
# 12. Provider: start → complete → client sees COMPLETED with rating prompt
# 13. Navigation: switch between tabs freely, back buttons work on detail screens
# 14. Admin: web panel accessible at http://localhost:3000/admin-web/login (on VPS)
# 15. Admin: can view and edit pricing rules (price + currency) via web panel
```

---

## Commit Message Convention for This Sprint

```
sprint6: add multi-currency support to pricing rules (default AED)
sprint6: simplify booking form — remove redundant address fields
sprint6: use device GPS for map pin default location
sprint6: fix expiry window 15 → 20 min, align with CLAUDE.md
sprint6: add BottomNavigationBar to client and provider
sprint6: verify and fix push notifications for new jobs
sprint6: web admin panel foundation with pricing management
```

---

## What Is NOT in This Sprint (future work)

| Deferred Item | Reason |
|---|---|
| Push hardening (delivery analytics/monitoring) | HTTP v1 path is already in use; improve observability in Sprint 8 |
| Full web admin (user management, request management) | Foundation only in 6.7; expand in Sprint 7 |
| "Locate me" button on map | GPS auto-centers on open; manual button is nice-to-have |
| Recurring requests in bottom nav | Low usage — stays accessible from home screen only |
| Internationalization (i18n) | Currency is per pricing rule now; full i18n (translations) deferred until multi-language need |
| Online payments | Cash/manual record per CLAUDE.md |
| Flutter admin panel deprecation | Keep both — mobile admin is useful for quick verifications on the go |

---

## Follow-up Issues Resolved (2026-02-21)

- `src/user-addresses/user-addresses.service.spec.ts` (`setDefault` path): resolved. Backend full test suite now passes (`13/13` suites, `99/99` tests) using Docker test runtime.
- Docker migration artifact cache issue: resolved in `infra/scripts/deploy.sh`. Deploy now validates that the latest `backend/src/migrations/*.ts` exists as `dist/migrations/*.js` inside `backend` container; if missing after cached build, script auto-runs `docker compose ... build --no-cache backend`, recreates backend, and re-validates before running migrations.
