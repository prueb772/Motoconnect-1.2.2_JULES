# MotoConnect — Arquitectura

**Versión**: 1.2.1+1
**Flutter**: 3.35.3 / Dart SDK ^3.7.0
**Plataforma**: Solo Android (iOS, web, Linux, macOS y Windows eliminados)
**Gestión de Estado**: flutter_bloc
**Backend**: Supabase (proyecto: otxzwutudsruildrtuzy, región: us-east-2)

---

## Visión General

MotoConnect usa una **Clean Architecture parcial**. Solo el módulo de Navegación tiene una capa UseCase completa. Todos los demás módulos van del BLoC directamente a un Repository o directamente a Supabase — no existen use cases intermedios para ellos.

Esto es intencional: la capa UseCase fue eliminada para los módulos que no son Navegación durante la limpieza de código muerto (rama MotoConnect_1.2.0).

---

## Estructura de Capas

### 1. Capa de Presentación (`lib/presentation/`)

- **Views** — Widgets Flutter (pantallas). Ubicadas en `lib/presentation/views/`.
- **BLoCs** — Componentes de Lógica de Negocio. Ubicados en `lib/presentation/blocs/`.
- Las vistas se suscriben a los estados del BLoC y despachan eventos BLoC.
- Excepción: `MapaCompartidoScreen` es un `StatefulWidget` con estado local — ningún BLoC lo maneja.

### 2. Capa de Dominio (`lib/domain/`) — Solo módulo de Navegación

- **UseCases** — cada uno encapsula una sola operación.
- Solo el módulo de Navegación tiene esta capa. No existen use cases para Auth, Routes, Events, Community, Talleres o Groups.

### 3. Capa de Datos (`lib/data/`)

- **Repositories** — abstraen las operaciones de Supabase (existen 4 repositories).
- **Models** — clases de datos inmutables con `fromJson`/`toJson`/`copyWith`.
- **Services** (`lib/data/services/`) — wrappers de API (GoogleDirectionsService, AuthApiService).

### 4. Capa de Servicios (`lib/services/`)

Servicios de plataforma que operan independientemente del patrón BLoC/repository:
- LocationTrackingService
- NavigationVoiceService
- NavigationTrackingService
- MarkerStateManager
- NotificationService

### 5. Capa Core (`lib/core/`)

- `theme/` — AppTheme con temas claro/oscuro, ThemeCubit
- `config/` — configuración de la app, valores de entorno
- `constants/` — constantes globales de la app

---

## Flujo de Datos por Tipo de Módulo

### Módulo de Navegación (Clean Architecture completa)

```
NavigationScreen (Vista)
    ↓ despacha eventos
NavigationBloc
    ↓ llama UseCases
StartNavigationUseCase / UpdateNavigationProgressUseCase /
EndNavigationUseCase / RecalculateRouteUseCase
    ↓ llama
NavigationRepository ← → Supabase (sesiones_navegacion, progreso_navegacion_tiempo_real)
LocationTrackingService ← → geolocator / servicio en primer plano Android
NavigationVoiceService ← → flutter_tts
NavigationTrackingService ← → snap a polyline / detección de desvío
GoogleDirectionsService ← → Google Directions API (HTTP)
```

### Todos los demás módulos (BLoC → Repository → Supabase)

```
Pantalla (Vista)
    ↓
BLoC
    ↓
Repository (si existe) O llamada directa al cliente Supabase
    ↓
Supabase
```

### MapaCompartidoScreen (excepción StatefulWidget)

```
MapaCompartidoScreen (StatefulWidget, estado local)
    ↓ suscripciones directas
6 StreamSubscriptions de Supabase Realtime
    ↓
ubicaciones_tiempo_real, participantes_sesion,
progreso_navegacion_tiempo_real, rutas_sesion,
sesiones_ruta_activa, connectivity
```

---

## BLoCs

| BLoC | Alcance | Dependencias |
|------|---------|-------------|
| AuthBloc | Global (nivel app, provisto en MaterialApp) | AuthRepository |
| LoginBloc | Por pantalla | AuthRepository |
| RoutesBloc | Por pantalla | Supabase client directo |
| SavedRoutesBloc | Por pantalla | Supabase client directo |
| NavigationBloc | Por pantalla | StartNavigationUseCase, UpdateNavigationProgressUseCase, EndNavigationUseCase, RecalculateRouteUseCase, LocationTrackingService, NavigationVoiceService, NavigationTrackingService |
| EventsBloc | Por pantalla | EventRepository |
| CommunityBloc | Por pantalla | Supabase client directo |
| ProfileBloc | Por pantalla | Supabase client directo |
| TalleresBloc | Por pantalla | Supabase client directo |
| ThemeCubit | Global (nivel app) | SharedPreferences |

**Eliminados (código muerto)**: HomeBloc nunca fue instanciado y fue eliminado. PauseNavigationUseCase y ResumeNavigationUseCase eliminados en v1.2.1 — ninguna vista despachaba los eventos correspondientes.

