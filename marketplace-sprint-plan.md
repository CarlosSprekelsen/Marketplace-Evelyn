# Marketplace de Limpieza por Horas — Plan de Sprints v1.1

## Decisiones de Arquitectura

```
Stack:        NestJS 10.x + TypeScript 5.x
Runtime:      Node.js 20 LTS
ORM:          TypeORM con PostgreSQL 15
Auth:         Passport + JWT (access 30min + refresh 30 días)
Validación:   class-validator + class-transformer
Docs:         Swagger/OpenAPI automático
Background:   @nestjs/schedule (cron jobs)
Rate limit:   @nestjs/throttler
Cache:        Redis 7 (expiración + rate limiting)
Mobile:       Flutter 3.x (1 app, 2 roles)
Estado:       Riverpod
HTTP:         Dio con interceptors
Dev:          Postgres + Redis en Docker Compose; backend en host
Prod:         VPS Ubuntu 22.04 + Docker Compose completo + Nginx + Certbot
Timezone:     Siempre UTC en backend y DB. App convierte a local para display.
```

---

## Modelo de Datos (4 tablas + 1 catálogo)

### District (catálogo normalizado)
```sql
id (UUID, PK)
name (varchar, unique, not null)       -- "Dubai Marina", "JBR", etc.
is_active (boolean, default true)
created_at (timestamp)
```

### User
```sql
id (UUID, PK)
email (varchar, unique, not null)
password_hash (varchar, not null)
role (enum: CLIENT, PROVIDER, ADMIN)
full_name (varchar, not null)
phone (varchar, not null)
district_id (UUID, FK → District, not null)  -- distrito principal del proveedor
is_verified (boolean, default false)
is_blocked (boolean, default false)
refresh_token_hash (varchar, nullable)
created_at (timestamp)
updated_at (timestamp)
```

### ServiceRequest
```sql
id (UUID, PK)
client_id (UUID, FK → User, not null)
provider_id (UUID, FK → User, nullable)
district_id (UUID, FK → District, not null)
address_detail (text, not null)
hours_requested (integer, not null)          -- 1-8
price_total (decimal, not null)
scheduled_at (timestamp, not null)           -- siempre UTC
status (enum: PENDING, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED, EXPIRED)
accepted_at (timestamp, nullable)
started_at (timestamp, nullable)
completed_at (timestamp, nullable)
cancelled_at (timestamp, nullable)
cancelled_by (UUID, FK → User, nullable)
cancelled_by_role (varchar, nullable)        -- CLIENT, PROVIDER, ADMIN
cancellation_reason (text, nullable)         -- obligatorio si se cancela
expires_at (timestamp, not null)
created_at (timestamp)
updated_at (timestamp)
-- índice: (status, expires_at) para el cron de expiración
```

### PricingRule
```sql
id (UUID, PK)
district_id (UUID, FK → District, unique where is_active, not null)
price_per_hour (decimal, not null)
min_hours (integer, default 1)
max_hours (integer, default 8)
is_active (boolean, default true)
created_at (timestamp)
updated_at (timestamp)
```

### Rating
```sql
id (UUID, PK)
service_request_id (UUID, FK → ServiceRequest, unique, not null)
client_id (UUID, FK → User, not null)
provider_id (UUID, FK → User, not null)
stars (integer, not null)                    -- 1-5
comment (text, nullable, max 500)
created_at (timestamp)
```

---

## Estados y Transiciones

```
PENDING → ACCEPTED       (proveedor acepta)
PENDING → EXPIRED        (timeout 5 min sin aceptación)
PENDING → CANCELLED      (cliente o admin)
ACCEPTED → IN_PROGRESS   (proveedor inicia)
ACCEPTED → CANCELLED     (cliente, proveedor asignado, o admin)
IN_PROGRESS → COMPLETED  (proveedor completa)
IN_PROGRESS → CANCELLED  (solo admin)
```

---

## Patrón "First Accept Wins"

UPDATE condicional atómico (sin SELECT FOR UPDATE):

```sql
UPDATE service_requests
SET provider_id = $1,
    status = 'ACCEPTED',
    accepted_at = NOW()
WHERE id = $2
  AND status = 'PENDING'
  AND expires_at > NOW()
  AND provider_id IS NULL
RETURNING id;
```

