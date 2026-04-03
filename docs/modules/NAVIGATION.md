# Módulo de Navegación (Giro a Giro)

**Archivos**:
- `lib/presentation/views/navigation/navigation_screen.dart`
- `lib/presentation/blocs/routes/navigation/navigation_bloc.dart`
- `lib/presentation/blocs/routes/navigation/navigation_state.dart`
- `lib/data/services/navigation/google_directions_service.dart`
- `lib/services/navigation_tracking_service.dart`
- `lib/services/navigation_voice_service.dart`
- `lib/data/models/navigation_step.dart`
- `lib/domain/usecases/navigation/` (4 casos de uso)
- `lib/data/repositories/navigation_repository.dart`

---

## Dos Contextos de Navegación

### 1. Navegación Individual (NavigationScreen + NavigationBloc)

Se usa cuando el usuario navega una ruta guardada de forma independiente, fuera de una sesión grupal.

- Punto de entrada: `navigation_screen.dart`
- Gestionado por `NavigationBloc`
- Única capa de UseCases en toda la app
- Ruta obtenida desde Google Directions API
- Progreso persistido en `sesiones_navegacion` y opcionalmente transmitido a `progreso_navegacion_tiempo_real`
- Rutas completadas pueden guardarse en `rutas_realizadas`

### 2. Navegación en Sesión Grupal (Estado local de MapaCompartidoScreen)

Se usa cuando una sesión tiene una ruta compartida activa (`rutas_sesion`) y el líder inicia la navegación.

- Punto de entrada: `mapa_compartido_screen.dart` (StatefulWidget)
- Estado de navegación gestionado en la variable local `_navigationSteps` — sin BLoC
- `_navigationSteps == null` significa sin navegación activa; `!= null` significa navegación activa
- La guía de voz y detección de desvíos funcionan igual que en la navegación individual
- Progreso transmitido a los miembros del grupo via suscripción Realtime en `progreso_navegacion_tiempo_real`

---

## NavigationBloc

**Ubicación**: `lib/presentation/blocs/routes/navigation/navigation_bloc.dart`

### Eventos Activos

| Evento | Propósito |
|--------|-----------|
| NavigationStartRequested | Inicia navegación — dispara obtención de ruta y creación de sesión |
| NavigationProgressUpdated | Llamado en cada posición GPS — avanza paso, actualiza distancia |
| NavigationEndRequested | Completa o cancela la sesión, opcionalmente guarda la ruta |
| NavigationRecalculateRequested | Disparado tras detección de desvío — obtiene nueva ruta desde posición actual |

### Estados

| Estado | Significado |
|--------|-------------|
| NavigationInitial | Sin navegación activa |
| NavigationLoading | Obteniendo ruta o inicializando sesión |
| NavigationActive | Navegación en progreso — contiene paso actual, distancia y ETA |
| NavigationCompleted | Destino alcanzado o finalización manual |
| NavigationError | Estado de error con mensaje |
| NavigationOffRoute | Desvío detectado, esperando recálculo |

### Dependencias

NavigationBloc se instancia en `navigation_screen.dart` con todas las dependencias inyectadas:

- `StartNavigationUseCase`
- `UpdateNavigationProgressUseCase`
- `EndNavigationUseCase`
- `RecalculateRouteUseCase`
- `LocationTrackingService`
- `NavigationVoiceService`
- `NavigationTrackingService`

---

## Casos de Uso (solo módulo de Navegación)

Ubicados en `lib/domain/usecases/navigation/`:

| UseCase | Operaciones Principales |
|---------|------------------------|
| StartNavigationUseCase | Llama a GoogleDirectionsService; decodifica polylines de pasos; crea registro en `sesiones_navegacion` en Supabase |
| UpdateNavigationProgressUseCase | Hace snap de posición GPS a la polyline; determina paso actual; calcula distancia restante; hace upsert en `progreso_navegacion_tiempo_real` |
| EndNavigationUseCase | UPDATE `sesiones_navegacion.estado = 'completed'` o `'cancelled'`; opcionalmente INSERT en `rutas_realizadas` |
| RecalculateRouteUseCase | Llama a GoogleDirectionsService desde la posición GPS actual hasta el destino original; reemplaza los pasos actuales |

---

## GoogleDirectionsService

**Ubicación**: `lib/data/services/navigation/google_directions_service.dart`

**Protocolo**: HTTP — llama a Google Directions API directamente via el paquete `http`. No usa el SDK de Google Maps para enrutamiento.

### Polylines por Paso (Detalle de Implementación Crítico)

El servicio usa **polylines a nivel de paso**, no la polyline general de resumen:

- Cada paso en la respuesta de Directions API tiene su propio string codificado `polyline.points`.
- Todas las polylines de pasos se decodifican individualmente y se concatenan en una sola lista de puntos `LatLng`.
- Esto produce significativamente más precisión que usar la polyline de resumen, que es una aproximación simplificada.
- La polyline concatenada se guarda en `sesiones_navegacion.polyline_completa`.

### Modelo de Respuesta

`DirectionsResponse` — contiene:
- `List<NavigationStep>` pasos
- Distancia total en metros
- Duración total en segundos
- Puntos de polyline concatenados

---

## Modelo NavigationStep

**Ubicación**: `lib/data/models/navigation_step.dart`

