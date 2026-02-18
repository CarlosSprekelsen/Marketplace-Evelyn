# Manual de Despliegue del Backend

Servidor: **claudiasrv.duckdns.org**
Stack: NestJS + PostgreSQL 15 + Redis 7 en Docker, Nginx + Certbot en host

---

## Prerequisitos

- VPS Ubuntu 22.04 con acceso SSH como root
- DNS `claudiasrv.duckdns.org` apuntando a la IP publica del VPS
- Puertos 22, 80 y 443 accesibles desde internet (router/firewall del ISP)

---

## Paso 1: Setup inicial del VPS

Conectarse por SSH como root y ejecutar:

```bash
# Descargar y ejecutar el script de setup
# (crea usuario marketplace, instala Docker, Nginx, Certbot, UFW, fail2ban)
ssh root@claudiasrv.duckdns.org

apt-get update && apt-get install -y git
git clone https://github.com/CarlosSprekelsen/Marketplace-Evelyn.git /tmp/setup
bash /tmp/setup/infra/scripts/setup-vps.sh
```

**IMPORTANTE**: Antes de ejecutar el script, copiar tu llave SSH al VPS:

```bash
# Desde tu PC local
ssh-copy-id root@claudiasrv.duckdns.org
```

Despues del script, el login por password queda deshabilitado. Copiar llave al user marketplace:

```bash
# Desde tu PC local
ssh-copy-id marketplace@claudiasrv.duckdns.org
```

---

## Paso 2: Clonar el repositorio

```bash
ssh marketplace@claudiasrv.duckdns.org

cd ~
git clone https://github.com/CarlosSprekelsen/Marketplace-Evelyn.git
cd Marketplace-Evelyn
```

---

## Paso 3: Configurar secrets de produccion

```bash
cd ~/Marketplace-Evelyn/infra
cp .env.production.example .env.production
nano .env.production
```

Llenar los valores. Generar secrets seguros:

```bash
# Generar passwords y secrets aleatorios
echo "POSTGRES_PASSWORD: $(openssl rand -base64 32)"
echo "JWT_SECRET: $(openssl rand -base64 64)"
echo "JWT_REFRESH_SECRET: $(openssl rand -base64 64)"
```

El archivo .env.production debe quedar asi (con tus valores reales):

```
POSTGRES_DB=marketplace
POSTGRES_USER=marketplace
POSTGRES_PASSWORD=<password generado>

JWT_SECRET=<secret generado>
JWT_EXPIRES_IN=30m
JWT_REFRESH_SECRET=<secret generado>
JWT_REFRESH_EXPIRES_IN=30d

CORS_ORIGINS=https://claudiasrv.duckdns.org
```

---

## Paso 4: Configurar Nginx como reverse proxy

```bash
# Copiar la config de Nginx
sudo cp ~/Marketplace-Evelyn/infra/nginx/api.conf /etc/nginx/sites-available/marketplace
sudo ln -sf /etc/nginx/sites-available/marketplace /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Verificar la config
sudo nginx -t

# Recargar Nginx
sudo systemctl reload nginx
```

---

## Paso 5: Desplegar el backend con Docker

```bash
cd ~/Marketplace-Evelyn
bash infra/scripts/deploy.sh
```

El script hace:
1. `git pull origin main`
2. `docker compose up -d postgres redis` (asegura servicios de datos sin apagar produccion)
3. `docker compose build backend`
4. `docker compose up -d --no-deps --force-recreate backend` (recrea solo backend)
5. Espera el healthcheck del backend
6. Ejecuta migraciones de base de datos
7. Verifica que `/health` retorna 200

Verificar que todo esta corriendo:

```bash
# Ver estado de contenedores
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production ps

# Ver logs del backend
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production logs backend --tail=30

# Probar el health check
curl http://localhost:3000/health
```

---

## Paso 6: Configurar HTTPS con Certbot

```bash
sudo certbot --nginx -d claudiasrv.duckdns.org
```

Certbot va a:
1. Pedir un email para notificaciones
2. Obtener el certificado SSL de Let's Encrypt
3. Modificar automaticamente la config de Nginx para HTTPS
4. Configurar redireccion HTTP -> HTTPS
5. Configurar renovacion automatica (cron)

Verificar:

```bash
# Debe retornar 200 por HTTPS
curl https://claudiasrv.duckdns.org/health
```

---

## Paso 7: Seed de datos iniciales

La primera vez necesitas crear los distritos y reglas de precios:

```bash
cd ~/Marketplace-Evelyn

# Ejecutar seed dentro del contenedor
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T backend node -e "
    const { DataSource } = require('typeorm');
    const ds = new DataSource({
      type: 'postgres',
      url: process.env.DATABASE_URL,
      entities: ['dist/**/*.entity.js'],
    });
    ds.initialize().then(async (d) => {
      const districtRepo = d.getRepository('District');
      const pricingRepo = d.getRepository('PricingRule');

      const districts = [
        { name: 'Dubai Marina' },
        { name: 'JBR (Jumeirah Beach Residence)' },
        { name: 'Downtown Dubai' },
        { name: 'Business Bay' },
        { name: 'Dubai Hills' },
      ];

      const saved = [];
      for (const d of districts) {
        const existing = await districtRepo.findOne({ where: { name: d.name } });
        if (!existing) {
          const created = await districtRepo.save(districtRepo.create(d));
          saved.push(created);
          console.log('Created district:', d.name);
        } else {
          saved.push(existing);
          console.log('Exists:', d.name);
        }
      }

      const prices = [
        { district_id: saved[0].id, price_per_hour: 20, min_hours: 1, max_hours: 8 },
        { district_id: saved[1].id, price_per_hour: 22, min_hours: 1, max_hours: 8 },
        { district_id: saved[2].id, price_per_hour: 25, min_hours: 1, max_hours: 8 },
      ];

      for (const p of prices) {
        const existing = await pricingRepo.findOne({ where: { district_id: p.district_id, is_active: true } });
        if (!existing) {
          await pricingRepo.save(pricingRepo.create(p));
          console.log('Created pricing for district:', p.district_id);
        } else {
          console.log('Pricing exists for district:', p.district_id);
        }
      }

      console.log('Seed complete.');
      process.exit(0);
    }).catch(e => { console.error(e); process.exit(1); });
  "
```

---

## Paso 8: Configurar backup diario

```bash
# Agregar al crontab del user marketplace
crontab -e

# Agregar esta linea (backup a las 3 AM UTC):
0 3 * * * /home/marketplace/Marketplace-Evelyn/infra/scripts/backup-db.sh >> /var/log/marketplace-backup.log 2>&1
```

---

## Paso 9: Crear usuarios beta via API

### Registrar un cliente:

```bash
curl -X POST https://claudiasrv.duckdns.org/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "cliente1@test.com",
    "password": "Password123!",
    "full_name": "Cliente Prueba",
    "phone": "+971501234567",
    "role": "CLIENT",
    "district_id": "<uuid del distrito>"
  }'
```

### Registrar un proveedor:

```bash
curl -X POST https://claudiasrv.duckdns.org/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "proveedor1@test.com",
    "password": "Password123!",
    "full_name": "Proveedor Prueba",
    "phone": "+971509876543",
    "role": "PROVIDER",
    "district_id": "<uuid del distrito>"
  }'
```

### Obtener los UUIDs de distritos:

```bash
# Conectar a la DB dentro del contenedor
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T postgres psql -U marketplace -c "SELECT id, name FROM districts;"
```

### Verificar un proveedor (activar para que pueda aceptar trabajos):

```bash
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T postgres psql -U marketplace -c \
  "UPDATE users SET is_verified = true WHERE email = 'proveedor1@test.com';"
```

---

## Recuperacion de contrasena

### Contexto

El flujo de forgot-password funciona end-to-end, pero en produccion NO envia email/SMS (respuesta generica para evitar enumeracion de usuarios). Para restablecer passwords hay dos mecanismos accesibles solo desde la LAN/VPN:

### Opcion 1: Script CLI (no requiere login de admin)

Ejecutar directamente en el VPS via SSH:

```bash
# Sintaxis:
# reset-password.ts <email> <nueva_password>

# Si el backend corre en Docker:
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T backend npx ts-node -r tsconfig-paths/register \
  src/scripts/reset-password.ts usuario@email.com NuevaPassword123

# Si tienes acceso directo al backend (dev local):
cd ~/Marketplace-Evelyn/backend
DATABASE_URL=postgresql://marketplace:TUPASSWORD@localhost:5432/marketplace \
  npx ts-node -r tsconfig-paths/register \
  src/scripts/reset-password.ts usuario@email.com NuevaPassword123
```