Si retorna fila → el proveedor ganó la asignación.
Si no retorna fila → ya fue tomado o expiró → ConflictException.

En TypeORM:
```typescript
const result = await manager
  .createQueryBuilder()
  .update(ServiceRequest)
  .set({ providerId: providerId, status: Status.ACCEPTED, acceptedAt: new Date() })
  .where('id = :id', { id })
  .andWhere('status = :status', { status: Status.PENDING })
  .andWhere('expiresAt > :now', { now: new Date() })
  .andWhere('providerId IS NULL')
  .execute();

if (result.affected === 0) {
  throw new ConflictException('Request not available');
}
```

---

## Estructura del Mono-repo

```
marketplace/
├── CLAUDE.md
├── README.md
├── .gitignore
├── .eslintrc.js
├── .prettierrc
├── backend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── nest-cli.json
│   ├── .env.example
│   ├── docker-compose.dev.yml       ← solo Postgres + Redis
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   ├── config/
│   │   │   └── configuration.ts
│   │   ├── auth/
│   │   │   ├── auth.module.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── jwt.strategy.ts
│   │   │   ├── jwt-auth.guard.ts
│   │   │   ├── jwt-refresh.strategy.ts
│   │   │   ├── roles.guard.ts
│   │   │   ├── roles.decorator.ts
│   │   │   └── dto/
│   │   ├── users/
│   │   │   ├── users.module.ts
│   │   │   ├── users.service.ts
│   │   │   ├── user.entity.ts
│   │   │   └── dto/
│   │   ├── districts/
│   │   │   ├── districts.module.ts
│   │   │   ├── districts.service.ts
│   │   │   └── district.entity.ts
│   │   ├── service-requests/
│   │   │   ├── service-requests.module.ts
│   │   │   ├── service-requests.controller.ts
│   │   │   ├── service-requests.service.ts
│   │   │   ├── service-request.entity.ts
│   │   │   ├── expiration.service.ts
│   │   │   └── dto/
│   │   ├── ratings/
│   │   │   ├── ratings.module.ts
│   │   │   ├── ratings.controller.ts
│   │   │   ├── ratings.service.ts
│   │   │   ├── rating.entity.ts
│   │   │   └── dto/
│   │   ├── pricing/
│   │   │   ├── pricing.module.ts
│   │   │   ├── pricing.controller.ts
│   │   │   ├── pricing.service.ts
│   │   │   ├── pricing-rule.entity.ts
│   │   │   └── dto/
│   │   └── common/
│   │       ├── filters/
│   │       ├── interceptors/
│   │       └── decorators/
│   └── test/
├── app/
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/
│   │   ├── core/
│   │   │   ├── api/
│   │   │   │   ├── dio_client.dart
│   │   │   │   └── interceptors/
│   │   │   ├── storage/
│   │   │   └── routing/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── client/
│   │   │   │   ├── request_form/
│   │   │   │   ├── my_requests/
│   │   │   │   └── rating/
│   │   │   └── provider/
│   │   │       ├── available_jobs/
│   │   │       └── my_jobs/
│   │   └── shared/
│   │       ├── models/
│   │       └── widgets/
│   └── android/
└── infra/
    ├── nginx/
    │   └── api.conf
    ├── scripts/
    │   ├── setup-vps.sh
    │   ├── deploy.sh
    │   └── backup-db.sh
    └── docker-compose.prod.yml
```

---

## CLAUDE.md (copiar a raíz del repo)