---

## UseCases (solo módulo de Navegación)

Ubicados en `lib/domain/usecases/navigation/`:

| UseCase | Propósito |
|---------|-----------|
| StartNavigationUseCase | Inicia una sesión de navegación, obtiene la ruta desde GoogleDirectionsService, persiste en Supabase |
| UpdateNavigationProgressUseCase | Actualiza el paso actual, posición snappeada y distancia; escribe en progreso_navegacion_tiempo_real |
| EndNavigationUseCase | Completa o cancela la navegación, opcionalmente guarda en rutas_realizadas |
| RecalculateRouteUseCase | Activado tras detección de desvío; llama a GoogleDirectionsService para nueva ruta desde posición actual |

---

## Repositories

Ubicados en `lib/data/repositories/`:

| Repository | Maneja |
|-----------|--------|
| GrupoRepository | Grupos, sesiones (sesiones_ruta_activa), participantes, upserts de ubicación en tiempo real, rutas compartidas (rutas_sesion) |
| NavigationRepository | Sesiones de navegación (sesiones_navegacion), seguimiento de progreso (progreso_navegacion_tiempo_real), streaming de estado |
| EventRepository | CRUD de eventos, gestión de participación, asociaciones evento_grupos |
| AuthRepository | Inicio de sesión, registro, Google OAuth, cierre de sesión, gestión de sesión |

**Eliminados (código muerto)**: TallerRepository, PostRepository, UserRepository, RouteRepository, RouteApiService, TallerApiService, UserApiService, PostApiService, CacheService, StorageService, ProfileService.

---

## Servicios de Datos

### `lib/data/services/`

| Servicio | Propósito |
|----------|-----------|
| GoogleDirectionsService | Realiza llamadas HTTP a Google Directions API; decodifica polylines por paso; concatena polylines para precisión completa de la ruta |
| AuthApiService | Envuelve las operaciones de Supabase auth (signIn, signUp, OAuth, signOut) |

### `lib/services/`

| Servicio | Propósito |
|----------|-----------|
| LocationTrackingService | Stream de posición GPS via geolocator; gestiona el servicio en primer plano de Android via `ForegroundNotificationConfig`; publica en el canal `geolocator_channel_01` |
| NavigationVoiceService | Texto a voz via flutter_tts; dispara anuncios a 200m y 50m de la siguiente maniobra, y al cambiar de paso |
| NavigationTrackingService | Snap a polyline para precisión GPS; detección de desvío con umbral de 3 segundos / 50 metros |
| MarkerStateManager | Gestiona el estado de los marcadores de Google Maps para participantes en `MapaCompartidoScreen` |
| NotificationService | Registro de token FCM; guarda token en tabla `fcm_tokens`; maneja mensajes FCM entrantes |

---

## Pantallas

```
lib/presentation/views/
├── auth/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   └── reset_password_screen.dart
├── home/
│   └── home_screen.dart              ← navegación inferior, 5 módulos
├── profile/
│   └── profile_screen.dart
├── events/
│   ├── events_screen.dart
│   ├── event_detail_screen.dart
│   └── create_event_screen.dart
├── routes/
│   ├── rutas_screen.dart
│   ├── saved_routes_screen.dart
│   └── map_picker_screen.dart
├── talleres/
│   └── talleres_screen.dart
├── community/
│   └── community_screen.dart
├── grupos/
│   ├── grupos_screen.dart
│   ├── detalle_grupo_screen.dart
│   ├── crear_grupo_screen.dart
│   ├── editar_grupo_screen.dart
│   ├── unirse_grupo_screen.dart
│   └── mapa_compartido_screen.dart   ← StatefulWidget, estado local
└── navigation/
    └── navigation_screen.dart        ← instancia NavigationBloc con todas las dependencias
```

---

## Versiones de Paquetes Principales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| flutter_bloc | ^8.1.3 | Gestión de estado BLoC |
| equatable | ^2.0.5 | Igualdad por valor para eventos/estados del BLoC |
| supabase_flutter | ^2.9.0 | Cliente Supabase + Realtime + Auth |
| google_maps_flutter | ^2.12.0 | Renderizado de mapas |
| geolocator | ^11.0.0 | GPS + servicio en primer plano Android |
| permission_handler | ^11.0.0 | Permisos en tiempo de ejecución |
| flutter_tts | ^4.2.0 | Texto a voz para guía de navegación |
| firebase_messaging | ^15.2.5 | Notificaciones push FCM |
| flutter_local_notifications | ^18.0.1 | Visualización de notificaciones locales |
| http | ^0.13.6 | Llamadas HTTP a Google Directions API |
| shared_preferences | ^2.2.2 | Persistencia del tema |
| app_links | ^6.4.0 | Deep links |
| package_info_plus | ^8.0.0 | Visualización de versión de la app |
