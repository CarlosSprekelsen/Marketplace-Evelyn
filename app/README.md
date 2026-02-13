# Marketplace App (Flutter)

App móvil Flutter para el marketplace de limpieza por horas.

## Requisitos

- Flutter 3.x
- Dart 3.x
- Android Studio (para desarrollo Android)
- Dispositivo Android o emulador

## Setup inicial

Una vez Flutter esté instalado, ejecuta los siguientes comandos:

```bash
# Obtener dependencias
flutter pub get

# Generar código con build_runner (si es necesario)
flutter pub run build_runner build --delete-conflicting-outputs

# Verificar que todo está configurado
flutter doctor
```

## Configuración del entorno

### Desarrollo local
La app se conectará por defecto a `http://localhost:3000` (backend local).

### Producción
Para compilar para producción con una URL diferente:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.tudominio.com --dart-define=ENV=production
```

## Ejecutar la app

### En modo desarrollo
```bash
flutter run
```

### En modo release
```bash
flutter run --release
```

## Estructura del proyecto

```
lib/
├── main.dart                    # Entry point
├── config/                      # Configuración de entorno
│   └── environment.dart
├── core/                        # Funcionalidades core
│   ├── api/                     # Cliente HTTP (Dio)
│   │   ├── dio_client.dart
│   │   └── interceptors/
│   ├── storage/                 # Secure storage
│   └── routing/                 # Router (go_router)
├── features/                    # Features (feature-first)
│   ├── auth/                    # Autenticación
│   ├── client/                  # Funcionalidades del cliente
│   │   ├── request_form/
│   │   ├── my_requests/
│   │   └── rating/
│   └── provider/                # Funcionalidades del proveedor
│       ├── available_jobs/
│       └── my_jobs/
└── shared/                      # Widgets y modelos compartidos
    ├── models/
    └── widgets/
```

## Estado (Riverpod)

Esta app utiliza Riverpod para state management. Ejemplos de uso se implementarán en Sprint 1.

## Características

- **Riverpod**: State management
- **Dio**: HTTP client con interceptors
- **go_router**: Routing declarativo
- **flutter_secure_storage**: Almacenamiento seguro de tokens

## Notas

- La estructura de carpetas está creada pero vacía en Sprint 0
- Las implementaciones específicas se agregarán en los siguientes sprints
- La pantalla de login actual es un placeholder
