# Marketplace de Limpieza por Horas

## Qué es
Marketplace on-demand de limpieza por horas. Precio fijo definido por la plataforma.
Asignación automática: primer proveedor que acepta gana (first accept wins).

## Stack
- Backend: NestJS 11 + TypeORM + PostgreSQL 15 + Redis 7
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

## Modelo de datos (base actual: 5 tablas)
- District (catálogo normalizado de distritos)
- User (roles: CLIENT, PROVIDER, ADMIN)
- ServiceRequest (estados: PENDING → ACCEPTED → IN_PROGRESS → COMPLETED | CANCELLED | EXPIRED)
- PricingRule (precio por hora por distrito)
- Rating (1-5 estrellas, solo cliente califica después de COMPLETED)

Nota evolutiva: el guardrail de "máximo 5 tablas" ya cumplió su propósito inicial. A partir de ahora, se pueden agregar tablas nuevas solo con justificación de UX validada en testing (por ejemplo, `user_addresses`).

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
- NO agregar tablas sin justificación de UX validada en testing
- NO agregar message queues (RabbitMQ, Kafka)
- NO crear abstracciones tipo "ServiceType" (solo hay limpieza)
- NO implementar pagos online (efectivo/registro manual)
- NO crear microservicios (monolito modular)
- NO aceptar distritos como texto libre (siempre FK a tabla districts)
