# Módulo de Rutas

## Descripción

Permite a los usuarios crear, visualizar y gestionar rutas de motocicleta. Las rutas se almacenan como arrays de coordenadas GPS y pueden incluir puntos de interés, tipo de vía y calificación escénica.

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `lib/presentation/views/routes/rutas_screen.dart` | Mapa principal con rutas disponibles |
| `lib/presentation/views/routes/saved_routes_screen.dart` | Rutas guardadas del usuario |
| `lib/presentation/views/routes/map_picker_screen.dart` | Selector de ubicación en el mapa |
| `lib/presentation/blocs/routes/routes_bloc.dart` | Estado de rutas disponibles |
| `lib/presentation/blocs/routes/saved_routes/saved_routes_bloc.dart` | Estado de rutas guardadas |
| `lib/data/repositories/route_repository.dart` | Repositorio |
| `lib/data/services/api/route_api_service.dart` | Servicio Supabase |
| `lib/domain/usecases/routes/` | Get, GetSaved, Save, Delete |

---

## Datos de ruta (Map<String, dynamic>)

Las rutas se representan como `Map<String, dynamic>` directamente desde la consulta Supabase. Campos relevantes:

| Campo | Descripción |
|-------|-------------|
| id | UUID de la ruta |
| usuario_id | ID del usuario creador |
| nombre_ruta | Nombre de la ruta |
| descripcion_ruta | Descripción opcional |
| fecha | Timestamp de creación |
| puntos | JSONB — array `[{lat, lng}, ...]` |
| distancia_km | Distancia calculada |
| duracion_minutos | Duración de la ruta |

---

## Tabla `rutas_realizadas`

Ver esquema completo en [`api/SUPABASE_SCHEMA.md`](../api/SUPABASE_SCHEMA.md).

Campos importantes:
- `puntos` — JSONB con array `[{lat, lng}, ...]` que traza la ruta
- `puntos_interes` — JSONB con paradas o lugares de interés
- `estado` — `activa` / `archivada` / `borrador`
- `tipo_via` — carretera, montaña, ciudad, etc.
- `valor_paisajistico` — calificación 1-5

---

## Casos de Uso

### `GetRoutesUseCase`
- `getAllRoutes()` — todas las rutas públicas
- `getRoutesByUser(userId)` — rutas de un usuario
- Ordena por `createdAt` descendente (más recientes primero)

### `GetSavedRoutesUseCase`
- `execute({userId, limit, offset})` — rutas guardadas con paginación
- `getCreatedRoutes()` — rutas creadas por el usuario
- `getFavoriteRoutes()` — rutas de otros usuarios guardadas
- `searchSaved(query)` — búsqueda por nombre en las guardadas
- Ordena por: `createdAt` (default), `name`, `distance`, `rating`

### `SaveRouteUseCase`
- Valida que los puntos GPS no estén vacíos
- Inserta en `rutas_realizadas`

### `DeleteRouteUseCase`
- `deleteOwnRoute(routeId)` — elimina si el usuario es el creador
- `removeFromFavorites(routeId)` — desguarda sin eliminar
- `deactivateRoute(routeId)` — soft delete (cambia `estado` a `inactive`)

---

## MapPickerScreen

Pantalla de selección de ubicación en el mapa. Acepta argumentos opcionales:
- `initialPosition` — `LatLng` inicial del mapa
- `initialSearchQuery` — texto pre-cargado en el buscador

Retorna al hacer `Navigator.pop(context, latLng)` con la ubicación seleccionada.

```dart
final LatLng? result = await Navigator.pushNamed(
  context,
  '/map-picker',
  arguments: {
    'initialPosition': LatLng(4.65, -74.08),
    'initialSearchQuery': 'Bogotá',
  },
);
```
