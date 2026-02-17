# Manual de Instalacion de la App Movil

La app es una sola APK que sirve para ambos perfiles (Cliente y Proveedor).
El perfil se determina por el rol del usuario registrado.

---

## Prerequisitos

- PC de desarrollo con Flutter instalado
- Telefono Android con USB debugging habilitado (o acceso al APK por archivo)
- Backend desplegado y accesible en `https://claudiasrv.duckdns.org`

---

## Paso 1: Generar la APK de produccion

En tu PC de desarrollo:

```bash
cd ~/Marketplace-Evelyn/app

# Build release APK apuntando al backend de produccion
flutter build apk --release \
  --dart-define=API_BASE_URL=https://claudiasrv.duckdns.org \
  --dart-define=ENV=production
```

La APK queda en:
```
app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Paso 2: Transferir la APK al telefono

### Opcion A: Via ADB (USB)

```bash
# Conectar telefono por USB con USB debugging habilitado
# Verificar que el dispositivo esta conectado
adb devices

# Instalar la APK
adb install app/build/app/outputs/flutter-apk/app-release.apk

# Si ya hay una version anterior instalada:
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

### Opcion B: Via transferencia de archivo

1. Copiar `app-release.apk` al telefono:
   - Cable USB: copiar a la carpeta `Downloads` del telefono
   - O enviar por Telegram/WhatsApp a ti mismo
   - O subir a Google Drive y descargar desde el telefono

2. En el telefono:
   - Abrir el archivo APK desde el gestor de archivos
   - Si pide permiso: **Ajustes > Instalar apps de fuentes desconocidas > Permitir**
   - Tocar **Instalar**

### Opcion C: Via SCP desde el VPS

Si la APK esta en el VPS:

```bash
# Desde tu PC, descargar del VPS
scp marketplace@claudiasrv.duckdns.org:~/app-release.apk ~/Downloads/

# Luego instalar con ADB
adb install ~/Downloads/app-release.apk
```

---

## Paso 3: Configuracion del perfil CLIENTE

### 3.1 Registrar una cuenta de cliente

1. Abrir la app "Marketplace" en el telefono
2. Tocar **Registrarse**
3. Llenar el formulario:
   - **Email**: email real del cliente
   - **Password**: minimo 8 caracteres
   - **Nombre completo**: nombre del cliente
   - **Telefono**: numero con codigo de pais (+971...)
   - **Rol**: seleccionar **CLIENTE**
   - **Distrito**: seleccionar el distrito donde necesita el servicio
4. Tocar **Registrar**

### 3.2 Uso como cliente

Despues de registrarse, el cliente accede automaticamente a la pantalla principal de cliente:

**Crear una solicitud de limpieza:**
1. Tocar **Nueva Solicitud**
2. Seleccionar distrito, direccion detallada, horas, fecha/hora
3. El sistema calcula el precio automaticamente
4. Confirmar la solicitud

**Ver mis solicitudes:**
1. Tocar **Mis Solicitudes**
2. Ver el estado de cada solicitud (PENDING, ACCEPTED, IN_PROGRESS, COMPLETED)
3. Tocar una solicitud para ver el detalle

**Cuando el estado es PENDING:**
- Se muestra un countdown de 5 minutos
- Si ningun proveedor acepta, expira automaticamente
- Se puede cancelar (requiere motivo)

**Cuando el estado es ACCEPTED:**
- Se muestra info del proveedor asignado (nombre, telefono, rating promedio)
- Se puede cancelar (requiere motivo)

**Cuando el estado es COMPLETED:**
- Aparece el formulario de calificacion
- Seleccionar estrellas (1-5) y comentario opcional
- Tocar **Enviar Calificacion**

---

## Paso 4: Configuracion del perfil PROVEEDOR

### 4.1 Registrar una cuenta de proveedor

1. Abrir la app en otro telefono (o cerrar sesion con **Logout**)
2. Tocar **Registrarse**
3. Llenar el formulario:
   - **Rol**: seleccionar **PROVEEDOR**
   - **Distrito**: seleccionar el distrito donde va a ofrecer servicios
   - El resto igual que cliente
4. Tocar **Registrar**

### 4.2 Activar el proveedor (OBLIGATORIO)

Los proveedores recien registrados tienen `is_verified = false` y **no pueden aceptar trabajos** hasta ser verificados. Esto se hace desde el servidor:

```bash
ssh marketplace@claudiasrv.duckdns.org

# Verificar al proveedor por email
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T postgres psql -U marketplace -c \
  "UPDATE users SET is_verified = true WHERE email = 'proveedor1@test.com';"

# Confirmar
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T postgres psql -U marketplace -c \
  "SELECT email, is_verified FROM users WHERE role = 'PROVIDER';"
```

### 4.3 Uso como proveedor

Despues de login, el proveedor accede a la pantalla principal de proveedor:

