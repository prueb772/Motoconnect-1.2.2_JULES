# Informe de Base de Datos — MotoConnect

**Fecha:** 2026-03-07
**Proyecto:** MotoConnect
**Supabase Project ID:** otxzwutudsruildrtuzy

---

## Visión General

MotoConnect tiene **18 tablas** organizadas en 5 módulos funcionales:

```
USUARIOS & AUTENTICACIÓN   → usuarios
GRUPOS                     → grupos_ruta, miembros_grupo, solicitudes_grupo,
                             usuarios_bloqueados_grupo
EVENTOS                    → eventos, evento_grupos, participantes_eventos
TALLERES                   → talleres
RUTAS & SESIONES EN VIVO   → rutas_realizadas, sesiones_ruta_activa, rutas_sesion,
                             participantes_sesion, sesiones_navegacion,
                             progreso_navegacion_tiempo_real, ubicaciones_tiempo_real
COMUNIDAD & NOTIFICACIONES → comentarios_comunidad, fcm_tokens
```

---

## Módulo 1 — Usuarios y Autenticación

### `usuarios`
**Qué es:** Perfil público de cada motociclista registrado en la app.

**Por qué existe separada de `auth.users`:** Supabase maneja la autenticación en su esquema interno (`auth.users`). Esta tabla extiende ese perfil con datos propios de la app que la autenticación no contempla.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | Mismo UUID que `auth.users.id` — el puente entre autenticación y perfil |
| `correo` | text NOT NULL | Email del usuario |
| `nombre` | text NOT NULL | Nombre real o de registro |
| `apodo` | text | Alias o nickname en la comunidad |
| `modelo_moto` | text | Moto que conduce (ej: "Honda CB300") |
| `foto_perfil_url` | text | URL de avatar en Storage |
| `color_mapa` | integer | Color ARGB del marcador del usuario en el mapa compartido. Default `0` |
| `created_at` / `updated_at` | timestamptz | Auditoría temporal |

**Relación con auth:** Cuando alguien se registra, el trigger `handle_new_user` (en `auth.users`) crea automáticamente el registro en esta tabla tomando el email y nombre del metadata del proveedor OAuth o del formulario.

---

## Módulo 2 — Grupos

### `grupos_ruta`
**Qué es:** Un grupo de motociclistas que se organizan juntos para rutas y eventos.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | Identificador único |
| `nombre` | text NOT NULL | Nombre del grupo |
| `descripcion` | text | Descripción opcional |
| `codigo_invitacion` | text NOT NULL | Código de 6 caracteres para unirse (ej: "AB3X7K"). Generado por `generar_codigo_invitacion()` |
| `creado_por` | uuid FK→usuarios | Quién fundó el grupo |
| `foto_url` | text | Imagen o logo del grupo |
| `activo` | boolean | Si el grupo está activo o disuelto |
| `created_at` / `updated_at` | timestamptz | Auditoría |

**Código de invitación:** Usa caracteres ambiguos eliminados (sin `I`, `O`, `0`, `1`) para facilitar la lectura. Un usuario puede unirse al grupo ingresando este código en la pantalla "Unirse a grupo".

---

### `miembros_grupo`
**Qué es:** Tabla de unión entre `usuarios` y `grupos_ruta`. Registra qué usuarios pertenecen a qué grupos y con qué rol.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `grupo_id` | uuid FK→grupos_ruta | Grupo al que pertenece |
| `usuario_id` | uuid FK→usuarios | Usuario miembro |
| `es_admin` | boolean | `true` = administrador del grupo, `false` = miembro regular |
| `fecha_union` | timestamptz | Cuándo se unió |

**Por qué se relacionan así:** Un usuario puede estar en múltiples grupos y un grupo tiene múltiples usuarios → relación muchos a muchos resuelta con esta tabla intermedia.

**Nota clave:** El creador del grupo automáticamente queda registrado aquí con `es_admin = true` gracias al trigger `trigger_agregar_creador_admin`.

---