```markdown
# Marketplace de Limpieza por Horas

## Qué es
Marketplace on-demand de limpieza por horas. Precio fijo definido por la plataforma.
Asignación automática: primer proveedor que acepta gana (first accept wins).

## Stack
- Backend: NestJS 10 + TypeORM + PostgreSQL 15 + Redis 7
- Mobile: Flutter 3 con Riverpod + Dio
- Infra prod: VPS Ubuntu + Docker Compose + Nginx

## Reglas de negocio críticas
1. Precio lo define la plataforma (tabla PricingRule por distrito)
2. No hay negociación ni pujas
3. First accept wins: UPDATE condicional atómico (sin SELECT FOR UPDATE)
4. Requests PENDING expiran en 5 minutos
5. Solo 1 proveedor por trabajo
6. Matching = filtro por district_id (FK, no string libre)
7. Distritos son un catálogo cerrado (tabla districts). El cliente elige de un dropdown.

## Modelo de datos (5 tablas)
- District (catálogo normalizado de distritos)
- User (roles: CLIENT, PROVIDER, ADMIN)
- ServiceRequest (estados: PENDING → ACCEPTED → IN_PROGRESS → COMPLETED | CANCELLED | EXPIRED)
- PricingRule (precio por hora por distrito)
- Rating (1-5 estrellas, solo cliente califica después de COMPLETED)

## Transiciones de estado permitidas
- PENDING → ACCEPTED | EXPIRED | CANCELLED
- ACCEPTED → IN_PROGRESS | CANCELLED
- IN_PROGRESS → COMPLETED | CANCELLED (solo admin)

## Auth
- Access token JWT: 30 minutos
- Refresh token: 30 días, hasheado en DB (user.refresh_token_hash)
- Endpoint POST /auth/refresh para renovar access token
- Dio interceptor en Flutter: auto-refresh en 401

## Timezone
- Backend y DB siempre en UTC
- La app Flutter convierte a hora local solo para display

## Convenciones backend
- ESLint + Prettier configurados
- DTOs con class-validator para toda entrada
- Guards: JwtAuthGuard + RolesGuard en todo endpoint protegido
- Servicios inyectados por constructor
- Errores: ConflictException, ForbiddenException, BadRequestException, NotFoundException
- Rate limiting con @nestjs/throttler
- Tests: al menos happy path + caso de error por endpoint
- Índice en service_requests(status, expires_at) para el cron de expiración

## Convenciones Flutter
- Feature-first folder structure
- Riverpod para estado (StateNotifier o AsyncNotifier)
- Dio con interceptors: JWT auto-attach, 401 auto-refresh, retry
- flutter_secure_storage para tokens
- go_router con guards de ruta por rol

## NO hacer (guardrails MVP)
- NO agregar WebSockets (polling es suficiente)
- NO agregar PostGIS (matching por district_id)
- NO crear más de 5 tablas
- NO agregar message queues (RabbitMQ, Kafka)
- NO crear abstracciones tipo "ServiceType" (solo hay limpieza)
- NO implementar pagos online (efectivo/registro manual)
- NO crear microservicios (monolito modular)
- NO aceptar distritos como texto libre (siempre FK a tabla districts)
```

---

## Sprint 0 [DONE]— Scaffolding & Setup (1-2 días)

**Objetivo:** Repo funcional con backend que levanta, conecta a PostgreSQL/Redis, y responde en /health.

### Tareas para Claude Code

```
Tarea 0.1: Inicializar mono-repo
- Crear estructura de carpetas según el árbol definido en el plan
- Crear .gitignore (node_modules, .env, dist, build, .dart_tool, etc.)
- Crear CLAUDE.md con el contenido especificado en el plan
- Crear README.md con descripción del proyecto y cómo correr localmente
- Configurar ESLint + Prettier con reglas de NestJS
```

```
Tarea 0.2: Scaffold backend NestJS
- npx @nestjs/cli new backend --package-manager npm --skip-git
- Configurar TypeORM con PostgreSQL en app.module.ts
- Configurar Redis connection
- Crear configuration.ts con ConfigModule (@nestjs/config)
- Variables: DATABASE_URL, REDIS_URL, JWT_SECRET, JWT_EXPIRES_IN,
  JWT_REFRESH_SECRET, JWT_REFRESH_EXPIRES_IN
- Crear .env.example con todas las variables
- Endpoint GET /health que retorne { status: 'ok', timestamp }
- Configurar Swagger en main.ts
- Configurar @nestjs/throttler con defaults globales
```

```
Tarea 0.3: Docker Compose para desarrollo (solo DB)
- backend/docker-compose.dev.yml con:
  - postgres:15-alpine (puerto 5432, volumen persistente)
  - redis:7-alpine (puerto 6379)
- El backend corre fuera de Docker en dev (npm run start:dev)
```