**Ver trabajos disponibles:**
1. Tocar **Trabajos Disponibles**
2. Se muestran solo las solicitudes PENDING de su mismo distrito
3. Cada solicitud muestra: distrito, horas, precio total, tiempo restante
4. Tocar **Aceptar** para tomar el trabajo (first accept wins)
5. Si otro proveedor ya lo tomo, se muestra "Ya fue tomado o expiro"

**Ver mis trabajos:**
1. Tocar **Mis Trabajos**
2. Filtrar por pestanas: ACCEPTED / IN_PROGRESS / COMPLETED

**Flujo de un trabajo aceptado:**
1. **ACCEPTED**: Tocar **Iniciar Servicio** cuando llega al lugar (dialog de confirmacion)
2. **IN_PROGRESS**: Tocar **Completar Servicio** cuando termina (dialog de confirmacion)
3. **COMPLETED**: El trabajo se muestra en la pestana de completados

**Cancelar un trabajo ACCEPTED:**
1. Tocar **Cancelar** en la card del trabajo
2. Escribir el motivo de cancelacion (obligatorio, max 500 caracteres)
3. Confirmar la cancelacion

---

## Paso 5: Test completo del flujo (E2E)

Para verificar que todo funciona, seguir este flujo con dos telefonos (o un telefono cambiando de cuenta):

| # | Accion | Actor | Resultado esperado |
|---|--------|-------|--------------------|
| 1 | Registrar cuenta cliente | Cliente | Login automatico, pantalla de cliente |
| 2 | Registrar cuenta proveedor | Proveedor | Login automatico, pantalla de proveedor |
| 3 | Verificar proveedor via SQL | Admin (SSH) | `is_verified = true` |
| 4 | Crear solicitud de 3 horas | Cliente | Estado PENDING, countdown 5 min |
| 5 | Ver trabajos disponibles | Proveedor | La solicitud aparece en la lista |
| 6 | Aceptar el trabajo | Proveedor | Estado cambia a ACCEPTED |
| 7 | Ver detalle de solicitud | Cliente | Muestra proveedor asignado + su rating |
| 8 | Iniciar servicio | Proveedor | Estado cambia a IN_PROGRESS |
| 9 | Completar servicio | Proveedor | Estado cambia a COMPLETED |
| 10 | Calificar 5 estrellas | Cliente | Rating creado, se muestra "Ya registraste tu calificacion" |

---

## Actualizar la app

Cuando hay cambios en el codigo:

```bash
cd ~/Marketplace-Evelyn/app

# Pull cambios
git pull origin main

# Rebuild
flutter build apk --release \
  --dart-define=API_BASE_URL=https://claudiasrv.duckdns.org \
  --dart-define=ENV=production

# Reinstalar en el telefono
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### La app no conecta al servidor

1. Verificar que el backend esta corriendo:
   ```bash
   curl https://claudiasrv.duckdns.org/health
   ```

2. Verificar que la APK fue compilada con la URL correcta:
   ```bash
   # Debe incluir --dart-define=API_BASE_URL=https://claudiasrv.duckdns.org
   ```

3. Verificar que el telefono tiene acceso a internet y puede resolver `claudiasrv.duckdns.org`

### El proveedor no ve trabajos disponibles

1. Verificar que el proveedor esta verificado (`is_verified = true`)
2. Verificar que el proveedor y la solicitud estan en el **mismo distrito**
3. Verificar que la solicitud no expiro (5 minutos)

### Error "Ya fue tomado o expiro"

Normal. Otro proveedor acepto primero (first accept wins) o pasaron los 5 minutos.
El cliente debe crear una nueva solicitud.

### Error al instalar APK: "App not installed"

1. Desinstalar la version anterior: **Ajustes > Apps > Marketplace > Desinstalar**
2. Intentar instalar de nuevo
3. Si persiste, verificar que el telefono tiene espacio suficiente

### Olvide la password de mi cuenta

La app tiene un enlace "Forgot password" en la pantalla de login. En desarrollo, el flujo es automatico (la app recibe el token y navega al formulario de reset). En produccion, como no hay envio de email, usar el script CLI desde el VPS:

```bash
docker compose -f ~/Marketplace-Evelyn/infra/docker-compose.prod.yml \
  --env-file ~/Marketplace-Evelyn/infra/.env.production \
  exec -T backend npx ts-node -r tsconfig-paths/register \
  src/scripts/reset-password.ts tu@email.com NuevaPassword123
```

Ver la seccion "Recuperacion de contrasena" en `MANUAL-BACKEND-DEPLOY.md` para mas opciones.

### No puedo acceder al VPS

1. Verificar que DuckDNS esta actualizando la IP:
   ```bash
   nslookup claudiasrv.duckdns.org
   ```
2. Verificar port forwarding en el router (puertos 22, 80, 443)
3. Verificar que UFW permite SSH: `sudo ufw status`