### `solicitudes_grupo`
**Qué es:** Flujo de aprobación cuando un usuario quiere unirse a un grupo que requiere aceptación manual.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `grupo_id` | uuid FK→grupos_ruta | Grupo al que solicita entrar |
| `usuario_id` | uuid FK→usuarios | Quien solicita |
| `estado` | text | `pendiente` / `aprobada` / `rechazada` |
| `fecha_solicitud` | timestamptz | Cuándo pidió unirse |
| `fecha_resolucion` | timestamptz | Cuándo se resolvió |
| `resuelto_por` | uuid FK→usuarios | Admin que aprobó/rechazó |
| `fue_bloqueado_antes` | boolean | Si el usuario estaba bloqueado previamente en este grupo |

**Flujo:** Usuario envía solicitud → queda en `pendiente` → admin ve la lista y acepta/rechaza → si acepta, se inserta registro en `miembros_grupo`.

---

### `usuarios_bloqueados_grupo`
**Qué es:** Lista negra por grupo. Un admin puede bloquear a un usuario para que no pueda unirse ni solicitar ingreso.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `grupo_id` | uuid FK→grupos_ruta | Grupo que aplica el bloqueo |
| `usuario_id` | uuid FK→usuarios | Usuario bloqueado |
| `bloqueado_por` | uuid FK→usuarios | Admin que bloqueó |
| `motivo` | text | Razón opcional del bloqueo |
| `fecha_bloqueo` | timestamptz | Cuándo se bloqueó |

**Relación con solicitudes:** El campo `fue_bloqueado_antes` en `solicitudes_grupo` se consulta al procesar solicitudes para saber si el usuario tuvo historial de bloqueo en ese grupo.

---

## Módulo 3 — Eventos

### `eventos`
**Qué es:** Un evento de rodada organizado por un usuario. Puede ser público (visible para todos) o privado (solo para miembros de grupos específicos).

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `titulo` | text NOT NULL | Nombre del evento |
| `descripcion` | text | Descripción detallada |
| `fecha_hora` | timestamptz NOT NULL | Cuándo ocurre |
| `creado_por` | uuid FK→usuarios | Organizador |
| `is_public` | boolean | `true` = cualquiera puede verlo; `false` = solo miembros de grupos asociados |
| `punto_encuentro` | text | Nombre/dirección del punto de encuentro |
| `punto_encuentro_lat/lng` | float | Coordenadas GPS del punto de encuentro |
| `destino` | text | Nombre del destino final |
| `destino_lat/lng` | float | Coordenadas GPS del destino |
| `foto_url` | text | Imagen del evento |
| `max_participants` | integer | Cupo máximo (null = sin límite) |
| `participants_count` | integer | Contador de inscritos confirmados (auto-mantenido por trigger) |
| `requires_approval` | boolean | Si requiere aprobación para inscribirse |
| `estado` | text | `activo` / `cancelado` / `finalizado` |
| `reminder_24h_sent` | boolean | Flag para evitar enviar recordatorio 24h dos veces |
| `reminder_2h_sent` | boolean | Flag para evitar enviar recordatorio 2h dos veces |
| `created_at` / `updated_at` | timestamptz | Auditoría |

---

### `evento_grupos`
**Qué es:** Tabla de unión entre `eventos` y `grupos_ruta`. Un evento privado puede estar dirigido a múltiples grupos.

| Campo | Tipo | Descripción |
|---|---|---|
| `evento_id` | uuid FK→eventos | El evento |
| `grupo_id` | uuid FK→grupos_ruta | Grupo que puede ver/participar en el evento |

**Por qué existe:** Antes un evento solo podía pertenecer a un grupo (campo `grupo_id` directo en `eventos`). Al migrar a esta tabla, un mismo evento puede ser visible para varios grupos simultáneamente → relación muchos a muchos.

**Impacto en seguridad (RLS):** La policy `eventos_select_policy` usa esta tabla para determinar si un usuario puede ver un evento privado: verifica si el usuario es miembro de alguno de los grupos asociados al evento.

---

### `participantes_eventos`
**Qué es:** Registro de usuarios inscritos a un evento y su estado de asistencia.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `evento_id` | uuid FK→eventos | Evento al que se inscribe |
| `usuario_id` | uuid FK→usuarios | Usuario inscrito |
| `estado` | text | `confirmado` / `posible` / `no_asiste` |
| `fecha_registro` | timestamptz | Cuándo se inscribió |

**Contador automático:** El trigger `trigger_participants_count` actualiza `eventos.participants_count` automáticamente en cada INSERT, UPDATE o DELETE sobre esta tabla, evitando tener que hacer COUNT(*) cada vez que se muestra un evento.

