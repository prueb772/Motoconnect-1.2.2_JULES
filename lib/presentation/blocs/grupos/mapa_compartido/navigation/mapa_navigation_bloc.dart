import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../data/models/ruta_sesion_model.dart';
import '../../../../../data/models/navigation_step.dart';
import '../../../../../data/models/navigation_progress.dart';
import '../../../../../data/repositories/grupo_repository.dart';
import '../../../../../data/repositories/navigation_repository.dart';
import '../../../../../services/location_tracking_service.dart';
import '../../../../../services/google_directions_service.dart';
import '../../../../../services/navigation_voice_service.dart';
import '../../../../../services/navigation_tracking_service.dart';

import 'mapa_navigation_event.dart';
import 'mapa_navigation_state.dart';

class MapaNavigationBloc extends Bloc<MapaNavigationEvent, MapaNavigationState> {
  final GrupoRepository _grupoRepository;
  final NavigationRepository _navigationRepository;
  final LocationTrackingService _locationService;
  final GoogleDirectionsService _directionsService;
  final NavigationVoiceService _voiceService;
  final NavigationTrackingService _navTrackingService;

  StreamSubscription? _rutaCompartidaSubscription;
  StreamSubscription? _groupProgressSubscription;
  StreamSubscription? _locationSubscription;

  late String _sesionId;
  DateTime? _offRouteSince;
  final int _offRouteTriggerSeconds = 5;
  bool _voiceProximity200Fired = false;
  bool _voiceProximity50Fired = false;

  MapaNavigationBloc({
    required GrupoRepository grupoRepository,
    required NavigationRepository navigationRepository,
    required LocationTrackingService locationService,
    required GoogleDirectionsService directionsService,
    required NavigationVoiceService voiceService,
    required NavigationTrackingService navTrackingService,
  })  : _grupoRepository = grupoRepository,
        _navigationRepository = navigationRepository,
        _locationService = locationService,
        _directionsService = directionsService,
        _voiceService = voiceService,
        _navTrackingService = navTrackingService,
        super(const MapaNavigationState()) {
    on<MapaNavigationIniciar>(_onIniciar);
    on<MapaNavigationRutaActualizada>(_onRutaActualizada);
    on<MapaNavigationProgresoGrupalActualizado>(_onProgresoGrupalActualizado);
    on<MapaNavigationCompartirRuta>(_onCompartirRuta);
    on<MapaNavigationCancelarRuta>(_onCancelarRuta);
    on<MapaNavigationAjustarDestino>(_onAjustarDestino);
    on<MapaNavigationLlegadaManual>(_onLlegadaManual);
    on<MapaNavigationFinalizarViaje>(_onFinalizarViaje);
    on<MapaNavigationDismissError>((event, emit) => emit(state.copyWith(error: null)));
    on<MapaNavigationDismissLlegada>((event, emit) => emit(state.copyWith(llegoAlDestino: false)));
    
    // Internal event handler for location updates
    on<_MapaNavigationLocationUpdated>(_onLocationUpdated);
  }

  void _onIniciar(MapaNavigationIniciar event, Emitter<MapaNavigationState> emit) {
    _sesionId = event.sesionId;

    _rutaCompartidaSubscription?.cancel();
    _rutaCompartidaSubscription = _grupoRepository
        .streamRutaCompartida(_sesionId)
        .listen((ruta) {
      add(MapaNavigationRutaActualizada(ruta));
    });

    _groupProgressSubscription?.cancel();
    _groupProgressSubscription = _navigationRepository
        .streamGroupNavigationProgress(_sesionId)
        .listen((progressList) {
      final progressMap = <String, NavigationProgress>{};
      for (final p in progressList) {
        progressMap[p.userId] = p;
      }
      add(MapaNavigationProgresoGrupalActualizado(progressMap));
    });
  }

