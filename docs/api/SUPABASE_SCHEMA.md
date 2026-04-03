# Supabase Schema — Quick Reference

**Project**: otxzwutudsruildrtuzy
**Region**: us-east-2
**Applied Migrations**: 23 (last: 2026-03-21)

> Complete table descriptions, RLS policies, trigger details, and function signatures are in [`docs/database/DATABASE_REPORT.md`](../database/DATABASE_REPORT.md).
> This file is the quick-reference for day-to-day development.

---

## Tables (18)

### usuarios
`id` uuid PK FK·auth.users | `correo` text | `nombre` text | `apodo` text | `modelo_moto` text | `foto_perfil_url` text | `created_at` | `updated_at`

### grupos_ruta
`id` uuid PK | `nombre` text | `descripcion` text | `codigo_invitacion` text UNIQUE | `creado_por` FK·usuarios | `activo` bool | `foto_url` text | `created_at` | `updated_at`

### miembros_grupo
`id` uuid PK | `grupo_id` FK·grupos_ruta | `usuario_id` FK·usuarios | `es_admin` bool | `fecha_union` | `created_at`

### solicitudes_grupo
`id` uuid PK | `grupo_id` FK·grupos_ruta | `usuario_id` FK·usuarios | `estado` (pendiente/aprobada/rechazada) | `motivo_rechazo` text | `created_at` | `updated_at`

### usuarios_bloqueados_grupo
`id` uuid PK | `grupo_id` FK·grupos_ruta | `usuario_id` FK·usuarios | `bloqueado_por` FK·usuarios | `motivo` text | `created_at`

### eventos
`id` uuid PK | `titulo` text | `descripcion` text | `fecha` timestamptz | `punto_encuentro` text nullable | `punto_encuentro_lat` float8 | `punto_encuentro_lng` float8 | `destino` text | `destino_lat` float8 | `destino_lng` float8 | `organizer_id` FK·usuarios | `creado_por` FK·usuarios | `foto_url` text | `max_participantes` int | `status` text | `requires_approval` bool | `is_public` bool | `participants_count` int | `grupo_nombre` text DEPRECATED | `created_at` | `updated_at`

### evento_grupos
`id` uuid PK | `evento_id` FK·eventos | `grupo_id` FK·grupos_ruta

### participantes_eventos
`id` uuid PK | `evento_id` FK·eventos | `usuario_id` FK·usuarios | `estado_asistencia` text | `created_at` | `updated_at`

### talleres
`id` uuid PK | `nombre` text | `direccion` text | `telefono` text | `horario` text | `latitud` float8 | `longitud` float8 | `ubicacion` geography(Point,4326) auto | `creado_por` FK·usuarios | `created_at` | `updated_at`

### rutas_realizadas
`id` uuid PK | `usuario_id` FK·usuarios | `nombre` text | `descripcion` text | `puntos` jsonb | `distancia_km` float8 | `duracion_minutos` int | `tipo` text | `created_at` | `updated_at`

### sesiones_ruta_activa
`id` uuid PK | `grupo_id` FK·grupos_ruta | `ruta_id` FK·rutas_realizadas nullable | `nombre_sesion` text | `descripcion` text | `estado` (activa/pausada/finalizada) | `iniciada_por` FK·usuarios | `fecha_inicio` | `fecha_fin` nullable | `created_at` | `updated_at`

### participantes_sesion
`id` uuid PK | `sesion_id` FK·sesiones_ruta_activa | `usuario_id` FK·usuarios | `estado_aprobacion` (pendiente/aprobado/rechazado) | `tracking_activo` bool | `conexion_perdida` bool | `fecha_solicitud` | `fecha_aprobacion` nullable | `aprobado_por` FK·usuarios nullable | `created_at` | `updated_at`
> REPLICA IDENTITY FULL set for Realtime DELETE events

### rutas_sesion
`id` uuid PK | `sesion_id` FK·sesiones_ruta_activa UNIQUE | `compartida_por` FK·usuarios | `destino_nombre` text | `destino_lat` float8 | `destino_lng` float8 | `ruta_polyline` text | `puntos_intermedios` jsonb nullable | `created_at` | `updated_at`