```
Tarea 0.4: Crear las 5 entidades con migraciones
- district.entity.ts: id (UUID), name (unique), is_active, created_at
- user.entity.ts: id, email, password_hash, role (enum), full_name, phone,
  district_id (FK → District), is_verified, is_blocked, refresh_token_hash,
  created_at, updated_at
- service-request.entity.ts: todos los campos del modelo de datos.
  Índice en (status, expires_at)
- pricing-rule.entity.ts: con unique constraint en district_id donde is_active=true
- rating.entity.ts: con unique constraint en service_request_id
- Generar migración inicial
- Crear seed script: 5 distritos + 3 PricingRules de ejemplo
```

```
Tarea 0.5: Scaffold Flutter app
- flutter create app --org com.evelyn.marketplace
- Agregar dependencias: dio, flutter_riverpod, flutter_secure_storage, go_router
- Crear estructura de carpetas feature-first
- Crear DioClient con baseUrl configurable (env variable)
- Crear pantalla placeholder de login
- Verificar que compila en Android
```

### Verificación Sprint 0
```bash
cd backend && docker compose -f docker-compose.dev.yml up -d  # Postgres + Redis
npm run start:dev
# → http://localhost:3000/health retorna 200
# → http://localhost:3000/api/docs carga Swagger
# → Tablas creadas en PostgreSQL
# → Seed: distritos y pricing rules insertados

cd app && flutter run  # compila y muestra login placeholder
```

---

## Sprint 1 [DONE]— Auth completo con Refresh Token (2-3 días)

**Objetivo:** Registro, login, refresh token, JWT funcional end-to-end.

### Tareas para Claude Code

```
Tarea 1.1: Módulo de autenticación backend
- POST /auth/register: email, password, full_name, phone, role, district_id
  - Validar email único
  - Validar district_id existe y está activo
  - Hashear password con bcrypt
  - Generar access token (30 min) + refresh token (30 días)
  - Hashear refresh token y guardar en user.refresh_token_hash
  - Retornar { access_token, refresh_token, user }
- POST /auth/login: email + password
  - Validar credenciales + is_blocked=false
  - Generar access + refresh tokens
  - Retornar { access_token, refresh_token, user }
- POST /auth/refresh: recibe refresh_token en body
  - Validar refresh token contra hash en DB
  - Generar nuevo par de tokens (rotación)
  - Retornar { access_token, refresh_token }
- POST /auth/logout: invalidar refresh token (setear hash a null)
- GET /auth/profile: retornar usuario autenticado
- jwt.strategy.ts: extraer user, validar is_blocked=false
- jwt-refresh.strategy.ts: para el endpoint /auth/refresh
- roles.decorator.ts + roles.guard.ts: @Roles('CLIENT', 'PROVIDER')
- DTOs con class-validator para cada endpoint
- Tests: registro exitoso, login exitoso, login fallido, refresh exitoso,
  refresh con token inválido, usuario bloqueado, role mismatch en endpoint protegido
```

```
Tarea 1.2: Auth en Flutter
- AuthRepository: register(), login(), refresh(), logout(), getProfile()
- AuthNotifier (Riverpod) con estados: loading, authenticated, unauthenticated, error
- Pantalla de registro:
  - Campos: email, password, nombre, teléfono, rol (toggle CLIENT/PROVIDER)
  - Dropdown de distritos (GET /districts lista de distritos activos)
- Pantalla de login: email + password
- Guardar access_token + refresh_token en flutter_secure_storage
- DioInterceptor:
  - Adjuntar Bearer token a cada request
  - En 401 → intentar refresh automáticamente
  - Si refresh falla → logout y navegar a login
- go_router: guards de ruta según rol
  - Sin token → login
  - CLIENT → home cliente
  - PROVIDER → home proveedor
- Manejar errores de red con mensajes claros
```