  Future<void> _onRutaActualizada(
    MapaNavigationRutaActualizada event,
    Emitter<MapaNavigationState> emit,
  ) async {
    final rutaAnterior = state.rutaCompartida;
    final rutaNueva = event.ruta;

    if (rutaNueva == null) {
      _detenerNavegacionInterna();
      emit(state.copyWithNullRuta());
      return;
    }

    emit(state.copyWith(
      rutaCompartida: rutaNueva,
      destinoAjustado: null,
    ));

    // Si es una ruta nueva o cambió el destino
    if (rutaAnterior?.id != rutaNueva.id ||
        rutaAnterior?.destinoLat != rutaNueva.destinoLat ||
        rutaAnterior?.destinoLng != rutaNueva.destinoLng) {
      await _calcularPolylineHaciaDestino(
        emit: emit,
        destinoLat: rutaNueva.destinoLat,
        destinoLng: rutaNueva.destinoLng,
      );
    }
  }

  void _onProgresoGrupalActualizado(
    MapaNavigationProgresoGrupalActualizado event,
    Emitter<MapaNavigationState> emit,
  ) {
    emit(state.copyWith(groupProgress: event.progress));
  }

  Future<void> _onCompartirRuta(
    MapaNavigationCompartirRuta event,
    Emitter<MapaNavigationState> emit,
  ) async {
    try {
      await _grupoRepository.compartirRuta(
        sesionId: _sesionId,
        destinoLat: event.destinoLat,
        destinoLng: event.destinoLng,
        destinoNombre: event.destinoNombre,
      );
    } catch (e) {
      emit(state.copyWith(error: 'Error al compartir la ruta: $e'));
    }
  }

  Future<void> _onCancelarRuta(
    MapaNavigationCancelarRuta event,
    Emitter<MapaNavigationState> emit,
  ) async {
    try {
      _detenerNavegacionInterna();
      emit(state.copyWithNullRuta());
      await _grupoRepository.eliminarRutaCompartida(_sesionId);
    } catch (e) {
      emit(state.copyWith(error: 'Error al cancelar la ruta: $e'));
    }
  }

  Future<void> _onAjustarDestino(
    MapaNavigationAjustarDestino event,
    Emitter<MapaNavigationState> emit,
  ) async {
    emit(state.copyWith(destinoAjustado: event.destinoAjustado));
    await _calcularPolylineHaciaDestino(
      emit: emit,
      destinoLat: event.destinoAjustado.latitude,
      destinoLng: event.destinoAjustado.longitude,
    );
  }

  // ============== BUSINESS LOGIC PRIVADA ==============

