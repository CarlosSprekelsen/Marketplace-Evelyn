# Push Notifications Guide — Marketplace Evelyn (HTTP v1 Only)

Updated: 2026-02-21

This is the practical runbook to make push notifications work for this project.
It is intentionally HTTP v1 only.

## Reality Check (No Assumptions)

Current truth:

- Firebase project exists: `marketplace-evelyn`
- FCM API exists and is enabled: `fcm.googleapis.com`
- Service account exists: `firebase-adminsdk-fbsvc@marketplace-evelyn.iam.gserviceaccount.com`
- `app/android/app/google-services.json` exists in repo
- Android Google Services Gradle plugin is already configured
- Backend has HTTP v1 code path implemented

Also true:

- Push is **not validated end-to-end yet** in your current deployment.
- It will not work until HTTP v1 credentials are correctly set in production env and provider token exists in DB.

## What Credential You Actually Need

For this backend flow, use only:

- Firebase Service Account JSON (for HTTP v1)

Important IAM concept:

- You do **not** add your personal user "inside" the Firebase service account.
- Service account (`firebase-adminsdk-...`) is an identity used by the backend.
- Your user needs permissions on the **project** to create/export a key for that service account.

Not needed for this backend flow:

- OAuth client IDs list in Google Cloud (can be empty)
- Manual OAuth access token copy/paste
- Web Push VAPID key (`BDUL...`) for Android backend sending

## Step 1 — Download Service Account JSON (Click Path)

1. Open: `https://console.firebase.google.com/`
2. Open project: `marketplace-evelyn`
3. Click gear icon next to "Project Overview"
4. Click `Project settings`
5. Open `Service accounts` tab
6. In `Firebase Admin SDK`, click `Generate new private key`
7. Confirm and download JSON file

No Google Cloud deep navigation is required for this step.

### If you see the red error banner

If Firebase shows:

`No se permite crear claves en esta cuenta de servicio...`

this is **not your mistake**. It means an organization policy is blocking key creation
(`iam.disableServiceAccountKeyCreation` / managed equivalent).

This is independent from the service account being "Habilitada".
"Enabled" service account does not mean key creation is allowed.

Then use one of these paths:

1. **Use an existing previously-downloaded JSON key** (fastest).
2. **Remove/override key-creation restriction at project level** (single-account setup), then generate one key.

Without one of those two, your backend cannot authenticate with HTTP v1 from this VPS.

### Path A — Check if you already have the JSON key

On your local machine/VPS, search for old downloads:

```bash
find ~ -type f \( -iname "*service*account*.json" -o -iname "*firebase*admin*.json" -o -iname "*marketplace-evelyn*.json" \) 2>/dev/null | head -n 30
```

If you find the correct JSON, use it directly in Step 2.

### Path B — Exact request to organization admin

Send this message to the org admin:

```text
Need temporary exception to create one service account key for project marketplace-evelyn.
Blocked by org policy: iam.disableServiceAccountKeyCreation (or managed equivalent).
Please allow key creation at project level (or for service account firebase-adminsdk-fbsvc@marketplace-evelyn.iam.gserviceaccount.com),
I will generate one key, configure FIREBASE_SERVICE_ACCOUNT_BASE64, validate FCM HTTP v1, and then we can re-enforce policy.
```

Required admin roles usually include Organization Policy Administrator and IAM permissions.

### Path C — Personal account (no organization) fix

If this project is under your personal Google account (no company org), treat yourself as project admin.
Use these exact pages with your project preselected:

1. IAM (verify your roles):  
   `https://console.cloud.google.com/iam-admin/iam?project=marketplace-evelyn`
2. Organization Policies at project scope:  
   `https://console.cloud.google.com/iam-admin/orgpolicies?project=marketplace-evelyn`

In **Organization Policies**:

1. Search for: `service account key creation`
2. Open and configure **both** policies (one by one):
   - `iam.disableServiceAccountKeyCreation` (legacy)
   - `iam.managed.disableServiceAccountKeyCreation` (managed)
3. For each policy:
   - Click `Override parent policy` / `Anular política principal`
   - Set to `Not enforced` / `No aplicada`
   - Save
4. Wait 1-2 minutes for propagation
5. Return to Firebase -> Project settings -> Service accounts
6. Click `Generar nueva clave privada` again

If the policy page is blocked or read-only:

- Your account is missing required permission (`orgpolicy.policy.set`).
- In IAM, try granting yourself this role at project scope:
  - `Organization Policy Administrator` (`roles/orgpolicy.policyAdmin`)
- Then retry the policy override steps above.

If you cannot grant that role to yourself, use Path B (admin request text).

### Path D — You cannot manage policies and you have no org admin

If you are a personal account and still cannot edit policies, the fastest unblock is:

1. Create a **new Firebase project** in your personal account.
2. Register Android app with same package: `com.evelyn.marketplace`.
3. Download new `google-services.json` and replace `app/android/app/google-services.json`.
4. In new project, go to Service Accounts and generate private key JSON.
5. Continue with Step 2 (base64 + env + backend recreate).

This avoids being blocked by inherited policy in the current project.

### Path E — Your exact Access Troubleshooter result

If Access Troubleshooter shows:

- principal: `carlos.sprekelsen@gmail.com`
- permission denied like `orgpolicy.policies.delete` (or set/update)
- `Ninguna política de permisos de IAM otorga acceso`
- `No tienes permiso para ver` deny / principal access boundary policies