### Verificación Sprint 1
```bash
# Registro
curl -X POST localhost:3000/auth/register -H "Content-Type: application/json" \
  -d '{"email":"test@mail.com","password":"123456","full_name":"Test User","phone":"999","role":"CLIENT","district_id":"<UUID>"}'
# → 201 con { access_token, refresh_token, user }

# Login
curl -X POST localhost:3000/auth/login ...
# → 200 con tokens

# Refresh
curl -X POST localhost:3000/auth/refresh -d '{"refresh_token":"..."}'
# → 200 con nuevos tokens

# Flutter: registro → login → home según rol → cerrar app → reabrir → auto-refresh → sigue logueado
```

---

## Sprint 2 [DONE]— Crear Solicitud + Pricing (2-3 días)

**Objetivo:** Cliente elige distrito del catálogo, ve precio cotizado, y crea solicitud.

### Tareas para Claude Code

```
Tarea 2.1: Endpoints de distritos y pricing
- GET /districts: retornar distritos activos (id, name)
- GET /pricing/quote?district_id=<UUID>&hours=3
  - Buscar PricingRule activa para el distrito
  - Validar hours entre min_hours y max_hours
  - Retornar { district, hours, price_per_hour, price_total }
  - Si no hay regla → BadRequestException
- Tests: quote exitoso, distrito sin pricing, horas fuera de rango
```

```
Tarea 2.2: Service requests — crear y consultar
- POST /service-requests (role: CLIENT)
  - Recibir: district_id, address_detail, hours_requested, scheduled_at (UTC)
  - Validar district_id existe
  - Calcular precio con PricingService
  - Validar scheduled_at es futuro
  - Crear con status=PENDING, expires_at=now()+5min
  - Retornar request con precio y datos del distrito
- GET /service-requests/mine (role: CLIENT)
  - Requests del cliente, ordenadas por created_at DESC
- GET /service-requests/:id (role: CLIENT dueño o PROVIDER asignado)
- CreateServiceRequestDto:
  - district_id: @IsUUID()
  - hours_requested: @IsInt(), @Min(1), @Max(8)
  - scheduled_at: @IsDateString() + validación custom "debe ser futuro"
  - address_detail: @IsNotEmpty(), @MaxLength(500)
- Tests: crear exitoso, distrito inválido, horas fuera de rango, fecha pasada
```

```
Tarea 2.3: Expiración automática
- expiration.service.ts con @Cron('*/1 * * * *')
- UPDATE service_requests SET status='EXPIRED'
  WHERE status='PENDING' AND expires_at < NOW()
- Loggear cantidad de requests expiradas
- El índice (status, expires_at) creado en Sprint 0 optimiza esta query
```

```
Tarea 2.4: Flujo de solicitud en Flutter (cliente)
- Pantalla "Solicitar Limpieza":
  - Dropdown de distritos (GET /districts)
  - Campo dirección detallada (texto libre)
  - Selector de horas (1-8)
  - DateTimePicker para fecha/hora (muestra hora local, envía UTC)
  - Botón "Ver Precio" → GET /pricing/quote → muestra precio
  - Botón "Confirmar Solicitud" → POST /service-requests
- Pantalla "Mi Solicitud" (detalle):
  - Estado actual, precio, dirección, fecha (en hora local)
  - Si PENDING: countdown del tiempo restante (5 min)
  - Si ACCEPTED: nombre y teléfono del proveedor
- Pantalla "Mis Solicitudes" (historial):
  - Lista con estado (chip de color), fecha, precio, distrito
  - Tap → navegar a detalle
```

### Verificación Sprint 2
```bash
# Quote
curl "localhost:3000/pricing/quote?district_id=<UUID>&hours=3"
# → { price_per_hour: 15, price_total: 45 }

# Crear solicitud
curl -X POST localhost:3000/service-requests \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"district_id":"<UUID>","address_detail":"Calle 1 #23","hours_requested":3,"scheduled_at":"2026-03-01T10:00:00Z"}'
# → 201 con precio calculado

# Esperar 5 min → status cambia a EXPIRED
```

---

## Sprint 3 [DONE]— Matching + First Accept Wins (3-4 días)

**Objetivo:** Proveedor ve trabajos de su distrito y acepta con asignación atómica.

### Tareas para Claude Code

