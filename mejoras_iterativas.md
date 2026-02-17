# MarketPlace Evelyn — Plan de Mejoras Iterativas

Estado actual: Sprints 0-4 completados. Flujo cliente funcional (registro + booking). Falta probar flujo proveedor (segunda app/rol).

---

## Wave 1 [COMLPLETADA]— Correcciones de testing inmediatas (1-2 días)

Estas salen directamente de tu sesión de pruebas. Son cambios quirúrgicos que no tocan arquitectura.

**1.1 Renombrar a "MarketPlace Evelyn"**
- Cambiar app title en Flutter (`MaterialApp.title`, splash screen si hay)
- Actualizar `APP_NAME` en configuración backend si se usa en emails/responses
- Esto no requiere cambios de DB ni endpoints
- Tarea Claude Code: "Renombra todas las referencias a 'Marketplace Limpieza' por 'MarketPlace Evelyn' en app/ y backend/. Busca en pubspec.yaml, AndroidManifest.xml, main.dart, y cualquier string visible al usuario."

**1.2 Slots redondeados a 30 minutos**
- Modificar el DateTimePicker en Flutter para que solo permita seleccionar minutos en intervalos de :00 y :30
- Agregar validación en backend: `CreateServiceRequestDto` debe rechazar `scheduled_at` que no termine en :00 o :30
- Tarea Claude Code: "En app/lib/features/client/request_form/request_form_screen.dart, modifica el DateTimePicker para que los minutos solo permitan seleccionar 0 o 30. En backend/src/service-requests/dto/create-service-request.dto.ts, agrega una validación custom que rechace scheduled_at con minutos distintos a 0 o 30. Agrega test para este caso."

**1.3 Eliminar precisión de microsegundos en UI**
- Formatear todas las fechas visibles al usuario sin segundos ni milisegundos
- El formato ya parcialmente existe (`_formatDateTime` en Sprint 2), verificar consistencia en todas las pantallas
- Formato target: "15 Feb 2026, 14:30"
- Tarea Claude Code: "Audita todas las pantallas en app/lib/features/ que muestren fechas. Asegúrate de que todas usen un formato consistente 'dd MMM yyyy, HH:mm' sin segundos ni milisegundos. Crea un helper centralizado en app/lib/shared/ si no existe."

**1.4 Re-lanzar solicitud expirada (sin persistencia)**
- Cuando una solicitud expira, el botón "Intentar de nuevo" debe abrir el formulario pre-llenado con los mismos datos (distrito, dirección, horas) pero NO reutilizar el registro expirado
- Se crea una solicitud nueva con datos copiados del frontend
- Tarea Claude Code: "En la pantalla de detalle del cliente (Mi Solicitud), cuando status=EXPIRED, el botón 'Intentar de nuevo' debe navegar al formulario de nueva solicitud pasando como parámetros: district_id, address_detail, hours_requested. El formulario debe pre-llenarse con esos valores. No modifica backend."

**1.5 Direcciones persistentes por usuario**
- Agregar tabla `user_addresses` (rompe la regla de 5 tablas, pero es justificado para UX real)
- Campos: id, user_id, district_id, address_detail, label (ej: "Casa", "Oficina"), is_default, created_at
- Endpoints: GET /me/addresses, POST /me/addresses, DELETE /me/addresses/:id
- En el formulario de solicitud: dropdown de direcciones guardadas + opción "Nueva dirección"
- Al crear solicitud con dirección nueva, preguntar si quiere guardarla
- Tarea Claude Code: dividir en 2 sub-tareas (backend entity+endpoints, luego Flutter UI)

---

## Wave 2 [COMPLETADA]— Mejoras de UX detectadas en codebase (3-5 días)

Cosas que no aparecieron en tu testing pero que se ven al revisar el código y que afectarán la validación real.

**2.1 Expiración de 5 minutos es probablemente muy corta**
- En un mercado real, los proveedores no están mirando la app cada 30 segundos
- Considerar subir a 15-30 minutos, o hacerlo configurable por distrito
- Cambio simple: `expires_at = now() + interval` donde interval viene de config o PricingRule
- Impacto bajo, cambio en un solo lugar del servicio

**2.2 Proveedor: estado online/offline**
- Agregar campo `is_available` (boolean) en tabla User
- Toggle en la app del proveedor: "Estoy disponible / No disponible"
- El endpoint GET /service-requests/available filtra además por `provider.is_available = true`... en realidad no, el filtro es al revés: solo muestra requests a proveedores que están online. Pero dado que usas polling del lado del proveedor, basta con que el proveedor no abra la app. Sin embargo, el toggle es útil para UX: el proveedor se siente "en control"
- Más importante: si implementas notificaciones después, solo notificas a proveedores con is_available=true

**2.3 Confirmación visual del precio ANTES de enviar**
- Revisar que el flujo sea: elegir distrito + horas → ver precio → confirmar. Si ya está así, verificar que el precio mostrado sea claro y prominente
- Agregar desglose: "3 horas × $15/hora = $45 total"

**2.4 Historial filtrable para el cliente**
- Actualmente GET /service-requests/mine devuelve todo ordenado DESC
- Agregar filtro por status como query param (ej: ?status=COMPLETED)
- El proveedor ya tiene filtro por estado en "Mis Trabajos", el cliente debería tener lo mismo

