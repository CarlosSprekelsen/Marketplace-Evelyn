# Marketplace de Limpieza por Horas

Marketplace on-demand de servicios de limpieza por horas con asignación automática de proveedores.

## Descripción

Plataforma que conecta clientes que necesitan servicios de limpieza por horas con proveedores en su zona. El precio lo define la plataforma según el distrito. La asignación es automática: el primer proveedor que acepta el trabajo lo obtiene (first accept wins).

## Características principales

- **Pricing fijo por distrito**: La plataforma define precios según zona geográfica
- **Asignación atómica**: Sistema "first accept wins" sin conflictos de concurrencia
- **Matching por distrito**: Proveedores ven solo trabajos de su zona
- **Expiración automática**: Solicitudes pendientes expiran en 5 minutos
- **Sistema de calificaciones**: Clientes califican proveedores después del servicio

## Stack tecnológico

### Backend
- **Framework**: NestJS 10.x con TypeScript 5.x
- **Runtime**: Node.js 20 LTS
- **Base de datos**: PostgreSQL 15
- **Cache**: Redis 7
- **ORM**: TypeORM
- **Autenticación**: Passport + JWT (access 30min + refresh 30 días)
- **Validación**: class-validator + class-transformer
- **Documentación**: Swagger/OpenAPI

### Mobile
- **Framework**: Flutter 3.x
- **Estado**: Riverpod
- **HTTP**: Dio con interceptors
- **Plataforma**: Android (APK)

### Infraestructura
- **Desarrollo**: PostgreSQL + Redis en Docker Compose, backend en host
- **Producción**: VPS Ubuntu 22.04 + Docker Compose + Nginx + Certbot

## Modelo de datos

El sistema utiliza 5 tablas:

1. **District**: Catálogo normalizado de distritos
2. **User**: Usuarios con roles CLIENT, PROVIDER, ADMIN
3. **ServiceRequest**: Solicitudes de servicio con estados (PENDING → ACCEPTED → IN_PROGRESS → COMPLETED)
4. **PricingRule**: Reglas de precio por hora por distrito
5. **Rating**: Calificaciones de 1-5 estrellas

## Cómo correr localmente

### Prerrequisitos

- Node.js 20 LTS
- npm
- Docker y Docker Compose
- Flutter 3.x (para la app móvil)
- PostgreSQL client (para verificar DB)

### Backend

#### Opción A: Puertos estándar (si no tienes servicios en 5432/6379)

1. **Levantar PostgreSQL y Redis**:
```bash
cd backend
docker compose -f docker-compose.dev.yml up -d
```

2. **Instalar dependencias**:
```bash
npm install
```

3. **Correr migraciones**:
```bash
npm run migration:run
```

4. **Cargar datos semilla**:
```bash
npm run seed
```

5. **Iniciar servidor de desarrollo**:
```bash
npm run start:dev
```

6. **Verificar**:
- API: http://localhost:3000/health
- Swagger: http://localhost:3000/api/docs

#### Opción B: Puertos alternativos (si tienes servicios existentes en 5432/6379)

1. **Crear archivo docker-compose.override.yml**:
```yaml
version: '3.8'

services:
  postgres:
    ports:
      - '15432:5432'
  redis:
    ports:
      - '16379:6379'
```

2. **Actualizar .env** para usar los puertos alternativos:
```bash
# En backend/.env:
DATABASE_URL=postgresql://postgres:postgres@localhost:15432/marketplace
REDIS_URL=redis://localhost:16379
```

3. **Levantar servicios**:
```bash
cd backend
docker compose -f docker-compose.dev.yml up -d
```

4. **Instalar dependencias y ejecutar**:
```bash
npm install
npm run migration:run
npm run seed
npm run start:dev
```

### App móvil (Flutter)

1. **Instalar dependencias**:
```bash
cd app
flutter pub get
```

2. **Configurar baseUrl**:
Editar `lib/config/environment.dart` con la URL del backend

3. **Correr en emulador/dispositivo**:
```bash
flutter run
```

## Estructura del proyecto

```
marketplace/
├── backend/           # API NestJS
├── app/              # App móvil Flutter
├── infra/            # Scripts y configs de infraestructura
├── CLAUDE.md         # Guía para Claude Code
└── README.md         # Este archivo
```

## Estados de ServiceRequest

```
PENDING → ACCEPTED       (proveedor acepta)
PENDING → EXPIRED        (timeout 5 min sin aceptación)
PENDING → CANCELLED      (cliente o admin)
ACCEPTED → IN_PROGRESS   (proveedor inicia)
ACCEPTED → CANCELLED     (cliente, proveedor, o admin)
IN_PROGRESS → COMPLETED  (proveedor completa)
IN_PROGRESS → CANCELLED  (solo admin)
```

## Desarrollo

Este proyecto sigue una arquitectura modular:

- **Backend**: Módulos NestJS separados por dominio (auth, users, service-requests, etc.)
- **Frontend**: Estructura feature-first en Flutter
- **Timezone**: Siempre UTC en backend/DB, conversión a local en la app

## Pruebas

```bash
# Backend
cd backend
npm run test
npm run test:e2e

# Flutter
cd app
flutter test
```

## Troubleshooting

### Puerto 5432 o 6379 ya está en uso

Si ves errores como `bind: address already in use` o `password authentication failed for user "postgres"`:

1. **Verificar qué servicios están usando los puertos**:
```bash
sudo lsof -i :5432    # PostgreSQL
sudo lsof -i :6379    # Redis
```

2. **Soluciones**:
   - **Opción 1**: Detener servicios existentes (si es seguro)
   - **Opción 2**: Usar puertos alternativos con `docker-compose.override.yml` (ver Opción B arriba)
   - **Opción 3**: Usar la validación remota contra un servidor existente (actualizar DATABASE_URL en .env)

### Error: `password authentication failed for user "postgres"`

Esto ocurre si hay un PostgreSQL local en puerto 5432 con credenciales diferentes. Soluciones:

1. Usar `docker-compose.override.yml` para mapear a puerto 15432
2. Verificar que tu .env apunta a `localhost:15432` en lugar de `localhost:5432`
3. Reiniciar los contenedores:
```bash
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d
```

## Licencia

Privado - Todos los derechos reservados
