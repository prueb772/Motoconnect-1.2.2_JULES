# Módulo de Talleres

## Descripción

Directorio de talleres mecánicos para motos. Los usuarios pueden registrar talleres con ubicación GPS, ver el detalle con teléfono y horario, y encontrar talleres cercanos usando búsqueda geoespacial (PostGIS).

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `lib/presentation/views/talleres/talleres_screen.dart` | Listado de talleres |
| `lib/presentation/blocs/talleres/talleres_bloc.dart` | Estado del módulo |
| `lib/data/repositories/taller_repository.dart` | Repositorio |
| `lib/data/services/api/taller_api_service.dart` | Servicio Supabase |
| `lib/domain/usecases/talleres/get_talleres_usecase.dart` | Casos de uso |

---

## Datos de taller (Map<String, dynamic>)

Los talleres se representan como `Map<String, dynamic>` directamente desde la consulta Supabase. Campos relevantes:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | uuid | Identificador del taller |
| nombre | text | Nombre del taller (NOT NULL) |
| direccion | text? | Dirección del establecimiento |
| telefono | text? | Número de contacto |
| horario | text? | Texto libre del horario |
| latitud / longitud | numeric? | Coordenadas GPS |
| creado_por | uuid? | usuario_id del creador |

---

## Tabla `talleres`

```
id uuid PK
nombre text NOT NULL
direccion text
telefono text
horario text
latitud / longitud numeric
ubicacion geography  ← generada automáticamente por trigger PostGIS
creado_por uuid FK→usuarios
created_at timestamptz
```

> La columna `ubicacion` es generada automáticamente por el trigger `trigger_talleres_ubicacion` que convierte `latitud`/`longitud` a un punto geography. Nunca se escribe directamente.

---

## Búsqueda Geoespacial

La función SQL `buscar_talleres_cercanos(lat, lng, radio_metros)` usa PostGIS `ST_DWithin` para encontrar talleres dentro de un radio, lo que es más eficiente que calcular distancias en la app:

```sql
SELECT *, ST_Distance(ubicacion, ST_MakePoint(lng, lat)::geography) AS distancia
FROM talleres
WHERE ST_DWithin(ubicacion, ST_MakePoint(lng, lat)::geography, radio_metros)
ORDER BY distancia;
```

En Flutter:
```dart
final talleres = await _tallerRepository.getTalleresNearby(
  latitude: userLat,
  longitude: userLng,
  radiusKm: 10.0,
);
```

---

## Casos de Uso (`GetTalleresUseCase`)

| Método | Descripción |
|--------|-------------|
| `call()` | Obtiene todos los talleres |
| `getNearby({lat, lng, radiusKm})` | Talleres dentro de un radio |
| `search(query)` | Búsqueda por nombre (mínimo 3 caracteres) |
| `getByCategory(category)` | Por categoría de servicio |
| `getTopRated({limit})` | Top talleres (limit primeros) |
| `getFavorites(userId)` | Talleres registrados por el usuario |
| `getPaginated({page, limit})` | Listado paginado |

---

## Pantalla de Detalle (`TallerDetailScreen`)

Muestra la información real disponible en la BD:
- **Header:** nombre del taller y dirección
- **Contacto:** teléfono con acción de llamada
- **Horario:** texto libre del horario
- **Ubicación:** dirección con botón "Cómo llegar" (pendiente integración Google Maps)
- **Acciones:** "Agendar cita" (funcionalidad pendiente) y botón de llamada directa

---

## Estado del BLoC (`TalleresBloc`)

```dart
// Estados
enum TalleresStatus { initial, loading, loaded, error, processing, deleted }

class TalleresState {
  final TalleresStatus status;
  final List<Map<String, dynamic>> talleres;
  final String? errorMessage;
}

// Eventos activos
class TalleresLoadRequested extends TalleresEvent {}
class TalleresRefreshRequested extends TalleresEvent {}
class TalleresSearchRequested extends TalleresEvent { final String query; }
class TallerAddRequested extends TalleresEvent { /* datos del taller */ }
class TallerDeleteRequested extends TalleresEvent { final String tallerId; }
class TalleresErrorCleared extends TalleresEvent {}
```
