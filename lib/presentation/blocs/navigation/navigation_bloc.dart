import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/models/ruta_realizada_model.dart';
import '../../../data/models/geo_point.dart';
import '../../../data/models/navigation_session.dart';
import '../../../data/models/navigation_step.dart';
import '../../../data/services/navigation/navigation_tracking_service.dart';
import '../../../domain/usecases/navigation/start_navigation_usecase.dart';
import '../../../domain/usecases/navigation/update_navigation_progress_usecase.dart';
import '../../../domain/usecases/navigation/end_navigation_usecase.dart';
import '../../../domain/usecases/navigation/recalculate_route_usecase.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/navigation_voice_service.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';

/// NavigationBloc - Gestiona el estado de navegación Turn-by-Turn
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc({
    required StartNavigationUseCase startNavigationUseCase,
    required UpdateNavigationProgressUseCase updateProgressUseCase,
    required EndNavigationUseCase endNavigationUseCase,
    required RecalculateRouteUseCase recalculateRouteUseCase,
    required LocationTrackingService locationService,
    required NavigationVoiceService voiceService,
    required NavigationTrackingService trackingService,
    required RoutesRepository routesRepository,
  })  : _startNavigationUseCase = startNavigationUseCase,
        _updateProgressUseCase = updateProgressUseCase,
        _endNavigationUseCase = endNavigationUseCase,
        _recalculateRouteUseCase = recalculateRouteUseCase,
        _voiceService = voiceService,
        _trackingService = trackingService,
        _routesRepository = routesRepository,
        super(const NavigationState()) {
    on<NavigationStartRequested>(_onStartRequested);
    on<NavigationEndRequested>(_onEndRequested);
    on<NavigationRecalculateRequested>(_onRecalculateRequested);
    on<NavigationSaveRouteRequested>(_onSaveRouteRequested);
    on<NavigationErrorCleared>(_onErrorCleared);
    on<_NavigationLocationUpdated>(_onLocationUpdated);
    on<_NavigationProgressAnnouncement>(_onProgressAnnouncement);
  }

  // ========================================
  // DEPENDENCIAS
  // ========================================

  final StartNavigationUseCase _startNavigationUseCase;
  final UpdateNavigationProgressUseCase _updateProgressUseCase;
  final EndNavigationUseCase _endNavigationUseCase;
  final RecalculateRouteUseCase _recalculateRouteUseCase;
  final NavigationVoiceService _voiceService;
  final NavigationTrackingService _trackingService;
  final RoutesRepository _routesRepository;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _progressAnnouncementTimer;

  /// Timestamp cuando se detectó salida de ruta (para auto-recalcular)
  DateTime? _offRouteSince;

  // ── Voice announcement state ────────────────────────────────────────────
  // Centralizar aquí el control de cuándo anunciar evita la lógica fragmentada
  // entre el BLoC y el servicio de voz, que era la causa raíz de las repeticiones.

  /// Índice del último paso que ya fue anunciado al cambiar de paso.
  int? _lastAnnouncedStepIndex;

  /// true si ya se emitió el aviso de "200 metros" para el paso actual.
  bool _proximity200Fired = false;

  /// true si ya se emitió el aviso de "50 metros" para el paso actual.
  bool _proximity50Fired = false;

  /// Segundos fuera de ruta antes de recalcular automáticamente.
  /// 3s = balance entre falsos positivos (GPS drift, rotondas) y reacción rápida.
  /// A 60 km/h, 3s = ~50m recorridos en dirección incorrecta antes de recalcular.
  static const int _offRouteTriggerSeconds = 3;

  // ========================================
  // HANDLERS
  // ========================================

  Future<void> _onStartRequested(
    NavigationStartRequested event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      _offRouteSince = null;

      emit(state.copyWith(
        status: NavigationStatus.planning,
        isCalculating: true,
        clearError: true,
      ));

      final session = await _startNavigationUseCase.execute(
        destination: event.destination,
        destinationName: event.destinationName,
        sesionGrupalId: event.sesionGrupalId,
        mode: event.mode,
      );

      emit(state.copyWith(
        status: NavigationStatus.navigating,
        currentSession: session,
        isCalculating: false,
        remainingPolyline: session.completePolyline,
        realizedTrack: const [],
        realizedDistanceMeters: 0.0, // Reset al iniciar nueva navegación
      ));

      await _voiceService.initialize();

      // Marcar el paso inicial como ya anunciado para que _onLocationUpdated
      // no lo repita al recibir las primeras actualizaciones de GPS.
      _lastAnnouncedStepIndex = session.currentStepIndex;
      _proximity200Fired = false;
      _proximity50Fired = false;

      if (session.currentStep != null) {
        await _voiceService.announceInstruction(
          session.currentStep!.instruction,
          session.currentStep!.distanceText,
        );
      }

      await _startLocationTracking();

      _progressAnnouncementTimer = Timer.periodic(
        const Duration(minutes: 2),
        (timer) => add(const _NavigationProgressAnnouncement()),
      );
    } catch (e) {
      emit(state.copyWith(
        status: NavigationStatus.cancelled,
        isCalculating: false,
        errorMessage: 'Error al iniciar navegación: ${e.toString()}',
      ));
      debugPrint('Error en NavigationBloc._onStartRequested: $e');
    }
  }

  Future<void> _onEndRequested(
    NavigationEndRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession == null) return;

    try {
      await _endNavigationUseCase.execute(
        sessionId: state.currentSession!.id,
        completed: event.completed,
      );

      final newStatus =
          event.completed ? NavigationStatus.completed : NavigationStatus.cancelled;

      await _locationSubscription?.cancel();
      _locationSubscription = null;
      _progressAnnouncementTimer?.cancel();
      _progressAnnouncementTimer = null;
      _offRouteSince = null;

      emit(state.copyWith(status: newStatus));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error al finalizar: ${e.toString()}'));
      debugPrint('Error en NavigationBloc._onEndRequested: $e');
    }
  }

  Future<void> _onRecalculateRequested(
    NavigationRecalculateRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession == null) return;

    try {
      _offRouteSince = null;
      _lastAnnouncedStepIndex = null;
      _proximity200Fired = false;
      _proximity50Fired = false;

      emit(state.copyWith(isCalculating: true));

      // Pasar la ubicación ya conocida del estado para evitar una segunda
      // lectura GPS redundante dentro del use case (ahorra 1-3 segundos).
      final updatedSession = await _recalculateRouteUseCase.execute(
        currentSession: state.currentSession!,
        currentLocation: state.lastKnownLocation,
      );

      // Calcular polyline restante con la nueva ruta
      final remainingPolyline = state.lastKnownLocation != null
          ? _calculateRemainingPolyline(
              state.lastKnownLocation!, updatedSession.completePolyline)
          : updatedSession.completePolyline;

      emit(state.copyWith(
        status: NavigationStatus.navigating,
        currentSession: updatedSession,
        isCalculating: false,
        remainingPolyline: remainingPolyline,
      ));

      // Anunciar nueva instrucción tras recalcular y marcar como anunciada
      if (updatedSession.currentStep != null) {
        _lastAnnouncedStepIndex = updatedSession.currentStepIndex;
        await _voiceService.announceInstruction(
          updatedSession.currentStep!.instruction,
          updatedSession.currentStep!.distanceText,
        );
      }
    } catch (e) {
      emit(state.copyWith(
        isCalculating: false,
        errorMessage: 'Error al recalcular: ${e.toString()}',
      ));
      debugPrint('Error en NavigationBloc._onRecalculateRequested: $e');
    }
  }

  Future<void> _onSaveRouteRequested(
    NavigationSaveRouteRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession == null || !state.isCompleted) {
      emit(state.copyWith(errorMessage: 'No hay sesión completada para guardar'));
      return;
    }

    final uid = _routesRepository.getCurrentUserId();
    if (uid == null) {
      emit(state.copyWith(errorMessage: 'Usuario no autenticado'));
      return;
    }

    try {
      // Usar el track GPS real acumulado durante la navegación.
      // Fallback a completePolyline solo si no se acumularon puntos
      // (ej: llegó sin moverse, caso extremadamente raro).
      final rawTrack = state.realizedTrack.isNotEmpty
          ? state.realizedTrack
          : state.currentSession!.completePolyline;

      // Simplificar con Douglas-Peucker (epsilon 15m) para reducir
      // puntos redundantes manteniendo fidelidad del trayecto real.
      final simplifiedTrack = _trackingService.simplifyTrack(rawTrack, 15.0);

      final puntosJson = simplifiedTrack
          .map((p) => GeoPoint(lat: p.latitude, lng: p.longitude))
          .toList();

      // Usar distancia real acumulada del track GPS, no la planificada de la sesión.
      final distanciaKm = state.realizedDistanceMeters / 1000.0;
      final duracionMinutos = state.currentSession!.elapsedTime.inMinutes;
      final now = DateTime.now();

      final rutaModel = RutaRealizadaModel(
        id: '', // Supabase genera el UUID
        usuarioId: uid,
        nombreRuta: event.routeName,
        fecha: now,
        puntos: puntosJson,
        distanciaKm: distanciaKm,
        duracionMinutos: duracionMinutos,
        descripcionRuta:
            event.routeDescription?.isEmpty == true ? null : event.routeDescription,
        tipo: 'realizada',
        createdAt: now,
        updatedAt: now,
      );

      await _routesRepository.saveRoute(rutaModel);

      emit(state.copyWith(routeSaved: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error al guardar ruta: ${e.toString()}'));
      debugPrint('Error en NavigationBloc._onSaveRouteRequested: $e');
    }
  }

  void _onErrorCleared(NavigationErrorCleared event, Emitter<NavigationState> emit) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onLocationUpdated(
    _NavigationLocationUpdated event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession == null || !state.isNavigating) return;

    try {
      final rawLocation =
          LatLng(event.position.latitude, event.position.longitude);
      final currentSpeedKmh =
          (event.position.speed < 0 ? 0 : event.position.speed) * 3.6;
      final currentHeading =
          event.position.heading < 0 ? 0.0 : event.position.heading;

      // Snap local a la polyline de ruta — sin coste de API.
      // Solo aplica cuando hay ruta activa con al menos 2 puntos.
      final polyline = state.currentSession?.completePolyline ?? const [];
      final LatLng navigationLocation = polyline.length >= 2
          ? _trackingService.snapToPolyline(rawLocation, polyline)
          : rawLocation;

      // ── Track GPS real: acumular posición snapped con filtro 15m ──────
      // Calculamos el segmento ANTES de agregar el punto para acumular la
      // distancia real. El mismo umbral de 15m que usa _appendToTrack garantiza
      // coherencia: si el punto no se agrega, tampoco se suma la distancia.
      double segmentMeters = 0.0;
      if (state.realizedTrack.isNotEmpty) {
        final d = Geolocator.distanceBetween(
          state.realizedTrack.last.latitude,
          state.realizedTrack.last.longitude,
          navigationLocation.latitude,
          navigationLocation.longitude,
        );
        if (d >= 15.0) segmentMeters = d;
      }
      final updatedTrack = _appendToTrack(state.realizedTrack, navigationLocation);
      final newRealizedDistance = state.realizedDistanceMeters + segmentMeters;

      // ── PRIMARY BUG FIX: Update progress (Supabase isolated inside use case) ──
      final updatedSession = await _updateProgressUseCase.execute(
        currentSession: state.currentSession!,
        currentLocation: navigationLocation,
        currentSpeedKmh: currentSpeedKmh,
      );

      // ── Phase 1: Remaining polyline ────────────────────────────────────
      final remainingPolyline = _calculateRemainingPolyline(
        navigationLocation,
        updatedSession.completePolyline,
      );

      // ── BUG FIX: Real distance to next turn ───────────────────────────
      double? distanceToNext;
      if (updatedSession.currentStep != null) {
        distanceToNext = _trackingService.calculateDistanceToStepEnd(
          currentLocation: navigationLocation,
          currentStep: updatedSession.currentStep!,
        );
      }

      // ── Phase 3: Off-route detection + auto-recalculate ───────────────
      if (updatedSession.currentStep != null) {
        final offRoute = _trackingService.isOffRoute(
          currentLocation: navigationLocation,
          currentStep: updatedSession.currentStep!,
        );

        if (offRoute) {
          _offRouteSince ??= DateTime.now();
          final offSeconds =
              DateTime.now().difference(_offRouteSince!).inSeconds;
          if (offSeconds >= _offRouteTriggerSeconds && !state.isCalculating) {
            _offRouteSince = null;
            await _voiceService.announceRecalculating();
            add(const NavigationRecalculateRequested());
            return; // _onRecalculateRequested emitirá el nuevo estado
          }
        } else {
          _offRouteSince = null;
        }
      }

      // ── Distancia al destino final (solo en último paso) ──────────────
      // Se calcula ANTES del emit para incluirla en el estado y que el panel
      // pueda mostrar el botón "Ya llegué" cuando corresponda.
      double? distToDestination;
      if (updatedSession.isLastStep) {
        distToDestination = Geolocator.distanceBetween(
          navigationLocation.latitude,
          navigationLocation.longitude,
          updatedSession.destination.latitude,
          updatedSession.destination.longitude,
        );
      }

      // ── Emit updated state ─────────────────────────────────────────────
      emit(state.copyWith(
        currentSession: updatedSession,
        lastKnownLocation: navigationLocation,
        currentHeading: currentHeading,
        currentSpeedKmh: currentSpeedKmh,
        remainingPolyline: remainingPolyline,
        realizedTrack: updatedTrack,
        realizedDistanceMeters: newRealizedDistance,
        distanceToNextStepMeters: distanceToNext,
        distanceToDestinationMeters: distToDestination,
        clearDistanceToDestination: distToDestination == null,
      ));

      // ── Voice: smart announcement logic ───────────────────────────────
      //
      // Reglas (inspiradas en Google Maps / Waze):
      //   1. Cambio de paso → anunciar inmediatamente con distancia del API.
      //      Inicializar los flags de proximidad según dónde estamos ahora,
      //      para no disparar alertas de 200 m si el paso tiene < 200 m en total.
      //   2. Sin cambio de paso → evaluar alertas de proximidad con distancia real:
      //      - 200 m antes del giro (una sola vez por paso)
      //      - 50 m antes del giro (una sola vez por paso)
      //   No se usan rangos (ej: 200–150 m): basta con la primera vez que
      //   la distancia cruza el umbral hacia abajo.

      final newStepIndex = updatedSession.currentStepIndex;

      if (newStepIndex != _lastAnnouncedStepIndex &&
          updatedSession.currentStep != null) {
        // Cambio de paso: anunciar y resetear flags de proximidad.
        _lastAnnouncedStepIndex = newStepIndex;
        // Si ya estamos a ≤200 m (paso corto), marcar el aviso de 200 m como
        // consumido para evitar re-anunciar lo que acaba de decirse.
        _proximity200Fired = distanceToNext == null || distanceToNext <= 200;
        _proximity50Fired = distanceToNext == null || distanceToNext <= 50;

        await _voiceService.announceInstruction(
          updatedSession.currentStep!.instruction,
          updatedSession.currentStep!.distanceText,
        );
      } else if (distanceToNext != null && updatedSession.currentStep != null) {
        // Sin cambio de paso: avisos de proximidad usando distancia real GPS.
        if (!_proximity200Fired && distanceToNext <= 200) {
          _proximity200Fired = true;
          await _voiceService.announceProximityAlert(
            updatedSession.currentStep!.instruction,
            200,
          );
        } else if (!_proximity50Fired && distanceToNext <= 50) {
          _proximity50Fired = true;
          await _voiceService.announceProximityAlert(
            updatedSession.currentStep!.instruction,
            50,
          );
        }
      }

      // ── Arrival detection (smart) ──────────────────────────────────────
      //
      // Tres niveles progresivos — inspirado en Google Maps / Waze:
      //
      //   Nivel 1 — Radio estricto (50 m):
      //     El usuario está a menos de 50 m del destino exacto.
      //     Cubre destinos al aire libre y GPS preciso.
      //     Se dispara sin importar la velocidad (el usuario está prácticamente encima).
      //
      //   Nivel 2 — Radio ampliado + velocidad baja (80 m, < 20 km/h):
      //     El usuario está a menos de 80 m Y se mueve despacio (estacionado,
      //     caminando, buscando entrada). Cubre edificios, centros comerciales,
      //     conjuntos donde el destino GPS está dentro del polígono pero el
      //     usuario se detiene en la calle o la entrada exterior.
      //     Evita falsos positivos: un motociclista en tráfico a 50 km/h que
      //     pasa cerca no dispara esto.
      //
      //   No se evalúa en pasos intermedios: distToDestination solo está
      //   disponible en el último paso (isLastStep).
      if (distToDestination != null) {
        final autoArrived = distToDestination < 50.0 ||
            (distToDestination < 80.0 && currentSpeedKmh < 20.0);

        if (autoArrived) {
          await _voiceService.announceArrival();
          await _locationSubscription?.cancel();
          _locationSubscription = null;
          _progressAnnouncementTimer?.cancel();
          _progressAnnouncementTimer = null;
          _offRouteSince = null;

          // Finalizar sesión en Supabase: actualiza estado y elimina progreso RT
          if (state.currentSession != null) {
            try {
              await _endNavigationUseCase.execute(
                sessionId: state.currentSession!.id,
                completed: true,
              );
            } catch (e) {
              debugPrint('Error al finalizar sesión tras auto-arrival: $e');
            }
          }

          emit(state.copyWith(status: NavigationStatus.completed));
        }
      }
    } catch (e) {
      debugPrint('Error actualizando progreso de navegación: $e');
    }
  }

  Future<void> _onProgressAnnouncement(
    _NavigationProgressAnnouncement event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession != null && state.isNavigating) {
      await _voiceService.announceProgress(
        state.currentSession!.remainingDistanceText,
        state.currentSession!.remainingDurationText,
      );
    }
  }

  // ========================================
  // MÉTODOS PRIVADOS
  // ========================================

  Future<void> _startLocationTracking() async {
    await _locationSubscription?.cancel();

    // Iniciar GPS directo — NO depende de LocationTrackingService.iniciarTracking()
    // que requiere una sesionId y está pensado para sesiones grupales.
    late final LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MotoConnect - Navegación activa',
          notificationText: 'Navegación turn-by-turn en curso',
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: true,
          setOngoing: true,
          color: Colors.teal,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );
    }

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => add(_NavigationLocationUpdated(position)),
      onError: (error) {
        debugPrint('Error en stream de ubicación de navegación: $error');
      },
    );
  }

  /// Agrega [newPoint] al [track] GPS real si supera el umbral de distancia mínima.
  ///
  /// El filtro de 15m elimina ruido GPS en paradas (semáforos, atascos) y
  /// puntos redundantes en líneas rectas, sin perder detalle en curvas.
  ///
  /// Retorna una nueva lista (no muta el estado existente).
  List<LatLng> _appendToTrack(List<LatLng> track, LatLng newPoint) {
    if (track.isEmpty) return [newPoint];

    final distance = Geolocator.distanceBetween(
      track.last.latitude,
      track.last.longitude,
      newPoint.latitude,
      newPoint.longitude,
    );

    if (distance < 15.0) return track; // Descartar: ruido o pausa

    return [...track, newPoint];
  }

  /// Calcula la polyline restante desde la posición actual hasta el destino.
  ///
  /// Encuentra el punto de la polyline más cercano a [currentLocation]
  /// y retorna todos los puntos desde ahí hasta el final.
  List<LatLng> _calculateRemainingPolyline(
    LatLng currentLocation,
    List<LatLng> completePolyline,
  ) {
    if (completePolyline.length < 2) return completePolyline;

    double minDist = double.maxFinite;
    int closestIdx = 0;

    for (int i = 0; i < completePolyline.length; i++) {
      final d = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        completePolyline[i].latitude,
        completePolyline[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // Incluir posición actual como primer punto para continuidad visual
    return [currentLocation, ...completePolyline.sublist(closestIdx)];
  }

  // ========================================
  // LIFECYCLE
  // ========================================

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _progressAnnouncementTimer?.cancel();
    _voiceService.dispose();
    return super.close();
  }
}
