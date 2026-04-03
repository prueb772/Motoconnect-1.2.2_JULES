# Módulo de Grupos

**Pantallas**: `grupos_screen.dart`, `detalle_grupo_screen.dart`, `crear_grupo_screen.dart`, `editar_grupo_screen.dart`, `unirse_grupo_screen.dart`, `mapa_compartido_screen.dart`
**Repository**: `GrupoRepository`
**Estado**: GruposBloc para pantallas de lista/detalle; `MapaCompartidoScreen` usa estado local de StatefulWidget

---

## Ciclo de Vida de un Grupo

### Crear un Grupo

1. El usuario completa nombre, descripción y foto opcional en `crear_grupo_screen.dart`.
2. `GrupoRepository` inserta en `grupos_ruta` con `creado_por = auth.uid()`.
3. El trigger de base de datos `trigger_agregar_creador_admin` se activa → `agregar_creador_como_admin()` inserta al creador en `miembros_grupo` con `es_admin = true`.
4. `generar_codigo_invitacion()` genera un código alfanumérico único de 6 caracteres almacenado en `codigo_invitacion`.

### Flujo del Código de Invitación

- El código de invitación se muestra en `detalle_grupo_screen.dart` para que los administradores lo compartan.
- `unirse_grupo_screen.dart` acepta la entrada del código. La coincidencia se realiza consultando `grupos_ruta WHERE codigo_invitacion = input`.
- Tras encontrar el grupo, se envía una solicitud de ingreso.

### Flujo de Solicitud de Ingreso

1. El usuario envía la solicitud → INSERT en `solicitudes_grupo` con `estado = 'pendiente'`.
2. El administrador del grupo ve las solicitudes pendientes en `solicitudes_pendientes_dialog.dart` (accesible desde `detalle_grupo_screen.dart`).
3. El administrador aprueba o rechaza:
   - Aprobada: `estado` → `'aprobada'`, el usuario se inserta en `miembros_grupo`.
   - Rechazada: `estado` → `'rechazada'`, se almacena `motivo_rechazo` opcional.

### Bloquear un Usuario

- El administrador puede bloquear a un miembro → INSERT en `usuarios_bloqueados_grupo`.
- Los usuarios bloqueados quedan excluidos de las operaciones del grupo a nivel de aplicación.
- El registro de bloqueo almacena `bloqueado_por` (admin que actuó) y `motivo` opcional.

---

## Ciclo de Vida de una Sesión

### Crear una Sesión

1. El líder de la sesión (cualquier miembro aprobado del grupo) presiona "Iniciar sesión" en `detalle_grupo_screen.dart`.
2. INSERT en `sesiones_ruta_activa` con `estado = 'activa'`, `iniciada_por = auth.uid()`.
3. Dos triggers se activan inmediatamente:
   - `trigger_aprobar_creador` → `aprobar_creador_sesion()`: inserta al líder en `participantes_sesion` con `estado_aprobacion = 'aprobado'`.
   - `trigger_session_started` → `notify_session_started()`: llama a la edge function `send-session-notification` para notificar a los miembros del grupo via FCM.
4. Se abre `MapaCompartidoScreen`.

### Unirse a una Sesión

1. El miembro ve la sesión activa en `detalle_grupo_screen.dart`.
2. Presionar "Unirse" → INSERT en `participantes_sesion` con `estado_aprobacion = 'pendiente'`.
3. `trigger_member_joined` se activa en UPDATE → `notify_member_joined()`: notifica al líder via FCM.
4. El líder aprueba en el panel de participantes → UPDATE `estado_aprobacion = 'aprobado'`.
5. El GPS del miembro aprobado se activa (`tracking_activo = true`).

### Finalizar una Sesión

- El líder o administrador presiona "Finalizar sesión" en el panel de participantes.
- UPDATE `sesiones_ruta_activa.estado = 'finalizada'`, `fecha_fin = now()`.
- `trigger_session_ended` se activa → `notify_session_ended()`: notifica a todos los participantes via FCM.
- Todos los streams GPS se cancelan.

---

## Internos de MapaCompartidoScreen

**Archivo**: `lib/presentation/views/grupos/mapa_compartido_screen.dart`
**Tipo**: `StatefulWidget` — NO usa BLoC. Usa estado local para datos en tiempo real porque los streams de Supabase Realtime requieren gestión directa del ciclo de vida del widget.

### 6 StreamSubscriptions

| # | Suscripción | Tabla/Canal Fuente | Datos |
|---|-------------|---------------------|-------|
| 1 | participantes | Realtime `participantes_sesion` | Lista de participantes, estados de aprobación, flags de rastreo |
| 2 | ubicaciones | Realtime `ubicaciones_tiempo_real` | Posiciones GPS en tiempo real de todos los participantes |
| 3 | navigationProgress | Realtime `progreso_navegacion_tiempo_real` | Progreso de paso de navegación por participante |
| 4 | rutaCompartida | Realtime `rutas_sesion` | Polyline de ruta compartida de la sesión |
| 5 | estadoSesion | Realtime `sesiones_ruta_activa` | Cambios de estado de la sesión (activa/pausada/finalizada) |
| 6 | conectado | Stream del plugin Connectivity | Detección de conectividad de red local |

Todas las suscripciones se cancelan en `dispose()`.

### Estados de Conexión (`_EstadoConexion`)

Indica la frescura del GPS de cada participante basándose en `ultima_actualizacion` en `ubicaciones_tiempo_real`.