El script:
- Busca el usuario por email
- Hashea la nueva password con bcrypt (10 rounds)
- Invalida refresh tokens y tokens de reset existentes
- Imprime confirmacion con el rol del usuario

### Opcion 2: Endpoint admin (requiere JWT de admin)

```bash
# 1. Login como admin para obtener el token
TOKEN=$(curl -s -X POST https://claudiasrv.duckdns.org/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@email.com","password":"AdminPassword123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 2. Obtener el UUID del usuario
curl -s -H "Authorization: Bearer $TOKEN" \
  https://claudiasrv.duckdns.org/admin/users | python3 -c "
import sys,json
for u in json.load(sys.stdin):
    print(f\"{u['id']}  {u['email']}  {u['role']}\")
"

# 3. Forzar reset del password
curl -X PATCH https://claudiasrv.duckdns.org/admin/users/<UUID>/reset-password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"new_password": "NuevaPassword123"}'
```

### Opcion 3: SQL directo (emergencia)

Si no tienes acceso al script ni al admin:

```bash
# Conectar a PostgreSQL
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T postgres psql -U marketplace

# Generar hash bcrypt e insertar (requiere node):
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T backend node -e "
    const bcrypt = require('bcrypt');
    bcrypt.hash('NuevaPassword123', 10).then(h => {
      console.log('UPDATE users SET password_hash = \\'' + h + '\\', refresh_token_hash = NULL, password_reset_token_hash = NULL, password_reset_expires_at = NULL WHERE email = \\'usuario@email.com\\';');
    });
  "
# Copiar el SQL generado y ejecutarlo en psql
```

### Flujo forgot-password en la app (para desarrollo/testing)

En entornos donde `NODE_ENV != production`, el endpoint `POST /auth/forgot-password` devuelve el `reset_token` en la respuesta JSON. La app automaticamente navega a la pantalla de reset con el token pre-rellenado.

En produccion (`NODE_ENV=production`), el endpoint devuelve solo el mensaje generico. Para cerrar el flujo completo en produccion se necesitaria integrar un proveedor de correo (SendGrid free tier, Resend, etc.).

---

## Operaciones comunes

### Re-desplegar despues de un cambio

```bash
ssh marketplace@claudiasrv.duckdns.org
cd ~/Marketplace-Evelyn
bash infra/scripts/deploy.sh
```

### Ver logs en tiempo real

```bash
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production logs -f backend
```

### Reiniciar solo el backend

```bash
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production restart backend
```

### Acceder a la base de datos

```bash
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T postgres psql -U marketplace
```

### Restaurar un backup

```bash
gunzip -c infra/backups/marketplace_20260215_030000.sql.gz | \
  docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T postgres psql -U marketplace
```

---

## Checklist de verificacion final

```bash
# HTTPS funciona
curl -s https://claudiasrv.duckdns.org/health
# Esperado: {"status":"ok","timestamp":"..."}

# Certificado SSL valido
curl -vI https://claudiasrv.duckdns.org/health 2>&1 | grep "subject:"

# Contenedores corriendo
docker ps --format "table {{.Names}}\t{{.Status}}"

# Base de datos tiene distritos
docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.production \
  exec -T postgres psql -U marketplace -c "SELECT count(*) FROM districts;"

# Rate limiting funciona (6to request deberia dar 429)
for i in $(seq 1 7); do
  echo "Request $i: $(curl -s -o /dev/null -w '%{http_code}' -X POST \
    https://claudiasrv.duckdns.org/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"email":"x","password":"x"}')"
done
```

---

## Puertos requeridos en el router/firewall

| Puerto | Protocolo | Uso |
|--------|-----------|-----|
| 22     | TCP       | SSH |
| 80     | TCP       | HTTP (redirige a HTTPS) |
| 443    | TCP       | HTTPS (API) |

Si `claudiasrv.duckdns.org` apunta a un router domestico, asegurar que los puertos 80 y 443 estan redirigidos (port forwarding) a la IP local del VPS.
