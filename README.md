# MotoConnect

Aplicación móvil para motociclistas desarrollada como proyecto de grado — Tecnología en Desarrollo de Sistemas Informáticos.

MotoConnect permite a los motociclistas planificar rutas, participar en eventos de rodada, conectarse con talleres mecánicos, compartir experiencias en comunidad y coordinar sesiones de ruta en grupo con seguimiento de ubicación en tiempo real.

**Versión**: 1.2.1 (Build 1) — Rama: `MotoConnect_1.2.1`
**Plataforma**: Solo Android

---

## Stack Tecnológico

| Tecnología | Versión |
|-----------|---------|
| Flutter | 3.35.3 (stable) |
| Dart SDK | ^3.7.0 |
| Backend | Supabase (PostgreSQL 17, Realtime, Storage, Edge Functions) |
| Autenticación | Supabase Auth (Email/Password + Google OAuth) |
| Mapas | google_maps_flutter 2.12.0 + Google Directions API |
| Gestión de estado | flutter_bloc 8.1.3 |
| Notificaciones | Firebase Cloud Messaging (FCM) |

---

## Módulos

| Módulo | Vistas | BLoC | Notas |
|--------|--------|------|-------|
| Auth | splash, login, register, reset_password | AuthBloc (global), LoginBloc | Google OAuth soportado |
| Home | home_screen | — | Navegación inferior, 5 pestañas |
| Perfil | profile_screen | ProfileBloc | Subida de foto, versión de app, selector de tema |
| Rutas | rutas_screen, saved_routes_screen, map_picker_screen | RoutesBloc, SavedRoutesBloc | — |
| Navegación | navigation_screen | NavigationBloc | Giro a giro, voz, capa UseCase completa |
| Eventos | events_screen, event_detail_screen, create_event_screen | EventsBloc | Notificaciones FCM al crear |
| Talleres | talleres_screen | TalleresBloc | — |
| Comunidad | community_screen | CommunityBloc | Feed social de publicaciones |
| Grupos | grupos_screen, detalle_grupo_screen, crear_grupo_screen, editar_grupo_screen, unirse_grupo_screen, mapa_compartido_screen | GruposBloc (lista/detalle) + estado local (mapa) | GPS en tiempo real, sesiones, rutas compartidas, SOS |
| Tema | (en perfil) | ThemeCubit (global) | Claro/oscuro, SharedPreferences |

---

## Notas de Arquitectura

- **Clean Architecture parcial** — solo el módulo de Navegación tiene una capa UseCase. Todos los demás módulos van del BLoC directamente a un repository o a Supabase.
- `MapaCompartidoScreen` es un `StatefulWidget` con estado local — no usa BLoC — debido a 6 suscripciones simultáneas de Supabase Realtime.
- Los directorios de plataforma iOS, web, Linux, macOS y Windows fueron eliminados. Android es el único objetivo soportado.

---

## Datos Técnicos Clave

- **Base de datos**: 18 tablas, 4 vistas, 20 triggers, 23 migraciones aplicadas
- **Realtime**: Supabase Realtime usado solo en `MapaCompartidoScreen` (6 suscripciones)
- **Notificaciones push**: Firebase FCM via Supabase Edge Functions. 3 canales de notificación pre-creados en `MainActivity.kt`
- **GPS**: geolocator 11.x con servicio en primer plano Android. Canal `geolocator_channel_01` pre-creado como `IMPORTANCE_LOW` para reemplazar el `IMPORTANCE_NONE` por defecto de geolocator
- **Navegación**: Polylines por paso desde Google Directions API concatenados para precisión. Detección de desvío: umbral de 3 segundos / 50 metros
- **Brechas RLS conocidas**: La política UPDATE de `grupos_ruta` es `true` (cualquier usuario autenticado puede actualizar cualquier grupo); todas las políticas de `miembros_grupo` son `true`

---

## Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone <url-repositorio>

# 2. Instalar dependencias
flutter pub get

# 3. Configurar credenciales
# - Supabase: lib/core/constants/api_constants.dart
# - Google Maps: android/app/src/main/AndroidManifest.xml
# - Firebase: android/app/google-services.json

# 4. Ejecutar
flutter run
```

Ver guía completa: [`docs/setup/INSTALLATION.md`](docs/setup/INSTALLATION.md)

---

## Documentación

### Arquitectura

| Archivo | Contenido |
|---------|-----------|
| [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) | Estructura de capas, lista de BLoCs, repositories, servicios, diagramas de flujo de datos |
| [docs/architecture/PATTERNS.md](docs/architecture/PATTERNS.md) | Patrón BLoC, Clean Architecture parcial, StatefulWidget Realtime, servicio en primer plano, pre-creación de canales de notificación |
| [docs/architecture/DIAGRAMS.md](docs/architecture/DIAGRAMS.md) | Diagramas de arquitectura |
| [docs/architecture/AUTH.md](docs/architecture/AUTH.md) | Flujos de autenticación |

### Módulos

| Archivo | Contenido |
|---------|-----------|
| [docs/modules/GRUPOS.md](docs/modules/GRUPOS.md) | Ciclo de vida de grupos, ciclo de sesión, internos de MapaCompartidoScreen, estados de conexión, sistema de roles |
| [docs/modules/NAVIGATION.md](docs/modules/NAVIGATION.md) | NavigationBloc, UseCases, polylines por paso, detección de desvío, guía de voz |
| [docs/modules/PROFILE.md](docs/modules/PROFILE.md) | Campos de UserModel, subida de foto, ProfileBloc |
| [docs/modules/EVENTS.md](docs/modules/EVENTS.md) | Módulo de eventos |
| [docs/modules/ROUTES.md](docs/modules/ROUTES.md) | Módulo de rutas |
| [docs/modules/COMMUNITY.md](docs/modules/COMMUNITY.md) | Módulo de comunidad/feed |
| [docs/modules/TALLERES.md](docs/modules/TALLERES.md) | Módulo de talleres |

### Base de Datos

| Archivo | Contenido |
|---------|-----------|
| [docs/database/InformeBD.md](docs/database/InformeBD.md) | Informe completo de la BD tablas, triggers, buckets |

### API / Esquema

| Archivo | Contenido |
|---------|-----------|
| [docs/api/SUPABASE_SCHEMA.md](docs/api/SUPABASE_SCHEMA.md) | Referencia rápida: tablas, vistas, triggers, funciones, buckets de storage, lista de migraciones |
| [docs/api/ENDPOINTS.md](docs/api/ENDPOINTS.md) | Referencia de endpoints de la API |
| [docs/api/GOOGLE_APIS.md](docs/api/GOOGLE_APIS.md) | Uso de Google Directions API |

### Desarrollo

| Archivo | Contenido |
|---------|-----------|
| [docs/development/DEPLOYMENT.md](docs/development/DEPLOYMENT.md) | Comandos de build Android, lista de verificación pre-lanzamiento, despliegue de Edge Functions, migraciones |
| [docs/setup/ENVIRONMENT.md](docs/setup/ENVIRONMENT.md) | Variables de configuración, tablas Supabase, rutas registradas |
