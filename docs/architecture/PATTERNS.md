# Patrones de Diseño — MotoConnect

Este documento describe los patrones de diseño utilizados en el código base a partir de la versión 1.2.1+1.

---

## 1. Patrón BLoC

Toda la gestión de estado usa `flutter_bloc`. Los BLoCs siguen la estructura `Evento → BLoC → Estado`. Los estados y eventos extienden `Equatable` para comparación por valor.

### BLoCs Globales vs. Por Pantalla

| BLoC | Alcance | Provisto en |
|------|---------|-------------|
| AuthBloc | Global | Raíz de `MaterialApp` via `BlocProvider` |
| ThemeCubit | Global | Raíz de `MaterialApp` via `BlocProvider` |
| Todos los demás BLoCs | Por pantalla | `BlocProvider` en el árbol de widgets de cada pantalla o ruta |

Los BLoCs globales se instancian una vez durante la vida de la app. Los BLoCs por pantalla se crean cuando se abre la pantalla y se destruyen cuando se cierra.

### Patrón de Acceso al BLoC

Las pantallas acceden a los BLoCs globales via `context.read<AuthBloc>()` o `context.watch<AuthBloc>()`. Los BLoCs por pantalla se consumen localmente.

---

## 2. Clean Architecture — Implementación Parcial

Clean Architecture está implementada completamente **solo para el módulo de Navegación**:

```
Vista → BLoC → UseCase → Repository → Supabase / Servicio
```

Para todos los demás módulos, la capa UseCase fue eliminada durante la limpieza de código muerto:

```
Vista → BLoC → Repository (si existe) O cliente Supabase directo → Supabase
```

Los módulos sin repositories (RoutesBloc, CommunityBloc, ProfileBloc, TalleresBloc) llaman a `Supabase.instance.client` directamente desde el BLoC. EventsBloc usa `EventRepository`.

Esta inconsistencia es intencional — las capas eliminadas no tenían lógica y eran simples intermediarios.

---

## 3. Modelos Inmutables

Todos los modelos de datos usan:
- Constructores `const` donde sea posible
- Constructor factory `fromJson(Map<String, dynamic>)`
- Método `toJson()` que retorna `Map<String, dynamic>`
- Método `copyWith(...)` para producir copias modificadas

Los modelos no son mutables — los estados del BLoC cargan nuevas instancias del modelo en lugar de modificar las existentes.

---

## 4. Supabase Realtime — Patrón StatefulWidget

Las suscripciones de Supabase Realtime **no se usan dentro de BLoCs**. La única UI en tiempo real de la app es `MapaCompartidoScreen`, que es un `StatefulWidget`.

### Por qué StatefulWidget para Tiempo Real

Los BLoCs no gestionan bien el ciclo de vida de streams de Supabase Realtime porque:
- Los canales Realtime deben cancelarse cuando el widget es destruido.
- `StatefulWidget.dispose()` provee un hook limpio para cancelar 6 suscripciones simultáneas.
- Los datos en tiempo real están acoplados al estado de marcadores del mapa gestionado por `MarkerStateManager`, que también es local al widget.

### Gestión de Suscripciones

Los 6 objetos `StreamSubscription` se almacenan como campos en la clase `_MapaCompartidoScreenState` y se cancelan en `dispose()`:

```
_participantesSubscription?.cancel();
_ubicacionesSubscription?.cancel();
_navigationProgressSubscription?.cancel();
_rutaCompartidaSubscription?.cancel();
_estadoSesionSubscription?.cancel();
_conectadoSubscription?.cancel();
```

---

## 5. Patrón de Servicio en Primer Plano Android para GPS en Segundo Plano

El rastreo GPS debe continuar cuando la app está en segundo plano. Esto se gestiona via el soporte de servicio en primer plano de geolocator en Android.

### Configuración en LocationTrackingService

```dart
// ForegroundNotificationConfig pasado al getPositionStream de geolocator
ForegroundNotificationConfig(
  notificationChannelName: 'geolocator_channel_01',
  notificationTitle: 'MotoConnect',
  notificationText: 'Tracking your location...',
  enableWakeLock: true,
)
```

### Patrón de Pre-creación de Canal de Notificación

geolocator crea `geolocator_channel_01` con `IMPORTANCE_NONE` si no existe previamente, haciendo la notificación del servicio en primer plano invisible y potencialmente causando problemas en algunos dispositivos.

**Solución**: `MainActivity.kt` pre-crea los tres canales de notificación **antes** de que cualquier plugin Flutter pueda crearlos, usando los niveles de importancia correctos:

```kotlin
// MainActivity.kt — creación de canales en configureFlutterEngine()
createNotificationChannel(
    "geolocator_channel_01",
    "Location Tracking",
    NotificationManager.IMPORTANCE_LOW   // era IMPORTANCE_NONE sin esta corrección
)
createNotificationChannel(
    "eventos_channel",
    "Eventos",
    NotificationManager.IMPORTANCE_HIGH
)
createNotificationChannel(
    "sesiones_channel",
    "Sesiones y SOS",
    NotificationManager.IMPORTANCE_HIGH
)
```

Si geolocator intenta crear `geolocator_channel_01` después de esto, Android ignora la llamada porque el canal ya existe con su importancia configurada.

---

## 6. Manejo de Permisos — Resolución de Conflicto de Importación

Tanto `permission_handler` como `geolocator` exportan un enum `ServiceStatus`. Esto causa un error de compilación cuando ambos se importan en el mismo archivo.

**Patrón utilizado**: `hide ServiceStatus` en la importación de `permission_handler`:

```dart
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:geolocator/geolocator.dart'; // ServiceStatus viene de aquí
```

Esto se aplica consistentemente en los archivos que usan ambos paquetes.

---

## 7. Patrón Repository

Los repositories encapsulan toda la lógica de consultas Supabase para una entidad de dominio. Retornan objetos de modelo tipados y lanzan excepciones tipadas en lugar de exponer respuestas raw de Supabase.

Los 4 repositories existentes:
- `GrupoRepository` — grupos, sesiones, participantes, upserts de ubicación en tiempo real, rutas compartidas
- `NavigationRepository` — sesiones de navegación, progreso
- `EventRepository` — eventos, participación
- `AuthRepository` — inicio de sesión, registro, Google OAuth, cierre de sesión

Los BLoCs que no usan repositories (RoutesBloc, CommunityBloc, ProfileBloc, TalleresBloc) llaman a `Supabase.instance.client` directamente.

---

## 8. Patrón de Tema (ThemeCubit)

La preferencia de tema se persiste con SharedPreferences. ThemeCubit es global (provisto en la raíz de la app).

- `ThemeCubit.toggleTheme()` alterna entre claro y oscuro.
- `AppTheme.lightTheme` y `AppTheme.darkTheme` están definidos en `lib/core/theme/app_theme.dart`.
- La UI de selección de tema está en `profile_screen.dart`.
- Al iniciar la app, `ThemeCubit` lee la preferencia guardada desde SharedPreferences.

---

## 9. Deep Links (app_links)

El paquete `app_links` maneja deep links entrantes (ej. links de invitación a grupos). El link se recibe en `main.dart` y se enruta a la pantalla correspondiente.

---

## 10. Qué Fue Eliminado (Patrones a No Reutilizar)

Los siguientes patrones existían en versiones anteriores y fueron eliminados durante la limpieza de ramas MotoConnect_1.2.0 y MotoConnect_1.2.1. No reintroducirlos:

| Eliminado | Motivo |
|-----------|--------|
| HomeBloc | Nunca fue instanciado — código muerto |
| Capa UseCase para Auth, Routes, Community, Talleres, Events | Simples intermediarios sin lógica |
| TallerRepository, PostRepository, UserRepository, RouteRepository | Los BLoCs los ignoraban completamente |
| RouteApiService, TallerApiService, UserApiService, PostApiService | Sin uso |
| CacheService, StorageService, ProfileService | Sin uso |
| GoogleRoadsService | Reemplazado por polylines por paso de GoogleDirectionsService |
| ErrorHandler, Validators, AppConstants utilities | Sin uso |
| `lib/utils/map_colors.dart` | Funcionalidad color_mapa eliminada |
| PauseNavigationUseCase, ResumeNavigationUseCase | Ninguna vista despachaba los eventos correspondientes |
| `lib/data/models/post_model.dart` | Nunca importado en ningún archivo |
| `CommunityPostCreateRequested` (evento) | Duplicado de `CommunityTextPostRequested` / `CommunityMediaPostRequested` |
| `ProfileDeleteRequested`, `ProfileRefreshRequested`, `ProfileChangesDiscarded` (eventos) | Ninguna vista los despachaba |
| `EventDetailLoadRequested`, `EventRegisterRequested`, `EventUnregisterRequested`, `EventSelectionCleared`, `EventsErrorCleared` (eventos) | Operaciones manejadas directamente en las vistas |
| `SavedRoutesFilterChanged` (evento) | UI de filtro eliminada; `displayRoutes` simplificado a `=> routes` |
| Campo `hasUnsavedChanges` en ProfileState | Nunca evaluado por ninguna vista |
| Campo `selectedEvent` en EventsState | Nunca leído por ninguna vista |
| `edit_profile_screen.dart` | Pantalla eliminada; edición integrada en `profile_screen.dart` |
| `taller_detail_screen.dart`, `post_detail_screen.dart`, `create_post_screen.dart` | Pantallas eliminadas |
| `create_route_screen.dart`, `route_detail_screen.dart` | Pantallas eliminadas |