### ubicaciones_tiempo_real
`id` uuid PK | `sesion_id` FK·sesiones_ruta_activa | `usuario_id` FK·usuarios | `latitud` float8 | `longitud` float8 | `velocidad_kmh` float8 | `heading` float8 | `ultima_actualizacion` | `created_at`

### sesiones_navegacion
`id` uuid PK | `usuario_id` FK·usuarios | `sesion_grupal_id` FK·sesiones_ruta_activa nullable | `origen_lat` float8 | `origen_lng` float8 | `destino_lat` float8 | `destino_lng` float8 | `destino_nombre` text | `pasos` jsonb | `polyline_completa` jsonb | `estado` (planning/navigating/paused/completed/cancelled/offRoute) | `distancia_total_metros` float8 | `duracion_total_segundos` int | `paso_actual` int | `distancia_recorrida_metros` float8 | `created_at` | `updated_at`

### progreso_navegacion_tiempo_real
`id` uuid PK | `sesion_navegacion_id` FK·sesiones_navegacion NOT NULL | `usuario_id` FK·usuarios NOT NULL | `paso_actual` int | `ubicacion_lat` float8 | `ubicacion_lng` float8 | `distancia_siguiente_paso` float8 | `eta_segundos` int | `distancia_restante_metros` float8 | `ultima_actualizacion`

### comentarios_comunidad
`id` uuid PK | `usuario_id` FK·usuarios | `tipo` (texto/imagen/video/ruta_compartida/evento_compartido) | `contenido` text | `media_url` text | `referencia_id` uuid nullable | `created_at` | `updated_at`
> This is the social feed posts table (not a comments table despite the name)

### fcm_tokens
`id` uuid PK | `usuario_id` FK·usuarios | `token` text UNIQUE | `created_at` | `updated_at`

---

## Views (4)

| View | Base Tables | Purpose |
|------|------------|---------|
| vista_participantes_sesion | participantes_sesion + usuarios | Participant list enriched with user display data |
| vista_progreso_navegacion_actual | progreso_navegacion_tiempo_real + sesiones_navegacion + usuarios | Real-time navigation progress with user context |
| vista_solicitudes_grupo | solicitudes_grupo + usuarios | Join requests with requesting user profile data |
| vista_ubicaciones_sesion_actual | ubicaciones_tiempo_real + usuarios + participantes_sesion | Real-time locations with user info and tracking status |

---

## Triggers (17 public + 1 auth.users)

| Trigger | Table | Event | Function |
|---------|-------|-------|----------|
| on_usuarios_updated | usuarios | BEFORE UPDATE | handle_updated_at() |
| trigger_agregar_creador_admin | grupos_ruta | AFTER INSERT | agregar_creador_como_admin() |
| update_grupos_ruta_updated_at | grupos_ruta | BEFORE UPDATE | update_updated_at_column() |
| trigger_participants_count | participantes_eventos | AFTER INSERT/UPDATE/DELETE | actualizar_participants_count() |
| trigger_notify_new_event | eventos | AFTER INSERT | notify_new_event() |
| trigger_eventos_updated_at | eventos | BEFORE UPDATE | actualizar_updated_at() |
| trigger_member_joined | participantes_sesion | AFTER UPDATE | notify_member_joined() |
| trigger_participantes_updated_at | participantes_sesion | BEFORE UPDATE | actualizar_updated_at() |
| trigger_rutas_updated_at | rutas_realizadas | BEFORE UPDATE | actualizar_updated_at() |
| trigger_sesiones_nav_updated_at | sesiones_navegacion | BEFORE UPDATE | actualizar_updated_at() |
| trigger_aprobar_creador | sesiones_ruta_activa | AFTER INSERT | aprobar_creador_sesion() |
| trigger_session_ended | sesiones_ruta_activa | AFTER UPDATE | notify_session_ended() |
| trigger_session_started | sesiones_ruta_activa | AFTER INSERT | notify_session_started() |
| update_sesiones_ruta_updated_at | sesiones_ruta_activa | BEFORE UPDATE | update_updated_at_column() |
| trigger_talleres_ubicacion | talleres | BEFORE INSERT/UPDATE | actualizar_ubicacion_taller() |
| trigger_talleres_updated_at | talleres | BEFORE UPDATE | actualizar_updated_at() |
| trigger_posts_updated_at | comentarios_comunidad | BEFORE UPDATE | actualizar_updated_at() |
| on_auth_user_created | auth.users | AFTER INSERT | handle_new_user() |