---

## Módulo 4 — Talleres

### `talleres`
**Qué es:** Directorio de talleres mecánicos para motos registrados por los usuarios.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `nombre` | text NOT NULL | Nombre del taller |
| `direccion` | text | Dirección física |
| `telefono` | text | Contacto |
| `horario` | text | Horario de atención (texto libre) |
| `latitud` / `longitud` | numeric | Coordenadas GPS |
| `creado_por` | uuid FK→usuarios | Usuario que registró el taller |
| `created_at` | timestamptz | Auditoría |

**Nota PostGIS:** El trigger `trigger_talleres_ubicacion` genera automáticamente una columna `ubicacion` de tipo `geography` (punto geoespacial) a partir de `latitud`/`longitud`. Esto habilita la función SQL `buscar_talleres_cercanos()` que usa `ST_DWithin` para búsqueda por radio en metros, más eficiente que calcular distancias en la app.

---

## Módulo 5 — Rutas y Sesiones en Vivo

Este es el módulo más complejo. Tiene dos conceptos distintos:
- **Rutas guardadas** (`rutas_realizadas`): trayectos que un usuario registra y guarda.
- **Sesiones en vivo** (`sesiones_ruta_activa` + tablas asociadas): rodadas grupales en tiempo real donde los miembros se ven en el mapa.

---

### `rutas_realizadas`
**Qué es:** Ruta grabada o planificada por un usuario. Es el "historial de rutas" de la app.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `usuario_id` | uuid FK→usuarios | Creador de la ruta |
| `nombre_ruta` | text NOT NULL | Nombre descriptivo |
| `descripcion_ruta` | text | Detalles opcionales |
| `puntos` | jsonb NOT NULL | Array de coordenadas `[{lat, lng}, ...]` que trazan la ruta |
| `distancia_km` | numeric | Distancia total calculada |
| `duracion_minutos` | integer | Tiempo estimado |
| `imagen_url` | text | Foto de portada de la ruta |
| `punto_inicio` / `punto_fin` | text | Nombres de inicio y fin |
| `tipo_via` | text | Tipo de camino (carretera, montaña, ciudad, etc.) |
| `valor_paisajistico` | integer (1-5) | Calificación del paisaje |
| `puntos_interes` | jsonb | Array de puntos de parada/interés a lo largo del trayecto |
| `estado` | text | `activa` / `archivada` / `borrador` |
| `created_at` / `updated_at` | timestamptz | Auditoría |

---

### `sesiones_ruta_activa`
**Qué es:** Una rodada grupal en curso. Es la "sala" donde los motociclistas se reúnen virtualmente para rodar juntos y verse en el mapa en tiempo real.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `grupo_id` | uuid FK→grupos_ruta | Grupo que realiza la sesión |
| `ruta_id` | uuid FK→rutas_realizadas | Ruta que van a seguir (opcional) |
| `nombre_sesion` | text NOT NULL | Nombre de la rodada |
| `descripcion` | text | Descripción opcional |
| `iniciada_por` | uuid FK→usuarios | Líder/organizador de la sesión |
| `estado` | text | `activa` / `finalizada` / `pausada` |
| `fecha_inicio` / `fecha_fin` | timestamptz | Duración de la sesión |
| `created_at` / `updated_at` | timestamptz | Auditoría |

**Flujo de creación:** Cuando un líder crea la sesión, el trigger `trigger_aprobar_creador` lo agrega automáticamente a `participantes_sesion` con estado `aprobado`, para que no tenga que aprobarse a sí mismo.

---

### `participantes_sesion`
**Qué es:** Los usuarios que participan (o solicitan participar) en una sesión de ruta activa.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `sesion_id` | uuid FK→sesiones_ruta_activa | Sesión a la que se une |
| `usuario_id` | uuid FK→usuarios | Participante |
| `estado_aprobacion` | text | `pendiente` / `aprobado` / `rechazado` |
| `tracking_activo` | boolean | Si comparte su ubicación en esta sesión |
| `fecha_solicitud` | timestamptz | Cuándo pidió unirse |
| `fecha_aprobacion` | timestamptz | Cuándo fue aprobado |
| `aprobado_por` | uuid FK→usuarios | Quién lo aprobó (normalmente el líder) |
| `created_at` / `updated_at` | timestamptz | Auditoría |