**2.5 Mejorar feedback cuando no hay proveedores en un distrito**
- Si un distrito no tiene proveedores registrados y verificados, la solicitud expirará siempre
- Considerar mostrar un indicador al cliente: "Hay proveedores activos en este distrito: Sí/No"
- Endpoint simple: GET /districts con campo `has_active_providers` (count de providers verificados por distrito)

---

## Wave 3 [COMPLETADA]— Preparación para beta real (5-7 días)

Estas son necesarias antes de poner usuarios reales.

**3.1 Notificaciones push (Firebase Cloud Messaging)**
- Esto rompe la regla de "NO WebSockets" pero FCM no es WebSocket, es push nativo
- Notificar al proveedor cuando hay nueva solicitud en su distrito
- Notificar al cliente cuando su solicitud es aceptada
- Requiere: guardar FCM token en User, integrar firebase_messaging en Flutter, endpoint para registrar token
- Sin esto, la beta depende 100% de que el proveedor esté haciendo polling activamente

**3.2 Validación de teléfono**
- Actualmente el teléfono es texto libre
- Para beta real, el proveedor necesita llamar/WhatsApp al cliente
- Considerar validación de formato (ej: +971XXXXXXXXX para UAE)
- Bonus: botón "Llamar" y "WhatsApp" en la card del proveedor/cliente asignado

**3.3 Pantalla de admin básica**
- No necesita ser Flutter, puede ser una web simple (React o incluso un dashboard con Retool/AdminJS)
- Ver todas las solicitudes, cambiar estados manualmente, bloquear usuarios, verificar proveedores
- Sin esto, "verificar proveedor" requiere UPDATE directo en DB

**3.4 Términos y condiciones + política de privacidad**
- Checkbox obligatorio en registro
- Necesario para publicar en Play Store
- Puede ser una pantalla con WebView a una URL estática

**3.5 Manejo de la app en segundo plano**
- Verificar que el refresh token funcione correctamente cuando la app vuelve de background después de horas
- Verificar que el polling se detenga en background y se reanude en foreground

---

## Wave 4 — Mejoras post-beta basadas en feedback (ongoing)

Estas son hipótesis que solo se validan con usuarios reales. No implementar hasta tener datos.

**4.1 Solicitudes recurrentes**
- "Quiero limpieza todos los martes a las 10:00"
- Solo implementar si múltiples clientes lo piden

**4.2 Proveedor en múltiples distritos**
- Actualmente un proveedor tiene un solo district_id
- Si los proveedores quieren cubrir zonas vecinas, necesitas tabla intermedia user_districts
- Solo si la oferta es insuficiente en algunos distritos

**4.3 Chat entre cliente y proveedor**
- Solo si la comunicación por teléfono/WhatsApp resulta insuficiente
- Complejidad alta para MVP

**4.4 Pagos online**
- Solo si el efectivo resulta problemático para la operación
- Considerar Stripe o payment gateway local para UAE

**4.5 Expansión a otros verticales**
- El nombre "Evelyn" ya lo anticipa
- Requiere la abstracción ServiceType que actualmente está en guardrails de "NO hacer"
- Solo cuando limpieza esté validada y funcionando

**4.6 Recuperacion de contrasena (Forgot password)**
- Agregar enlace pequeño "Forgot password" en la pantalla de login
- Flujo de backend: `POST /auth/forgot-password` + `POST /auth/reset-password` con token temporal y expiración corta
- En producción: respuesta genérica para evitar enumeración de usuarios por email
- En app: pantalla para solicitar reset y pantalla para definir nueva contrasena
Forgot password en producción todavía no es end-to-end real: no hay envío de email/SMS del token (el backend devuelve mensaje genérico y no expone token en NODE_ENV=production).
Falta integración de proveedor de correo + plantilla + link seguro de reset para cerrar el flujo completo de recuperación.
---

## Orden sugerido de ejecución

| Prioridad | Wave | Descripción | Esfuerzo |
|-----------|------|-------------|----------|
| AHORA | 1.1-1.4 | Fixes de tu testing (rename, slots, retry, formato) | 1 día |
| AHORA | 1.5 | Direcciones persistentes | 1-2 días |
| SIGUIENTE | 2.1-2.3 | Expiración, precio claro, toggle proveedor | 2 días |
| SIGUIENTE | 2.4-2.5 | Filtros e indicadores de disponibilidad | 1 día |
| PRE-BETA | 3.1 | Push notifications (FCM) | 2-3 días |
| PRE-BETA | 3.2-3.5 | Teléfono, admin, T&C, background | 3-4 días |
| POST-BETA | 4.x | Según feedback real | Variable |

---

## Nota sobre la regla de 5 tablas

El guardrail de "máximo 5 tablas" cumplió su propósito durante los sprints iniciales: evitó que el modelo de datos creciera sin control. Ahora que el core funciona (District, User, ServiceRequest, PricingRule, Rating), agregar `user_addresses` como tabla 6 es razonable. La regla debería evolucionar a: "no agregar tablas sin justificación de UX validada en testing".
