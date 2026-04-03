# Instalación Local — MotoConnect

> **Plataforma objetivo:** Android únicamente. Los directorios `ios/`, `web/`, `linux/`, `macos/` y `windows/` han sido eliminados del repositorio.

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| Flutter | 3.35.3 (canal stable) |
| Dart | ^3.7.0 |
| Android Studio / VS Code | Cualquier versión reciente |
| Android SDK | API 21+ (Android 5.0) |
| Git | Cualquier versión reciente |

---

## Pasos

### 1. Clonar el repositorio

```bash
git clone <url-del-repo>
cd MotoConnect
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar credenciales

Las credenciales están embebidas en el código por ahora. Para un entorno nuevo:

- **Supabase**: editar `lib/core/constants/api_constants.dart` y `lib/main.dart`
- **Google Maps**: editar `android/app/src/main/AndroidManifest.xml`
- **Firebase**: reemplazar `android/app/google-services.json`

Ver [ENVIRONMENT.md](ENVIRONMENT.md) para los valores exactos.

### 4. Ejecutar la app

```bash
# Android (dispositivo o emulador)
flutter run

# Android con sabor de entorno
flutter run --debug
flutter run --release
```

### 5. Verificar análisis estático

```bash
flutter analyze
```

Debe retornar **0 errores y 0 warnings** (solo `info` de `avoid_print` en producción es aceptable).

---

## Dependencias Principales

```yaml
flutter_bloc: ^8.1.3        # Gestión de estado
supabase_flutter: ^2.9.0    # Backend
google_maps_flutter: ^2.12.0 # Mapas
geolocator: ^11.0.0         # GPS
google_place: ^0.4.7        # Places API
geocoding: ^4.0.0           # Geocoding
flutter_polyline_points: ^1.0.0 # Trazado de rutas
firebase_core: ^3.13.0      # Firebase
firebase_messaging: ^15.2.5 # Push notifications
flutter_local_notifications: ^18.0.1 # Notificaciones locales
flutter_tts: ^4.2.0         # Voz (navegación)
image_picker: ^1.0.7        # Cámara/galería
video_player: ^2.9.2        # Reproducción de video
dartz: ^0.10.1              # Either para manejo de errores
```

---

## Permisos Android Requeridos

Los permisos están configurados en `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION` — GPS preciso
- `ACCESS_COARSE_LOCATION` — GPS aproximado
- `ACCESS_BACKGROUND_LOCATION` — GPS en segundo plano (sesiones activas)
- `FOREGROUND_SERVICE` — Servicio de tracking en primer plano
- `FOREGROUND_SERVICE_LOCATION` — Tipo de foreground service
- `INTERNET` — Conexión a Supabase y APIs
- `POST_NOTIFICATIONS` — Notificaciones push

---

## Notas de Configuración Especial

### Canal de notificaciones Android
`MainActivity.kt` pre-crea el canal `geolocator_channel_01` con `IMPORTANCE_LOW` antes de que geolocator lo cree con `IMPORTANCE_NONE`. Esto garantiza que las notificaciones del foreground service sean visibles.

### Firebase en background
El handler `_firebaseBackgroundMessageHandler` en `main.dart` debe ser una función top-level (no dentro de clase) con `@pragma('vm:entry-point')` para que funcione cuando la app está terminada.