```
Tarea 3.1: Endpoints de proveedor
- GET /service-requests/available (role: PROVIDER)
  - Filtrar: district_id = provider.district_id, status=PENDING, expires_at > now()
  - Ordenar: created_at ASC (FIFO)
  - Limitar: 10 resultados
  - Retornar: id, district name, hours, price_total, scheduled_at, tiempo restante
  - NO retornar datos del cliente (dirección, teléfono)

- POST /service-requests/:id/accept (role: PROVIDER)
  - UPDATE condicional atómico (no SELECT FOR UPDATE):
    UPDATE service_requests
    SET provider_id=$1, status='ACCEPTED', accepted_at=NOW()
    WHERE id=$2 AND status='PENDING' AND expires_at > NOW() AND provider_id IS NULL
  - Validar antes: proveedor mismo distrito, is_verified=true, is_blocked=false
  - Si affected=0 → ConflictException "Ya fue tomado o expiró"
  - Si affected=1 → retornar request completa (ahora con datos del cliente)
  - Tests de concurrencia: 2 proveedores aceptando simultáneamente,
    solo 1 gana, el otro recibe ConflictException
```

```
Tarea 3.2: Vista de proveedor en Flutter
- Pantalla "Trabajos Disponibles":
  - Polling con Timer.periodic (10s inicial, backoff a 60s si lista vacía)
  - Lista de cards: distrito, horas, precio, fecha, countdown de expiración
  - Botón "Aceptar" por card
  - Al aceptar:
    - Éxito → navegar a "Mis Trabajos" con snackbar de confirmación
    - Conflict → snackbar "Ya fue tomado" + refrescar lista automáticamente
  - Pull-to-refresh manual
  - Estado vacío: "No hay trabajos disponibles en tu zona"

- Pantalla "Mis Trabajos":
  - Lista de jobs asignados
  - Filtro por estado: ACCEPTED | IN_PROGRESS | COMPLETED
```

```
Tarea 3.3: Actualizar vista de cliente
- En "Mi Solicitud" cuando status=PENDING:
  - Polling cada 5s para detectar cambio de estado
  - ACCEPTED → mostrar nombre y teléfono del proveedor
  - EXPIRED → mensaje "Nadie aceptó. Intenta de nuevo." con botón para crear nueva
  - Detener polling cuando estado no sea PENDING
```

### Verificación Sprint 3
```bash
# Registrar 2 proveedores del mismo distrito
# Crear solicitud como cliente en ese distrito
# Proveedor 1 acepta → éxito
# Proveedor 2 acepta la misma → ConflictException
# Cliente ve datos del proveedor 1

npm run test -- --grep "concurrent accept"  # test de concurrencia pasa
```

---

## Sprint 4 [DONE]— Ejecución + Rating + Cancelación (2-3 días)

**Objetivo:** Flujo completo: aceptar → iniciar → completar → calificar. Cancelación en cualquier punto válido.

### Tareas para Claude Code

```
Tarea 4.1: Transiciones de estado
- PUT /service-requests/:id/start (role: PROVIDER asignado)
  - Validar: status=ACCEPTED, provider_id=current user
  - Cambiar a IN_PROGRESS, setear started_at

- PUT /service-requests/:id/complete (role: PROVIDER asignado)
  - Validar: status=IN_PROGRESS, provider_id=current user
  - Cambiar a COMPLETED, setear completed_at

- PUT /service-requests/:id/cancel
  - Requiere: cancellation_reason (obligatorio, @IsNotEmpty)
  - Lógica de permisos:
    - PENDING: cliente o admin
    - ACCEPTED: cliente, proveedor asignado, o admin
    - IN_PROGRESS: solo admin
  - Setear: cancelled_at, cancelled_by, cancelled_by_role, cancellation_reason
  - Rechazar transiciones inválidas con BadRequestException

- Tests por cada transición válida + cada transición inválida
```

```
Tarea 4.2: Ratings
- POST /service-requests/:id/rating (role: CLIENT)
  - Validar: status=COMPLETED, client_id=current user
  - Validar: no existe rating previo para este service_request_id
  - Recibir: stars (1-5), comment (opcional, max 500 chars)
  - Crear Rating

- GET /providers/:id/ratings (público o autenticado)
  - Retornar: lista de ratings + promedio + conteo total

- Tests: calificar exitoso, calificar sin completar, calificar dos veces
```