---

### `rutas_sesion`
**Qué es:** Destino compartido durante una sesión activa. El líder puede establecer o cambiar el destino al que todos deben navegar.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `sesion_id` | uuid FK→sesiones_ruta_activa | Sesión a la que aplica |
| `destino_lat / destino_lng` | float NOT NULL | Coordenadas del destino |
| `destino_nombre` | text | Nombre del lugar |
| `compartida_por` | uuid FK→usuarios | Quién fijó el destino |
| `fecha_compartida` | timestamptz | Cuándo se fijó |

---

### `ubicaciones_tiempo_real`
**Qué es:** La posición GPS actual de cada participante dentro de una sesión activa. Es la tabla más "caliente" de la BD — se actualiza constantemente mientras hay sesiones en curso.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `sesion_id` | uuid FK→sesiones_ruta_activa | Sesión a la que corresponde |
| `usuario_id` | uuid FK→usuarios | A quién pertenece la ubicación |
| `latitud / longitud` | numeric NOT NULL | Posición GPS actual |
| `velocidad` | numeric | km/h actual |
| `direccion` | numeric | Heading en grados (0-360) |
| `altitud` | numeric | Metros sobre el nivel del mar |
| `precision_metros` | numeric | Precisión del GPS en metros |
| `ultima_actualizacion` | timestamptz | Timestamp del último GPS fix |

**Por qué está separada:** Aislar las escrituras frecuentes de GPS en su propia tabla evita bloqueos y contención en las tablas de sesiones o participantes.

---

### `sesiones_navegacion`
**Qué es:** Sesión de navegación turn-by-turn de un usuario dentro de una rodada grupal. Almacena la ruta calculada por la API de Google Maps para que todos los participantes la puedan seguir paso a paso.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `usuario_id` | uuid FK→usuarios | Usuario navegando |
| `sesion_grupal_id` | uuid FK→sesiones_ruta_activa | Rodada grupal a la que pertenece |
| `origen_lat/lng` | float NOT NULL | Punto de partida |
| `destino_lat/lng` | float NOT NULL | Destino |
| `destino_nombre` | text | Nombre del destino |
| `steps` | jsonb NOT NULL | Array de instrucciones de navegación (girar aquí, continuar recto, etc.) |
| `polyline` | jsonb NOT NULL | Polilínea codificada de la ruta completa para dibujarla en el mapa |
| `distancia_total_metros` | float NOT NULL | Distancia total de la ruta |
| `duracion_total_segundos` | integer NOT NULL | Duración estimada |
| `estado` | text | `planning` / `active` / `completed` / `cancelled` |
| `paso_actual` | integer | En qué instrucción va el usuario |
| `distancia_recorrida_metros` | float | Cuánto ha avanzado |
| `fecha_inicio` / `fecha_fin` | timestamptz | Duración real de la navegación |
| `created_at` / `updated_at` | timestamptz | Auditoría |

---

### `progreso_navegacion_tiempo_real`
**Qué es:** Estado exacto del avance de un usuario en su navegación, actualizado en tiempo real. Complementa a `sesiones_navegacion` con datos de posición instantánea durante la navegación.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `sesion_navegacion_id` | uuid FK→sesiones_navegacion | A qué sesión de navegación corresponde |
| `usuario_id` | uuid FK→usuarios | El usuario |
| `paso_actual` | integer NOT NULL | Paso de las instrucciones en el que está |
| `ubicacion_lat/lng` | float NOT NULL | Posición GPS actual |
| `distancia_siguiente_paso` | float | Metros hasta la próxima instrucción |
| `eta_segundos` | integer | Tiempo estimado de llegada en segundos |
| `distancia_restante_metros` | float | Total restante hasta el destino |
| `ultima_actualizacion` | timestamptz | Último update de GPS |

**Por qué separada de `sesiones_navegacion`:** La sesión de navegación almacena datos fijos (la ruta calculada, instrucciones). El progreso es un estado mutable que cambia cada pocos segundos — separarlos evita actualizar constantemente la fila principal de la sesión.

---

## Módulo 6 — Comunidad y Notificaciones

