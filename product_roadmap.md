# MarketPlace Evelyn — Product Roadmap: Pilot Launch Plan

**Date:** February 2026 | **Baseline:** Sprints 0–4 complete  
**Status:** Core booking flow functional. Provider verification and admin tooling are the critical gaps before any real-world pilot.

---

## 1. Immediate Blockers — What Prevents Real Testing Today

### 1.1 Provider Verification — The #1 Blocker

Providers register via the app but arrive with `is_verified = false`. The only current mechanism to flip this is a direct SQL command run over SSH on the VPS. This is not viable beyond solo internal testing.

Without a verification interface, the marketplace cannot operate: unverified providers are invisible to the job queue, and there is no workflow to review, approve, or reject applications.

**What is needed:**
- A mechanism to receive provider applications with supporting data (ID, phone, district)
- A review interface where an operator can approve or reject each provider
- Notification to the provider of the decision (email minimum, FCM push preferred)
- A basic provider profile visible to clients once verified (name, rating, district)

---

### 1.2 Address UX — Currently Broken for Real Use

The current address form in the booking flow is large, error-prone, and duplicates the Address Management screen. Three specific changes are required:

- **Flashcard selector in booking form:** Replace the expanded address form with a compact chip/dropdown showing saved address labels (e.g. *Casa — Calle 5 Norte*). Selecting it populates the booking. Tapping "Add new" navigates to the Address Management screen.
- **Eliminate free-text address entry in booking:** Address creation only happens in Address Management. The booking form only selects from verified saved addresses. This removes the main source of data errors.
- **Google Maps pin widget in Address Management:** Each address shows an embedded draggable Maps pin. The user places or corrects the pin to set `lat/lng`. This replaces manual coordinate entry and is the data source providers need to navigate.

---

### 1.3 Provider Navigation Integration

When a provider accepts a job they need to reach the client's address. Once `lat/lng` is correctly stored via the Maps pin widget, the provider's job detail screen needs a **Navigate** button that deep-links to Waze or Google Maps. This is a single-line implementation once the geo data exists.

---

## 2. Admin / Management Interface

### 2.1 Recommended Access Strategy

For a pilot of this scale, the simplest viable approach is:

- Deploy a lightweight admin web panel served from the **same NestJS backend** under `/admin`
- Restrict the `/admin` path at the **nginx level** using HTTP Basic Auth as an outer layer
- All admin API routes use a separate **ADMIN role JWT guard** as an inner layer
- The first admin user is created via a **one-time seed migration** — no admin registration endpoint is ever exposed

This requires no VPN, no separate server, and no additional infrastructure. When the operation grows, access can be migrated behind Cloudflare Zero Trust or a VPN with minimal changes.

---

### 2.2 Admin Panel — MVP Feature Set

The panel is a minimal React + Vite SPA bundled as static files and served by NestJS. No heavy UI library needed.

#### Provider Management *(Priority 1 — blocks everything)*
- Provider application list: all `PROVIDER` users with `is_verified = false`, sorted by registration date
- Provider detail view: full name, phone, email, district, registration date, uploaded documents
- Approve / Reject actions: set `is_verified = true` or `is_blocked = true`, trigger notification email
- Verified provider list: active providers per district, with block/unblock toggle

#### Client Management *(Priority 2)*
- Client list with search by name, email, phone, district
- Block / unblock a client account
- View a client's service request history

#### Operations Dashboard *(Priority 3)*
- Live view of all active service requests by status (`PENDING`, `ACCEPTED`, `IN_PROGRESS`)
- Daily metrics table per district: total completed, total cancelled, average provider rating

#### District and Pricing Management *(Priority 4)*
- View and edit active districts and pricing rules
- Activate or deactivate a district without a code deployment or SQL command

---

### 2.3 Backend Changes Required

Minimal additions to the existing NestJS backend:

- Add `ADMIN` to `UserRole` enum (seed only — never self-registrable)
- Create `AdminModule` with role-guarded endpoints for user management, district management, and metrics
- Add `verification_status` field (`PENDING | APPROVED | REJECTED`) to `User` entity alongside `is_verified`
- Add `verification_notes` field for operator rejection comments
- Add an audit log table: `(admin_id, action, target_user_id, timestamp, notes)`

---

## 3. Prioritized Feature Roadmap