```
Tarea 4.3: Flujo completo en Flutter
- Provider — "Mis Trabajos":
  - Card ACCEPTED: botones "Iniciar Servicio" + "Cancelar"
  - Card IN_PROGRESS: botón "Completar Servicio"
  - Dialog de confirmación antes de cada acción
  - "Cancelar" abre campo de motivo (obligatorio) antes de enviar

- Client — "Mi Solicitud":
  - COMPLETED → pantalla de rating:
    - Widget de estrellas (1-5, tocables)
    - Campo de comentario opcional
    - Botón "Enviar Calificación"
  - PENDING o ACCEPTED → botón "Cancelar" con campo de motivo obligatorio
  - Mostrar rating promedio del proveedor cuando está asignado
```

### Verificación Sprint 4
```bash
# Flujo completo E2E:
# 1. Cliente crea solicitud → PENDING
# 2. Proveedor acepta → ACCEPTED
# 3. Proveedor inicia → IN_PROGRESS
# 4. Proveedor completa → COMPLETED
# 5. Cliente califica 5 estrellas → Rating creado
# 6. GET /providers/:id/ratings → promedio 5.0

# Cancelaciones:
# Cliente cancela PENDING → ok (con motivo)
# Cliente cancela IN_PROGRESS → rechazado
# Proveedor cancela ACCEPTED → ok (con motivo)
# Calificar ACCEPTED → rechazado
# Calificar dos veces → rechazado
```

---

## Sprint 5 [DONE]— Hardening + Deploy a VPS (3-4 días)

**Objetivo:** Backend en producción con HTTPS. App distribuible como APK.

### Tareas para Claude Code

```
Tarea 5.1: Hardening backend
- @nestjs/throttler configurado por ruta:
  - /auth/login y /auth/register: 5 req/minuto por IP
  - APIs generales: 60 req/minuto por usuario
- Logging estructurado con Winston:
  - Interceptor que genera request_id único por request
  - Log de cada request: method, url, status, duration, request_id
  - Niveles: info (requests), warn (rate limit, token refresh fail), error (exceptions)
- Helmet para headers de seguridad
- CORS configurado (origins de producción)
- Validar is_blocked en JwtStrategy (cada request)
- ExceptionFilter global:
  - Formato consistente: { statusCode, message, error, request_id }
  - Sin stack traces en NODE_ENV=production
```

```
Tarea 5.2: Docker Compose producción
- backend/docker/Dockerfile:
  - Multi-stage: build con node:20 → production con node:20-alpine
  - npm ci --only=production
  - USER node (no root)
- infra/docker-compose.prod.yml:
  - postgres:15-alpine con volumen persistente + healthcheck
  - redis:7-alpine con volumen
  - backend con restart: unless-stopped, depends_on postgres healthy
  - Variables desde .env.production
- infra/nginx/api.conf:
  - Reverse proxy a backend:3000
  - Headers: X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
  - Client max body size, proxy timeouts
```

```
Tarea 5.3: Scripts de infraestructura
- infra/scripts/setup-vps.sh:
  - Crear usuario marketplace con sudo
  - Instalar Docker + Docker Compose plugin + Nginx + Certbot
  - Configurar ufw (22, 80, 443)
  - Configurar fail2ban para SSH
  - SSH hardening (deshabilitar password auth + root login)
- infra/scripts/deploy.sh:
  - git pull origin main
  - docker compose -f docker-compose.prod.yml down
  - docker compose -f docker-compose.prod.yml up -d --build
  - Esperar healthcheck de backend
  - Correr migraciones si hay pendientes
  - Verificar /health retorna 200
- infra/scripts/backup-db.sh:
  - pg_dump comprimido con timestamp
  - Retener últimos 7 backups
  - Agregar a crontab: daily a las 3 AM UTC
```

```
Tarea 5.4: Flutter release build
- Configurar signing key para Android (keystore)
- Crear config de entorno para producción (API URL = https://api.tudominio.com)
- flutter build apk --release
- Verificar que APK instala y conecta al backend de producción
```