  void _detenerNavegacionInterna() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _offRouteSince = null;
    _voiceService.stop();
  }

  Future<void> _calcularPolylineHaciaDestino({
    required Emitter<MapaNavigationState> emit,
    required double destinoLat,
    required double destinoLng,
    int maxRetries = 3,
  }) async {
    int intento = 0;
    while (intento < maxRetries) {
      try {
        intento++;
        final position = await _locationService.obtenerUbicacionActual();
        final origen = LatLng(position.latitude, position.longitude);
        final destino = LatLng(destinoLat, destinoLng);

        final directions = await _directionsService.getDirections(
          origin: origen,
          destination: destino,
        );

        if (directions.routes.isNotEmpty) {
          final route = directions.routes.first;
          final polylinePoints = _directionsService.decodePolyline(route.polylineEncoded);

          final steps = <NavigationStep>[];
          if (route.legs.isNotEmpty) {
            final leg = route.legs.first;
            for (final directionStep in leg.steps) {
              final stepPolylinePoints = _directionsService.decodePolyline(directionStep.polylineEncoded);
              steps.add(directionStep.toNavigationStep(stepPolylinePoints));
            }
          }

          final completeFromSteps = <LatLng>[];
          for (final s in steps) {
            if (completeFromSteps.isNotEmpty && s.polylinePoints.isNotEmpty) {
              completeFromSteps.addAll(s.polylinePoints.skip(1));
            } else {
              completeFromSteps.addAll(s.polylinePoints);
            }
          }
          final completePoints = completeFromSteps.isNotEmpty ? completeFromSteps : polylinePoints;

          double totalDist = 0;
          int totalDur = 0;
          for (final s in steps) {
            totalDist += s.distanceMeters;
            totalDur += s.durationSeconds;
          }

          emit(state.copyWith(
            completePolylinePoints: completePoints,
            remainingPolyline: completePoints,
            navigationSteps: steps,
            currentStepIndex: steps.isNotEmpty ? 0 : null,
            remainingDistanceMeters: totalDist,
            remainingDurationSeconds: totalDur,
            distanceToNextStepMeters: null,
            error: null,
            isRecalculating: false,
          ));

          if (steps.isNotEmpty) {
            _iniciarNavegacionPorVoz(steps.first);
          }
          return; // Exito
        } else {
          emit(state.copyWith(
            isRecalculating: false,
            error: 'No se encontraron rutas para el destino.',
          ));
          return;
        }
      } catch (e) {
        if (intento >= maxRetries) {
          emit(state.copyWith(
            isRecalculating: false,
            error: 'Error al calcular ruta: $e',
          ));
          return;
        }
        await Future.delayed(Duration(seconds: 2 * (1 << (intento - 1))));
      }
    }
  }

  Future<void> _iniciarNavegacionPorVoz(NavigationStep firstStep) async {
    _locationSubscription?.cancel();
    await _voiceService.initialize();
    
    _voiceProximity200Fired = false;
    _voiceProximity50Fired = false;
    _offRouteSince = null;
    
    await _voiceService.announceInstruction(
      firstStep.instruction,
      firstStep.distanceText,
    );

    _locationSubscription = _locationService.ubicacionStream.listen((position) {
      add(_MapaNavigationLocationUpdated(position));
    });
  }

  void _onLocationUpdated(
    _MapaNavigationLocationUpdated event,
    Emitter<MapaNavigationState> emit,
  ) {
    if (state.navigationSteps == null || state.navigationSteps!.isEmpty || state.currentStepIndex == null) {
      return;
    }

    final rawLocation = LatLng(event.position.latitude, event.position.longitude);
    final speedKmh = (event.position.speed < 0 ? 0 : event.position.speed) * 3.6;
    final heading = event.position.heading < 0 ? 0.0 : event.position.heading;

    final LatLng navLocation = state.completePolylinePoints.length >= 2
        ? _navTrackingService.snapToPolyline(rawLocation, state.completePolylinePoints)
        : rawLocation;

    emit(state.copyWith(
      cameraUpdate: NavigationCameraUpdate(
        location: navLocation,
        heading: heading,
        speedKmh: speedKmh,
      ),
    ));

    final newStepIndex = _navTrackingService.determineCurrentStep(
      currentLocation: navLocation,
      steps: state.navigationSteps!,
      lastStepIndex: state.currentStepIndex!,
    );

    if (newStepIndex > state.currentStepIndex!) {
      if (newStepIndex >= state.navigationSteps!.length) {
        _llegadaExitosa(emit);
        return;
      }
      
      final newStep = state.navigationSteps![newStepIndex];
      _voiceProximity200Fired = false;
      _voiceProximity50Fired = false;
      _voiceService.announceInstruction(newStep.instruction, newStep.distanceText);
      emit(state.copyWith(currentStepIndex: newStepIndex));
    }

    final currentIndex = state.currentStepIndex ?? newStepIndex;
    if (currentIndex >= state.navigationSteps!.length) return;
    
    final currentStep = state.navigationSteps![currentIndex];
    final distanceToStepEnd = _navTrackingService.calculateDistanceToStepEnd(
      currentLocation: navLocation,
      currentStep: currentStep,
    );
    final remainingDist = _navTrackingService.calculateRemainingDistance(
      currentLocation: navLocation,
      steps: state.navigationSteps!,
      currentStepIndex: currentIndex,
    );
    final remainingDur = _navTrackingService.calculateRemainingDuration(
      steps: state.navigationSteps!,
      currentStepIndex: currentIndex,
    );

    int closestIdx = 0;
    double minDist = double.maxFinite;
    for (int i = 0; i < state.completePolylinePoints.length; i++) {
        final d = Geolocator.distanceBetween(
          navLocation.latitude, navLocation.longitude,
          state.completePolylinePoints[i].latitude, state.completePolylinePoints[i].longitude,
        );
        if (d < minDist) {
          minDist = d;
          closestIdx = i;
        }
    }
    final remainingPolyline = [navLocation, ...state.completePolylinePoints.sublist(closestIdx)];

    // Off-route logic
    bool recalc = state.isRecalculating;
    if (!recalc) {
      final offRoute = _navTrackingService.isOffRoute(
        currentLocation: rawLocation,
        currentStep: currentStep,
      );
      if (offRoute) {
        _offRouteSince ??= DateTime.now();
        if (DateTime.now().difference(_offRouteSince!).inSeconds >= _offRouteTriggerSeconds) {
          _offRouteSince = null;
          recalc = true;
          _voiceProximity200Fired = false;
          _voiceProximity50Fired = false;
          _voiceService.announceRecalculating();
          
          final dest = state.destinoAjustado ?? LatLng(state.rutaCompartida!.destinoLat, state.rutaCompartida!.destinoLng);
          _calcularPolylineHaciaDestino(
            emit: emit, 
            destinoLat: dest.latitude, 
            destinoLng: dest.longitude
          );
          emit(state.copyWith(isRecalculating: true));
          return;
        }
      } else {
        _offRouteSince = null;
      }
    }

    // Auto arrival logic
    final isLastStep = currentIndex == state.navigationSteps!.length - 1;
    double? distToDest;
    if (isLastStep && state.rutaCompartida != null) {
      final destLat = state.destinoAjustado?.latitude ?? state.rutaCompartida!.destinoLat;
      final destLng = state.destinoAjustado?.longitude ?? state.rutaCompartida!.destinoLng;
      distToDest = Geolocator.distanceBetween(navLocation.latitude, navLocation.longitude, destLat, destLng);
      final autoArrived = distToDest < 50.0 || (distToDest < 80.0 && speedKmh < 20.0);
      if (autoArrived) {
         _llegadaExitosa(emit);
         return;
      }
    }

    emit(state.copyWith(
      distanceToNextStepMeters: distanceToStepEnd,
      remainingDistanceMeters: remainingDist,
      remainingDurationSeconds: remainingDur,
      remainingPolyline: remainingPolyline.isNotEmpty ? remainingPolyline : state.remainingPolyline,
      distanceToDestinationMeters: distToDest,
    ));

    // Voice proximity alerts
    if (!_voiceProximity200Fired && distanceToStepEnd <= 200) {
      _voiceProximity200Fired = true;
      _voiceService.announceProximityAlert(currentStep.instruction, 200);
    }
    if (!_voiceProximity50Fired && distanceToStepEnd <= 50) {
      _voiceProximity50Fired = true;
      _voiceService.announceProximityAlert(currentStep.instruction, 50);
    }
  }

  Future<void> _onLlegadaManual(
    MapaNavigationLlegadaManual event,
    Emitter<MapaNavigationState> emit,
  ) async {
    _llegadaExitosa(emit);
  }

  Future<void> _onFinalizarViaje(
    MapaNavigationFinalizarViaje event,
    Emitter<MapaNavigationState> emit,
  ) async {
    _detenerNavegacionInterna();
    emit(state.copyWithNullRuta());
  }

  void _llegadaExitosa(Emitter<MapaNavigationState> emit) {
    _voiceService.announceArrival();
    _detenerNavegacionInterna();
    emit(state.copyWith(llegoAlDestino: true));
  }

  @override
  Future<void> close() {
    _rutaCompartidaSubscription?.cancel();
    _groupProgressSubscription?.cancel();
    _detenerNavegacionInterna();
    return super.close();
  }
}

class _MapaNavigationLocationUpdated extends MapaNavigationEvent {
  final Position position;
  const _MapaNavigationLocationUpdated(this.position);
  @override
  List<Object> get props => [position];
}