| Priority | Feature | Effort | Notes |
|----------|---------|--------|-------|
| CRITICAL | Provider verification workflow — approve/reject backend | 3–4 days | Blocks all real testing |
| CRITICAL | Admin panel — provider management screens | 3–4 days | Depends on above |
| CRITICAL | Email notification to provider on verification decision | 1 day | Required for UX |
| CRITICAL | Address booking flashcard selector — no free-text in booking | 2 days | Real UX blocked |
| CRITICAL | Google Maps pin widget in Address Management | 2–3 days | Enables provider navigation |
| CRITICAL | Provider navigation deeplink — open Waze / Google Maps | 0.5 days | Depends on geo data |
| HIGH | FCM push notifications — new job available for providers | 3–4 days | Providers will not poll the app |
| HIGH | FCM push — booking status changes for clients | 1–2 days | Client retention |
| HIGH | Extend expiration window from 5 min to 15–30 min (configurable) | 0.5 days | Real market timing |
| HIGH | Provider online / offline toggle | 1 day | Controls notification spam |
| HIGH | Admin operations dashboard — live request view and metrics | 2–3 days | Operator visibility |
| HIGH | Admin — district and pricing management UI | 2 days | Removes SQL dependency |
| HIGH | Email confirmation on booking for client | 1 day | Trust and professionalism |
| HIGH | Phone number OTP validation on registration | 3–4 days | Fraud prevention |
| HIGH | Terms of service acceptance on registration | 0.5 days | Legal requirement |
| MEDIUM | Provider profile card visible to client — photo, name, rating | 2 days | Trust UX |
| MEDIUM | Client filterable request history by status | 0.5 days | Convenience |
| MEDIUM | District availability indicator — has active verified providers? | 1 day | Reduces client frustration |
| MEDIUM | Price breakdown shown before booking confirmation | 0.5 days | Transparency |
| MEDIUM | Admin — client management, block/unblock | 1 day | Moderation |
| MEDIUM | Basic KYC — provider ID document upload reviewed in admin panel | 3–4 days | Regulatory compliance |
| MEDIUM | Multi-district coverage per provider | 2–3 days | Supply scaling |
| LOW | Recurring booking templates | 4–5 days | Retention (validate demand first) |
| LOW | Odoo integration — invoice generation per completed service | 5–7 days | Back-office (post pilot only) |

---

## 4. Sprint Plan (Post Sprint 4)

### Sprint 5 — Unblock Real Testing *(~1 week)*

**Goal:** First provider can be verified and accept a real job end-to-end without any SQL commands.

- [ ] Backend: provider verification endpoints (`POST /admin/providers/:id/approve`, `POST /admin/providers/:id/reject`)
- [ ] Backend: ADMIN role seeded via migration. `AdminModule` with role guard.
- [ ] Backend: `verification_status` and `verification_notes` fields on `User`
- [ ] Backend: audit log table and service
- [ ] Backend: approval/rejection email to provider (use existing email transport)
- [ ] Admin panel: provider application list + approve/reject UI (React + Vite, served from `/admin`)
- [ ] Admin panel: nginx basic auth restriction on `/admin` path
- [ ] Flutter: address booking flashcard — replace expanded form with chip selector
- [ ] Flutter: Address Management — Google Maps draggable pin, persist `lat/lng` to backend
- [ ] Flutter: provider job detail screen — Navigate button (deep-link to Waze / Google Maps)

---

### Sprint 6 — Real-World Readiness *(~1 week)*

**Goal:** Safe to give to 5–10 real users.

- [ ] FCM push notifications: new job available (provider), status changes (client)
- [ ] Extend expiration window to 20 min, configurable per district via admin panel
- [ ] Provider online/offline toggle
- [ ] Client email confirmation on booking
- [ ] Admin dashboard: live request view, daily metrics per district
- [ ] Admin: district and pricing management (replaces all SQL operations)
- [ ] Terms of service checkbox on registration

---

### Sprint 7 — Trust and Quality *(~1 week)*

**Goal:** Professional enough for word-of-mouth growth.

- [ ] Phone OTP validation on registration
- [ ] Provider profile card visible to client when accepted (photo, name, rating)
- [ ] Basic KYC: provider uploads ID document, operator reviews in admin panel
- [ ] Price breakdown on booking confirmation screen
- [ ] Admin: client management and moderation tools
- [ ] District availability indicator

---

### Sprint 8 — Growth Features *(~2 weeks, after pilot feedback)*

Only implement what pilot data confirms users actually want.

- [ ] Recurring bookings
- [ ] Multi-district provider coverage
- [ ] Referral or promo code system
- [ ] Odoo invoice integration (scope separately based on transaction volume)

---

## 5. Google Maps Integration Notes

Two Maps APIs are required:

- **Maps JavaScript API (Flutter):** embed a draggable marker in the Address Management screen using `google_maps_flutter`. User places the pin; `lat/lng` is sent to the backend and stored on the `user_addresses` record.
- **Static Maps API (optional):** generate a small map image for the provider's job detail screen showing the client's pinned location without loading the full SDK.

**API key hygiene:** restrict by Android bundle ID and iOS bundle ID. Costs for pilot volume are negligible (well within free tier).

---

## 6. KYC by Market

| Tier | When | Approach |
|------|------|----------|
| Pilot | Now | Manual: provider uploads ID photo. Operator reviews in admin panel before approval. No third-party API. |
| Growth | Post-pilot | Integrate Stripe Identity, Jumio, or a local KYC provider. Automated liveness + document checks. |
| Scale | High volume | Automated KYC with manual exception queue. Compliance reporting for regulated markets. |

For countries with strict on-demand labor regulations, legal counsel should determine what data must be collected before providers can legally operate on the platform before the pilot goes live in those markets.

---

## 7. Long-Term Integrations

### Odoo
Once transaction volume justifies back-office tooling, use Odoo's REST API to create invoice records from completed service events. Do not build this before real volume exists.

### Multi-Vertical Expansion
The district-based, first-accept-wins model is generic. When expanding to new service categories, the primary additions are a `service_type` field on requests and category-based provider registration. The core architecture does not need to change.

---

## Immediate Next Action

> **Sprint 5, Day 1:** Seed the first ADMIN user via migration. Build `POST /admin/providers/:id/approve` and `POST /admin/providers/:id/reject`. Stand up the `/admin` static panel with the provider application list. The goal is that by end of Sprint 5, a provider can register, be approved from the web panel, and accept a real job — with zero SSH commands.