then this project is effectively controlled by higher-level restrictions you cannot edit.

In that case, do not spend more time on this project policy setup.
Use Path D (new Firebase project) immediately.

## What Your Current Cloud Messaging Screen Means

From the screen you pasted:

- `API de Firebase Cloud Messaging (V1) Habilitado` -> correct
- `API de Cloud Messaging (heredada) Inhabilitado` -> correct for this MVP
- `ID del remitente 201542107167` -> normal
- Service account shown (`firebase-adminsdk-fbsvc@marketplace-evelyn.iam.gserviceaccount.com`) -> correct
- `Certificados push web` key (`BDUL...`) -> web push only, ignore for Android backend sending

So your Firebase project status is correct for HTTP v1.
Your current blocker is policy inheritance on service-account key creation.
If policy details show `iam.managed.disableServiceAccountKeyCreation` as `No aplicada` but mention legacy restriction active, the blocker is usually the inherited legacy policy (`iam.disableServiceAccountKeyCreation`).

## Step 2 — Put Credential in Production Env

On your server:

```bash
cd /home/carlossprekelsen/Marketplace-Evelyn
base64 -w 0 /path/to/firebase-service-account.json > /tmp/firebase-sa.b64
nano infra/.env.production
```

Set these lines:

```bash
FIREBASE_PROJECT_ID=marketplace-evelyn
FIREBASE_SERVICE_ACCOUNT_BASE64=<paste_content_of_/tmp/firebase-sa.b64>
```

If `base64 -w 0` is not available:

```bash
base64 /path/to/firebase-service-account.json | tr -d '\n' > /tmp/firebase-sa.b64
```

## Step 3 — Recreate Backend

```bash
cd /home/carlossprekelsen/Marketplace-Evelyn/infra
docker compose -f docker-compose.prod.yml --env-file .env.production build backend
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --no-deps --force-recreate backend
```

## Step 4 — Verify Backend Loaded HTTP v1 Credentials

```bash
docker exec infra-backend-1 printenv | grep -E '^FIREBASE_PROJECT_ID=|^FIREBASE_SERVICE_ACCOUNT'
```

Expected:

- `FIREBASE_PROJECT_ID=marketplace-evelyn`
- Non-empty `FIREBASE_SERVICE_ACCOUNT_*` variable

## Step 5 — Verify Firebase Console Status (Easy UI Check)

Open Firebase Console -> Project settings -> Cloud Messaging.

You should see:

- `API de Firebase Cloud Messaging (V1) Habilitado`
- Service account row for `firebase-adminsdk-fbsvc@marketplace-evelyn.iam.gserviceaccount.com`
- `API de Cloud Messaging (heredada) Inhabilitado` (this is fine for this MVP)

If those 3 are true, your Firebase side is correctly set for HTTP v1.

## Step 6 — Ensure Provider Token Exists

Provider must login on app and allow notifications.

Check:

```bash
docker exec infra-postgres-1 psql -U marketplace -d marketplace -c "
  SELECT id, full_name, role, fcm_token IS NOT NULL AS has_fcm_token
  FROM users
  WHERE role='PROVIDER';
"
```

Expected: at least one provider row with `has_fcm_token = t`.

## Step 7 — Final 2-Device Test

1. Phone A (provider): login and keep app in background
2. Phone B (client): create request in provider's district
3. Phone A receives `Nueva solicitud disponible`
4. Check backend logs for real send result:

```bash
docker logs infra-backend-1 --since 10m | grep -Ei 'FCM v1 sent|FCM v1 request error'
```

Expected: at least one `FCM v1 sent...` line.

## Troubleshooting (Shortest Path)

No notification and no `FCM v1 sent...` logs:

- Provider token likely missing
- Or no eligible provider in same district (verified + not blocked)

`FCM v1 request error` in logs:

- Service account credential invalid
- Regenerate JSON and repeat Step 2 + Step 3

No push popup while cleaner app is open in foreground:

- Current app handles foreground messages without system popup.
- Put provider app in background/home screen and retest for visible notification tray popup.

No Firebase prompt on phone:

- Reinstall latest APK
- Open app, login again, grant notification permission

## SHA Fingerprints (Already Generated)

Keep these for Firebase/Google API screens that request SHA keys.

Debug keystore (`~/.android/debug.keystore`):

- SHA1: `4F:CF:60:D7:3B:73:12:7B:CE:26:84:F6:7E:34:00:2A:04:1D:D0:F4`
- SHA-256: `73:5E:A2:E6:16:A1:03:4E:D7:2A:A1:46:01:76:DC:29:37:D0:0D:3E:BD:5E:9A:5D:CF:4A:06:5B:B3:B8:CC:69`

Release/upload keystore (`app/android/upload-keystore.jks`):

- SHA1: `D0:CE:08:F9:8A:56:D7:41:BE:EF:55:75:18:D9:AA:6E:28:64:C5:8B`
- SHA-256: `81:A9:18:06:A9:FD:1A:97:4B:18:25:30:F5:C9:77:45:A6:02:9E:5C:9F:75:D2:9B:39:E1:85:DD:B9:28:17:BC`

## Private Key Record (Local Only)

Use local private notes file:

- `FIREBASE_KEYS_PRIVATE.local.md`

This file is git-ignored and intended for your own secret tracking/checklist.