| Estado | Condición | Visual |
|--------|-----------|--------|
| `activo` | Última actualización hace menos de 60 segundos | Indicador verde |
| `sinActualizacion` | Última actualización hace 60–180 segundos | Indicador ámbar |
| `sinConexion` | Última actualización hace más de 180 segundos | Indicador gris |
| `pausado` | El usuario pausó manualmente el rastreo | Indicador naranja |

### Sistema de Roles

| Variable | Fuente | Significado |
|----------|--------|-------------|
| `_esLider` | `sesion.iniciada_por == currentUserId` | Líder de sesión — control total |
| `_esAdminGrupo` | `miembros_grupo.es_admin == true` | Administrador del grupo — puede gestionar la sesión |
| `_estaAprobado` | `participantes_sesion.estado_aprobacion == 'aprobado'` | Aprobado para participar |

### AppBar

- Punto verde pulsante cuando el rastreo GPS está activo (`tracking_activo = true` para el usuario actual).
- Botón "Solicitudes" (solo visible para `_esLider`) — abre `SolicitudesPendientesDialog`.
- `TextButton.icon` con etiqueta:
  - "Iniciar ruta" — cuando `_esLider` y no existe ruta compartida.
  - "Cancelar ruta" — cuando `_esLider` y hay una ruta compartida activa.
- **Sin menú de desbordamiento** — el menú de 3 puntos superior derecho fue eliminado. Todas las acciones están en el panel de participantes.

### Panel de Participantes

Embebido, con visibilidad alternada. Cada fila de participante muestra nombre, indicador de estado de conexión y velocidad.

Para la fila del usuario actual (`esMiUsuario == true`), aparece un menú contextual de 3 puntos con las siguientes opciones:

| Acción | Condición de Visibilidad |
|--------|--------------------------|
| "Pausar ubicación" / "Reanudar ubicación" | Siempre — alterna `tracking_activo` |
| "Finalizar viaje" | Solo cuando `_navigationSteps != null` (navegación giro a giro activa) |
| "SOS / Emergencia" | Siempre — llama a `send-session-notification` con `event_type = 'sos'` |
| "Salir de la sesión" | Solo para usuarios que NO son líder NI administrador |
| "Finalizar sesión" | Solo para `_esLider` O `_esAdminGrupo` |

### Navegación Dentro de una Sesión

Cuando existe una ruta compartida (registro en `rutas_sesion`), el líder puede iniciar la navegación giro a giro para el grupo. La navegación se ejecuta como **estado local** dentro de `MapaCompartidoScreen`:

- `_navigationSteps` — lista de objetos `NavigationStep`; `null` significa que no hay navegación activa.
- Establecer `_navigationSteps != null` activa el modo de navegación.
- La guía de voz es provista por `NavigationVoiceService` a 200m y 50m de proximidad.
- Umbral de detección de desvío: 3 segundos fuera de la polyline (tolerancia de 50 metros).
- La detección de desvío usa la posición GPS **cruda** (`rawLocation`), no la posición snapeada a polyline. Esto es crítico: usar la posición snapeada siempre devuelve un punto sobre la polyline, impidiendo que se detecte el desvío.
- El flag `_isRecalculating` evita recálculos concurrentes cuando se detecta un desvío. Se pone en `true` al iniciar el recálculo y se resetea a `false` al completar (o al producirse un error).
- El snap a polyline se aplica solo para precisión visual en el mapa en cada actualización de posición.
- El progreso se transmite a los miembros del grupo via `progreso_navegacion_tiempo_real` (visible en la suscripción 3).
- Al completar el recálculo, `_navigationLocationSubscription` se cancela antes de reiniciar la guía de voz para evitar suscripciones duplicadas.

---

## Resumen de RLS para Grupos/Sesiones

### Grupos (`grupos_ruta`)
- SELECT: público (todos los usuarios autenticados pueden leer grupos).
- INSERT: solo el creador (`creado_por = auth.uid()`).
- UPDATE: **true — cualquier usuario autenticado puede actualizar cualquier grupo** (brecha conocida).
- DELETE: solo el creador.

### Miembros del Grupo (`miembros_grupo`)
- Todas las operaciones: `true` — completamente permisivo a nivel de BD.

### Sesiones (`sesiones_ruta_activa`)
- SELECT: líder de sesión, participantes o cualquier miembro del grupo.
- INSERT: solo el líder (`iniciada_por = auth.uid()`).
- UPDATE: líder de sesión O administrador del grupo.
- DELETE: solo el líder de sesión.

### Participantes de Sesión (`participantes_sesion`)
- SELECT: público.
- INSERT/UPDATE/DELETE: propio registro, o líder de sesión.

---

## Casos Borde

### Condición de Carrera en el Flujo de Aprobación
La aprobación automática del líder via trigger (`aprobar_creador_sesion`) inserta en `participantes_sesion` antes de que la pantalla se suscriba. Al abrir la pantalla, la consulta inicial recupera el registro aprobado existente.

### Detección de Pérdida de Conexión
El flag `conexion_perdida` en `participantes_sesion` (migración 2026-03-18) se establece en `true` por la aplicación cuando el `_EstadoConexion` de un participante transiciona a `sinConexion`. Persiste entre reconexiones y es visible para el líder.

### REPLICA IDENTITY FULL
`participantes_sesion` tiene `REPLICA IDENTITY FULL` (migración 2026-03-19). Esto garantiza que los eventos DELETE de Supabase Realtime incluyan los datos completos de la fila antigua, permitiendo a la app identificar qué participante fue eliminado sin una consulta adicional.

### Ruta Única por Sesión
`rutas_sesion.sesion_id` tiene una restricción UNIQUE. Intentar compartir una segunda ruta requiere eliminar o reemplazar el registro existente.