| Campo | Tipo | Propósito |
|-------|------|-----------|
| id | String | Identificador del paso |
| startLocation | LatLng | Punto GPS de inicio del paso |
| endLocation | LatLng | Punto GPS de fin del paso |
| instruction | String | Instrucción sin HTML (ej. "Gira a la izquierda en Av. Insurgentes") |
| maneuver | String | Tipo de maniobra (turn-left, turn-right, straight, etc.) |
| distanceMeters | double | Distancia del paso en metros |
| durationSeconds | int | Duración estimada del paso |
| polylinePoints | List\<LatLng\> | Puntos de polyline del paso decodificados |

---

## NavigationTrackingService

**Ubicación**: `lib/services/navigation_tracking_service.dart`

### Snap a Polyline

En cada actualización de posición GPS, el servicio proyecta la posición del usuario sobre el segmento más cercano de la polyline de la ruta. Esto elimina el ruido GPS y mantiene el marcador del mapa sobre la vía.

### Detección de Desvío

- Umbral: **50 metros** desde el punto de polyline más cercano (medido con posición GPS cruda, no snappeada).
- Requisito temporal: la posición debe permanecer fuera de ruta durante **3 segundos consecutivos** antes de disparar.
- Al detectar: se activa el recálculo de ruta (`RecalculateRouteUseCase` en NavigationBloc, `_calcularPolylineHaciaDestinoConRetry` en MapaCompartidoScreen).
- El retardo de 3 segundos evita falsos positivos por saltos momentáneos del GPS.
- Un flag `_isRecalculating` evita recálculos concurrentes en MapaCompartidoScreen.

---

## NavigationVoiceService

**Ubicación**: `lib/services/navigation_voice_service.dart`

**Motor**: paquete `flutter_tts`.

### Activadores de Anuncio

| Activador | Distancia / Condición |
|-----------|-----------------------|
| Acercándose a maniobra (lejos) | 200 metros del punto final del siguiente paso |
| Acercándose a maniobra (cerca) | 50 metros del punto final del siguiente paso |
| Avance de paso | Cuando el índice del paso actual se incrementa |

Los anuncios usan el campo `instruction` del próximo `NavigationStep`. El servicio verifica la proximidad en cada actualización de posición y dispara TTS solo una vez por umbral de distancia (estado rastreado internamente).

---

## Progreso de Navegación (Transmisión Grupal)

Al navegar dentro de una sesión grupal, el progreso se escribe en `progreso_navegacion_tiempo_real` en cada actualización GPS:

| Campo Escrito | Valor |
|--------------|-------|
| sesion_navegacion_id | ID de `sesiones_navegacion` actual |
| usuario_id | `auth.uid()` |
| paso_actual | Índice del paso actual |
| ubicacion_lat / ubicacion_lng | Posición GPS snappeada |
| distancia_siguiente_paso | Metros hasta la siguiente maniobra |
| eta_segundos | Segundos estimados hasta el destino |
| distancia_restante_metros | Distancia restante de la ruta |
| ultima_actualizacion | `now()` |

Los miembros del grupo suscritos en `MapaCompartidoScreen` reciben estas actualizaciones via la suscripción `navigationProgress` en `progreso_navegacion_tiempo_real`.

---

## Tablas de Base de Datos

### sesiones_navegacion

- Un registro por sesión de navegación.
- Valores de `estado`: `planning`, `navigating`, `completed`, `cancelled`, `offRoute`.
- `pasos` (jsonb): array completo de objetos `NavigationStep`.
- `polyline_completa` (jsonb): puntos de polyline concatenados de todos los pasos.
- `paso_actual` y `distancia_recorrida_metros` se actualizan conforme el usuario avanza.

### progreso_navegacion_tiempo_real

- Se hace upsert en cada posición GPS durante la navegación activa.
- Restricciones NOT NULL en `sesion_navegacion_id` y `usuario_id` (aplicadas desde migración 2026-03-20).
- RLS SELECT permite al propio usuario O a miembros del grupo (via cadena JOIN: `sesiones_navegacion → sesiones_ruta_activa → miembros_grupo`).

---

## RLS

### sesiones_navegacion

| Operación | Condición |
|-----------|-----------|
| SELECT | `auth.uid() = usuario_id` — privado para el navegante |
| INSERT | `auth.uid() = usuario_id` |
| UPDATE | `auth.uid() = usuario_id` |
| DELETE | `auth.uid() = usuario_id` |

### progreso_navegacion_tiempo_real

| Operación | Condición |
|-----------|-----------|
| SELECT | `auth.uid() = usuario_id` O usuario es miembro del grupo via cadena de sesión |
| INSERT | `auth.uid() = usuario_id` |
| UPDATE | `auth.uid() = usuario_id` |
| DELETE | `auth.uid() = usuario_id` |

---

## Guardado de Ruta al Finalizar

Cuando `EndNavigationUseCase` finaliza con estado `completed` (destino alcanzado), la app ofrece guardar la ruta:

- INSERT en `rutas_realizadas` con `usuario_id`, `nombre_ruta` (nombre del destino), `puntos` (array de waypoints recorridos), `distancia_km`, `duracion_minutos`.
- Es la misma tabla usada por el módulo de Rutas para rutas guardadas.