```
Tarea 5.5: CI/CD con GitHub Actions
- .github/workflows/test.yml:
  - Trigger: push a cualquier branch
  - Backend: npm run lint && npm test
  - Flutter: flutter analyze && flutter test
- .github/workflows/deploy.yml:
  - Trigger: push a main
  - SSH al VPS → ejecutar deploy.sh
  - Notificación de resultado
```

### Verificación Sprint 5
```bash
# VPS
curl https://api.tudominio.com/health       # → 200
curl https://api.tudominio.com/api/docs      # → Swagger UI

# APK en teléfono real:
# Login → crear solicitud → proveedor acepta → completa → califica
# Todo funciona contra producción
```

---

## Sprint 6 — Testing con Usuarios Reales (5-7 días)

**Objetivo:** 10+ transacciones completas, feedback, bugs corregidos.

### Setup

```
Pre-requisitos:
- 5-10 proveedores onboarded (is_verified=true vía SQL)
- 5-10 clientes beta con APK instalado
- Google Form para feedback (link en la app o por WhatsApp)
```

### Métricas target

| Métrica | Target | Query SQL |
|---------|--------|-----------|
| Tiempo medio de aceptación | < 3 min | SELECT AVG(EXTRACT(EPOCH FROM (accepted_at - created_at)))/60 FROM service_requests WHERE accepted_at IS NOT NULL |
| Ratio asignación | > 75% | SELECT COUNT(*) FILTER (WHERE status!='EXPIRED') * 100.0 / COUNT(*) FROM service_requests |
| Tasa de completado | > 90% | SELECT COUNT(*) FILTER (WHERE status='COMPLETED') * 100.0 / COUNT(*) FROM service_requests WHERE status IN ('ACCEPTED','IN_PROGRESS','COMPLETED','CANCELLED') |
| Rating promedio | > 4.0 | SELECT AVG(stars) FROM ratings |
| Time-to-first-view | Benchmark | Medir desde logs: tiempo entre creación y primer GET /available que incluye el request |
| Crashes en happy path | 0 | Monitoreo manual + logs de error |

### Tareas (bugs y ajustes con Claude Code)

```
Durante esta semana, los prompts serán reactivos a bugs encontrados.
Ejemplo de prompt para bugfix:

"En el endpoint POST /service-requests/:id/accept, cuando dos proveedores
aceptan casi simultáneamente, el segundo recibe un 500 en vez de 409.
El error en logs es: [pegar error]. Corrige para que retorne ConflictException
con mensaje claro y agrega un test que reproduzca este caso."
```

---

## Estimación total

| Sprint | Días | Entregable |
|--------|------|------------|
| 0 — Scaffolding | 1-2 | Repo + backend levanta + Flutter compila |
| 1 — Auth + Refresh | 2-3 | Registro, login, refresh token E2E |
| 2 — Solicitudes + Pricing | 2-3 | Cliente crea solicitud con precio cotizado |
| 3 — Matching + Accept | 3-4 | First accept wins funcional |
| 4 — Lifecycle + Rating | 2-3 | Flujo completo + calificaciones |
| 5 — Hardening + Deploy | 3-4 | Producción con HTTPS + APK release |
| 6 — Beta real | 5-7 | 10+ transacciones + feedback |
| **Total** | **~4-5 semanas** | **MVP validado con datos reales** |

---

## Tips para Claude Code

1. **CLAUDE.md siempre actualizado** — Claude Code lo lee al iniciar cada sesión.
2. **Un prompt = una tarea** — No pidas "haz el Sprint 2 completo".
3. **Incluye paths de archivos** — "Edita backend/src/auth/auth.service.ts" es mejor que "edita el auth".
4. **Pide tests junto con la implementación** — "Implementa X y escribe tests para Y".
5. **Verifica después de cada tarea** — Corre los comandos de verificación antes de seguir.
6. **Si falla, pega el error completo** — Claude Code corrige mejor con el stacktrace exacto.
7. **git commit entre tareas** — Así puedes hacer rollback si algo se rompe.
8. **No pidas refactors prematuros** — Primero que funcione, después que sea bonito.
