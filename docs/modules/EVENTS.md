# Módulo de Eventos

## Descripción

Permite crear, descubrir y participar en eventos de rodada. Soporta eventos públicos (visibles para todos) y eventos privados (solo para miembros de grupos específicos). Un evento puede asociarse a múltiples grupos mediante la tabla `evento_grupos`.

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `lib/presentation/views/events/events_screen.dart` | Listado de eventos próximos |
| `lib/presentation/views/events/event_detail_screen.dart` | Detalle, inscripción y mapa del punto de encuentro |
| `lib/presentation/views/events/create_event_screen.dart` | Formulario de creación |
| `lib/presentation/blocs/events/events_bloc.dart` | Estado del módulo |
| `lib/data/models/event_model.dart` | Modelo de evento |
| `lib/data/repositories/event_repository.dart` | Repositorio — accede a Supabase directamente |

---

## Modelo `EventModel`

```dart
class EventModel {
  final String id;
  final String titulo;
  final DateTime fecha;        // NOT NULL — siempre requerido
  final String? descripcion;
  final String creadorId;
  final bool isPublic;
  final String? puntoEncuentro;
  final double? puntoEncuentroLat;
  final double? puntoEncuentroLng;
  final String? destino;
  final double? destinoLat;
  final double? destinoLng;
  final String? fotoUrl;
  final int? maxParticipants;
  final int participantsCount;
  final bool requiresApproval;
  final String estado;          // 'activo' | 'cancelado' | 'finalizado'
  final List<String> gruposIds; // IDs de grupos asociados (via evento_grupos)
  final String? grupoNombre;    // Nombre del primer grupo (join)
}
```

> **Nota:** El campo `grupoId` directo fue eliminado. Los grupos asociados se obtienen via JOIN con `evento_grupos` en el select.

---

## Tablas Involucradas

| Tabla | Uso |
|-------|-----|
| `eventos` | Datos principales del evento |
| `evento_grupos` | Asociación evento ↔ grupos (many-to-many) |
| `participantes_eventos` | Inscritos con estado |

---

## Visibilidad de Eventos (RLS)

La policy `eventos_select_policy` permite ver un evento si:
1. `is_public = true`, O
2. El usuario es el creador (`creado_por = auth.uid()`), O
3. El usuario es miembro de algún grupo asociado al evento (via `evento_grupos` + `miembros_grupo`)

```sql
-- Resumen de la policy
(is_public = true)
OR (creado_por = auth.uid())
OR EXISTS (
  SELECT 1 FROM evento_grupos eg
  JOIN miembros_grupo mg ON mg.grupo_id = eg.grupo_id
  WHERE eg.evento_id = eventos.id AND mg.usuario_id = auth.uid()
)
```

---

## Estado del EventsBloc

El `EventsBloc` tiene únicamente dos eventos activos:

| Evento | Propósito |
|--------|-----------|
| `EventsLoadRequested` | Carga la lista de eventos próximos desde `EventRepository` |
| `EventsRefreshRequested` | Refresca la lista (delega a `EventsLoadRequested`) |

```dart
enum EventsStatus { initial, loading, success, error }

class EventsState {
  final EventsStatus status;
  final List<Event> events;
  final String? errorMessage;
}
```

### Operaciones que NO pasan por EventsBloc

Las siguientes operaciones se realizan directamente en las pantallas via `EventRepository` o Supabase client, sin pasar por el BLoC:

| Operación | Dónde se ejecuta |
|-----------|-----------------|
| Crear evento | `create_event_screen.dart` → `EventRepository` |
| Eliminar evento | `event_detail_screen.dart` → `EventRepository` |
| Confirmar asistencia (Iré / Quizá / No iré) | `event_detail_screen.dart` → Supabase directo |
| Cancelar asistencia | `event_detail_screen.dart` → Supabase directo |

No existe capa de UseCases para este módulo — las pantallas llaman directamente a `EventRepository`.

---

## Notificaciones de Eventos

Al crear un evento, el trigger `trigger_notify_new_event` invoca la Edge Function `send-event-notification`, que envía push a los miembros de los grupos asociados.

Recordatorios automáticos (via `pg_cron`):
- **24h antes** del evento → `reminder_24h_sent = true` (evita duplicados)
- **2h antes** del evento → `reminder_2h_sent = true`

---

## Contador de Participantes

El campo `participants_count` en `eventos` se mantiene automáticamente por el trigger `trigger_participants_count` en la tabla `participantes_eventos`. Solo cuenta participantes con `estado = 'confirmado'`.
