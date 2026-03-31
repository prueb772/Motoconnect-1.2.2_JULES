# Acceso a Datos — MotoConnect

Toda la comunicación con el backend usa el SDK `supabase_flutter`. No hay endpoints REST propios — todo va directo a Supabase PostgREST o a través de Repositories.

---

## Capa de acceso por módulo

| Módulo | Acceso |
|--------|--------|
| Auth | `AuthApiService` → Supabase Auth |
| Grupos / Sesiones | `GrupoRepository` → Supabase |
| Navegación | `NavigationRepository` → Supabase |
| Eventos | `EventRepository` → Supabase |
| Rutas | `RoutesBloc` → Supabase directo |
| Comunidad | `CommunityBloc` → Supabase directo |
| Talleres | `TalleresBloc` → Supabase directo |
| Perfil | `ProfileBloc` → Supabase directo |
| Notificaciones | `NotificationService` → tabla `fcm_tokens` |
| Direcciones | `GoogleDirectionsService` → HTTP a Google Directions API |

---

## AuthApiService
**Archivo:** `lib/data/services/api/auth_api_service.dart`
**Tabla:** `auth` (Supabase Auth)

| Método | Descripción |
|--------|-------------|
| `signIn(email, password)` | Login con email/password |
| `signUp(email, password, nombre)` | Registro → trigger `handle_new_user` crea fila en `usuarios` |
| `signInWithGoogle()` | OAuth Google |
| `signOut()` | Cierra sesión |
| `getCurrentUser()` | Usuario autenticado actual |
| `getCurrentSession()` | Sesión activa con token |

---

## GrupoRepository
**Archivo:** `lib/data/repositories/grupo_repository.dart`
**Tablas:** `grupos_ruta`, `miembros_grupo`, `solicitudes_grupo`, `usuarios_bloqueados_grupo`, `sesiones_ruta_activa`, `participantes_sesion`, `rutas_sesion`, `ubicaciones_tiempo_real`

Operaciones principales:
- CRUD de grupos (crear, obtener, editar, eliminar)
- Búsqueda por código de invitación
- Gestión de membresías (unirse, salir, bloquear)
- Flujo de solicitudes (crear, aprobar, rechazar)
- Crear / unirse / finalizar sesiones activas
- Streams en tiempo real: ubicaciones, participantes, rutas, estado de sesión

---

## NavigationRepository
**Archivo:** `lib/data/repositories/navigation_repository.dart`
**Tablas:** `sesiones_navegacion`, `progreso_navegacion_tiempo_real`

| Método | Descripción |
|--------|-------------|
| `createNavigationSession(...)` | Crea sesión con pasos y polyline |
| `getNavigationSession(id)` | Obtiene sesión por ID |
| `getUserNavigationSessions(limit)` | Historial del usuario |
| `updateNavigationSession(...)` | Actualiza paso actual, distancia, estado |
| `upsertNavigationProgress(...)` | UPSERT progreso tiempo real |
| `clearNavigationProgress(sessionId)` | DELETE progreso al finalizar |
| `streamGroupNavigationProgress(sesionId)` | Stream del progreso del grupo |

---

## EventRepository
**Archivo:** `lib/data/repositories/event_repository.dart`
**Tablas:** `eventos`, `evento_grupos`, `participantes_eventos`

Operaciones principales:
- `getUpcomingEvents()` — eventos futuros con `estado = 'activo'`
- `getEventById(id)` — detalle con join a `evento_grupos` → `grupos_ruta`
- `createEvent(data)` — crea evento + filas en `evento_grupos`
- `updateEvent(id, data)` — actualiza evento + sincroniza `evento_grupos`
- `deleteEvent(id)` — elimina evento
- `joinEvent(eventId)` — inscribirse
- `leaveEvent(eventId)` — abandonar
- `getEventParticipants(eventId)` — lista con join a `usuarios`

---

## GoogleDirectionsService
**Archivo:** `lib/data/services/navigation/google_directions_service.dart`

Cliente HTTP para Google Directions API (no usa SDK de Google).

| Método | Descripción |
|--------|-------------|
| `getDirections(origin, destination, ...)` | Petición HTTP con timeout 10s, retorna `DirectionsResponse` |
| `recalculateRoute(currentLocation, destination)` | Alias de getDirections para recálculo |
| `extractNavigationSteps(response)` | Convierte respuesta a `List<NavigationStep>` |
| `extractCompletePolyline(response)` | Concatena polylines de cada step (alta precisión) |
| `decodePolyline(encoded)` | Algoritmo de decodificación de Google |

> **Nota:** Se usan polylines por step (no `overview_polyline`) para mayor precisión en snap-to-polyline.

---

## NotificationService
**Archivo:** `lib/services/notification_service.dart`
**Tabla:** `fcm_tokens`

| Método | Descripción |
|--------|-------------|
| `saveToken(userId, token)` | UPSERT del token FCM del dispositivo |
| `deleteToken(token)` | Eliminar token al cerrar sesión |
| Inicialización | Configura handlers de FCM en foreground y background |

---

## Acceso Directo desde BLoC

Los siguientes BLoCs acceden directamente a Supabase sin pasar por una clase Repository:

| BLoC | Tablas que accede |
|------|-------------------|
| `RoutesBloc` / `SavedRoutesBloc` | `rutas_realizadas` |
| `CommunityBloc` | `comentarios_comunidad`, `usuarios` |
| `TalleresBloc` | `talleres`, función `buscar_talleres_cercanos` |
| `ProfileBloc` | `usuarios`, bucket `avatars` |