---

## Application Functions

| Function | Signature | Active |
|----------|-----------|--------|
| handle_new_user | () → trigger | Yes |
| agregar_creador_como_admin | () → trigger | Yes |
| aprobar_creador_sesion | () → trigger | Yes |
| generar_codigo_invitacion | () → text | Yes |
| buscar_talleres_cercanos | (lat FLOAT, lng FLOAT, radio_metros FLOAT) → SETOF talleres | Yes |
| is_event_creator | (evento_id UUID) → boolean SECURITY DEFINER | Yes |
| is_grupo_admin | (user_id UUID, grupo_id UUID) → boolean | Yes |
| is_grupo_member | (user_id UUID, grupo_id UUID) → boolean | Yes |
| get_user_grupo_ids | (user_id UUID) → UUID[] | Yes |
| obtener_conteo_participantes | (evento_id UUID) → record | Yes |
| contar_participantes_por_estado | (sesion_id UUID, estado text) → integer | Yes |
| actualizar_participants_count | () → trigger | Yes |
| actualizar_ubicacion_taller | () → trigger | Yes |
| notify_new_event | () → trigger | Yes |
| notify_session_started | () → trigger | Yes |
| notify_session_ended | () → trigger | Yes |
| notify_member_joined | () → trigger | Yes |
| actualizar_comentarios_count | () → trigger | Inactive |
| actualizar_likes_count | () → trigger | Inactive |
| handle_updated_at / actualizar_updated_at / update_updated_at_column | () → trigger | Yes (3 variants) |

---

## Edge Functions (3)

| Function | Trigger / Schedule | Handles |
|----------|--------------------|---------|
| send-session-notification | DB triggers + SOS direct call | session_started, session_ended, member_joined, sos |
| send-event-notification | DB trigger (AFTER INSERT eventos) | new_event |
| send-event-reminders | pg_cron scheduled | 24h and 2h event reminders |

---

## Storage Buckets (4)

| Bucket | Access | Used For |
|--------|--------|---------|
| avatars | Public read | User profile photos (`usuarios.foto_perfil_url`) |
| posts | Public read | Community post media (images/videos) |
| eventos | Public read | Event cover photos (`eventos.foto_url`) |
| grupos | Public read | Group photos (`grupos_ruta.foto_url`) |

---

## Migration History

| # | Name | Date |
|---|------|------|
| 1 | drop_unused_tables_and_views | 2026-03-04 |
| 2 | drop_unused_columns_usuarios | 2026-03-04 |
| 3 | alter_eventos_punto_encuentro_nullable | 2026-03-05 |
| 4 | create_evento_grupos_table | 2026-03-05 |
| 5 | session_notification_triggers | 2026-03-06 |
| 6 | drop_unused_talleres_columns | 2026-03-07 |
| 7 | drop_rutas_realizadas_unused_columns | 2026-03-07 |
| 8 | drop_eventos_grupo_id_update_rls | 2026-03-07 |
| 9 | drop_rutas_realizadas_dificultad_creador_nombre | 2026-03-07 |
| 10 | fix_notify_new_event_grupo_id | 2026-03-07 |
| 11 | fix_evento_grupos_rls_infinite_recursion | 2026-03-07 |
| 12 | remove_color_mapa | 2026-03-15 |
| 13 | add_tipo_to_rutas_realizadas | 2026-03-16 |
| 14 | add_conexion_perdida_to_participantes_sesion | 2026-03-18 |
| 15 | replica_identity_full_participantes | 2026-03-19 |
| 16 | drop_trigger_duplicado_usuarios_updated_at | 2026-03-20 |
| 17 | add_not_null_progreso_navegacion_tiempo_real | 2026-03-20 |
| 18 | drop_rls_all_sesiones_ubicaciones | 2026-03-20 |
| 19 | replace_buscar_talleres_cercanos_drop_recreate | 2026-03-20 |
| 20 | rls_grupos_ruta_replace_all_policy | 2026-03-20 |
| 21 | rls_miembros_grupo_replace_all_policy | 2026-03-20 |
| 22 | fix_rls_sesiones_ruta_activa_miembros_grupo | 2026-03-21 |
| 23 | fix_rls_update_sesiones_ruta_activa_admins | 2026-03-21 |