### `comentarios_comunidad`
**Qué es:** Feed de publicaciones de la comunidad de motociclistas. A pesar del nombre "comentarios", en realidad son los **posts** del feed social de la app (el nombre es herencia histórica).

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `usuario_id` | uuid FK→usuarios | Autor del post |
| `contenido` | text | Texto del post |
| `titulo` | text | Título opcional |
| `tipo` | text NOT NULL | `texto` / `imagen` / `video` / `ruta_compartida` / `evento_compartido` / `taller_compartido` |
| `media_url` | text | URL de imagen o video subido al Storage |
| `imagen_url` | text | URL de imagen adicional (campo histórico) |
| `categoria` | text | Categoría temática del post |
| `referencia_ruta_id` | uuid FK→rutas_realizadas | Si el post comparte una ruta |
| `referencia_evento_id` | uuid FK→eventos | Si el post comparte un evento |
| `referencia_taller_id` | uuid FK→talleres | Si el post comparte un taller |
| `likes_count` | integer | Contador de likes (mantenido por función, sin tabla de likes activa aún) |
| `comentarios_count` | integer | Contador de comentarios (ídem) |
| `fecha` | timestamptz | Cuándo se publicó |
| `created_at` / `updated_at` | timestamptz | Auditoría |

**Relaciones opcionales:** Las tres FK de referencia solo se llenan según el `tipo` del post. Por ejemplo, un post de tipo `ruta_compartida` tendrá `referencia_ruta_id` con el ID de la ruta y los demás en NULL.

---

### `fcm_tokens`
**Qué es:** Tokens de Firebase Cloud Messaging para enviar notificaciones push a los dispositivos de los usuarios.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | |
| `usuario_id` | uuid FK→usuarios | A quién pertenece el token |
| `token` | text NOT NULL | Token FCM del dispositivo |
| `plataforma` | text NOT NULL | `android` / `ios` / `web` (default: `android`) |
| `created_at` / `updated_at` | timestamptz | Auditoría |

**Por qué existe:** Cada vez que la app se instala/actualiza, Firebase genera un nuevo token. Esta tabla guarda el token más reciente por usuario para que las Edge Functions puedan enviar notificaciones push.

---

## Triggers

| Trigger | Tabla | Cuándo | Qué hace |
|---|---|---|---|
| `trigger_agregar_creador_admin` | `grupos_ruta` | AFTER INSERT | Agrega al creador como admin en `miembros_grupo` automáticamente |
| `trigger_aprobar_creador` | `sesiones_ruta_activa` | AFTER INSERT | Agrega al líder como participante aprobado en `participantes_sesion` |
| `trigger_participants_count` | `participantes_eventos` | AFTER INSERT/UPDATE/DELETE | Mantiene `eventos.participants_count` sincronizado. Solo cuenta estado `confirmado` |
| `trigger_notify_new_event` | `eventos` | AFTER INSERT | Llama a la Edge Function `send-event-notification` para notificar del nuevo evento |
| `trigger_session_started` | `sesiones_ruta_activa` | AFTER INSERT | Llama a `send-session-notification` para notificar al grupo que empezó una rodada |
| `trigger_session_ended` | `sesiones_ruta_activa` | AFTER UPDATE | Cuando `estado` cambia a `finalizada`, notifica al grupo |
| `trigger_member_joined` | `participantes_sesion` | AFTER UPDATE | Cuando `estado_aprobacion` cambia a `aprobado`, notifica al líder de la sesión |
| `trigger_talleres_ubicacion` | `talleres` | BEFORE INSERT/UPDATE | Genera columna `ubicacion` geography a partir de lat/lng para búsquedas espaciales |
| `*_updated_at` (varios) | Múltiples | BEFORE UPDATE | Mantienen `updated_at = NOW()` automáticamente en: `usuarios`, `grupos_ruta`, `rutas_realizadas`, `sesiones_ruta_activa`, `sesiones_navegacion`, `eventos`, `participantes_sesion`, `comentarios_comunidad`, `talleres` |

---

## Funciones de Utilidad

| Función | Qué hace |
|---|---|
| `handle_new_user()` | Crea perfil en `usuarios` cuando alguien se registra por Supabase Auth |
| `generar_codigo_invitacion()` | Genera código aleatorio de 6 chars para grupos (sin I, O, 0, 1 para evitar confusión visual) |
| `agregar_creador_como_admin()` | Usada por trigger: auto-membresía del creador del grupo como admin |
| `aprobar_creador_sesion()` | Usada por trigger: auto-aprobación del líder al crear sesión |
| `actualizar_participants_count()` | Usada por trigger: mantiene el contador de participantes en eventos |
| `actualizar_ubicacion_taller()` | Usada por trigger: convierte lat/lng a punto geography con PostGIS |
| `buscar_talleres_cercanos(lat, lng, radio_metros)` | Búsqueda geoespacial de talleres en un radio dado usando `ST_DWithin` |
| `get_user_grupo_ids(user_id)` | Retorna todos los IDs de grupos donde está el usuario |
| `is_grupo_admin(user_id, grupo_id)` | Verifica si un usuario es admin de un grupo |
| `is_grupo_member(user_id, grupo_id)` | Verifica si un usuario es miembro de un grupo |
| `contar_participantes_por_estado(evento_id, estado)` | Cuenta participantes de un evento filtrando por estado |
| `obtener_conteo_participantes(evento_id)` | Retorna conteo desglosado: confirmados, posibles, no asisten, total |
| `notify_new_event()` | Trigger function: llama Edge Function de notificación al crear evento |
| `notify_session_started()` | Trigger function: notifica al grupo cuando inicia una rodada |
| `notify_session_ended()` | Trigger function: notifica al grupo cuando finaliza una rodada |
| `notify_member_joined()` | Trigger function: notifica al líder cuando se aprueba un participante |

---

## Seguridad — Row Level Security (RLS)

Todas las tablas tienen RLS activado. La lógica general es:

| Regla | Aplica a |
|---|---|
| **Lectura pública** | `rutas_realizadas`, `talleres`, `comentarios_comunidad`, `participantes_eventos` — visibles para cualquier usuario autenticado |
| **Solo el dueño modifica** | Tablas con `usuario_id` o `creado_por` aplican `auth.uid() = campo` para UPDATE/DELETE |
| **Eventos privados** | SELECT en `eventos` verifica: `is_public = true` OR usuario es miembro de algún grupo asociado via `evento_grupos` OR es el creador |
| **Sesiones grupales** | Un usuario solo ve las sesiones donde participa o las inició |
| **Grupos — permisos de admin** | Admins tienen permisos extendidos en `solicitudes_grupo` y `usuarios_bloqueados_grupo` |
| **FCM tokens** | Cada usuario solo gestiona sus propios tokens |
| **Progreso de navegación** | Solo visible para el propio usuario o miembros del grupo de la sesión |

---

## Diagrama de Relaciones

```
auth.users ──────────── usuarios ──────────────────────────────────────────────┐
                            │                                                   │
              ┌─────────────┼──────────────────────┐                           │
              │             │                       │                           │
        grupos_ruta    rutas_realizadas      comentarios_comunidad              │
              │             │                  │    │    │                      │
    ┌─────────┼──────┐      │           (ruta) │    │(ev)│(taller)              │
    │         │      │      │                  │    │    │                      │
miembros   solicitu  bloq   │              eventos  │  talleres                 │
_grupo     des_grupo eados  │                  │    │                           │
    │                       │            evento_    │                           │
    │                       │            grupos     │                           │
    │                       │                  participantes_eventos            │
    │                       │                                                   │
    └───── sesiones_ruta_activa ─────────────────────────────────────────────── ┘
                  │
     ┌────────────┼──────────────┐
     │            │              │
participantes  rutas_sesion  ubicaciones
_sesion                      _tiempo_real
     │
sesiones_navegacion
     │
progreso_navegacion
_tiempo_real
```

---

## Edge Functions (notificaciones)

Las siguientes Edge Functions de Supabase son invocadas por triggers de la BD:

| Edge Function | Invocada por | Descripción |
|---|---|---|
| `send-event-notification` | `trigger_notify_new_event` | Envía push notification cuando se crea un nuevo evento |
| `send-session-notification` | `trigger_session_started`, `trigger_session_ended`, `trigger_member_joined` | Envía notificaciones de inicio/fin de sesión y aprobación de participantes |

Estas funciones reciben el payload via HTTP POST, consultan los `fcm_tokens` de los destinatarios y llaman a la API de Firebase para enviar la notificación al dispositivo.
