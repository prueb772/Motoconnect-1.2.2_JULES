import 'package:equatable/equatable.dart';
import '../../../../../data/models/ruta_sesion_model.dart';
import '../../../../../data/models/navigation_step.dart';
import '../../../../../data/models/navigation_progress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationCameraUpdate extends Equatable {
  final LatLng location;
  final double heading;
  final double speedKmh;

  const NavigationCameraUpdate({
    required this.location,
    required this.heading,
    required this.speedKmh,
  });

  @override
  List<Object?> get props => [location, heading, speedKmh];
}

class MapaNavigationState extends Equatable {
  final RutaSesionModel? rutaCompartida;
  final Map<String, NavigationProgress> groupProgress;
  
  final List<LatLng> remainingPolyline;
  final List<LatLng> completePolylinePoints;
  final List<NavigationStep>? navigationSteps;
  final int? currentStepIndex;
  
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final double? distanceToNextStepMeters;
  final double? distanceToDestinationMeters;
  
  final bool isRecalculating;
  final LatLng? destinoAjustado;
  final bool llegoAlDestino;
  final String? error;
  
  final NavigationCameraUpdate? cameraUpdate;

  const MapaNavigationState({
    this.rutaCompartida,
    this.groupProgress = const {},
    this.remainingPolyline = const [],
    this.completePolylinePoints = const [],
    this.navigationSteps,
    this.currentStepIndex,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
    this.distanceToNextStepMeters,
    this.distanceToDestinationMeters,
    this.isRecalculating = false,
    this.destinoAjustado,
    this.llegoAlDestino = false,
    this.error,
    this.cameraUpdate,
  });

  MapaNavigationState copyWith({
    RutaSesionModel? rutaCompartida,
    Map<String, NavigationProgress>? groupProgress,
    List<LatLng>? remainingPolyline,
    List<LatLng>? completePolylinePoints,
    List<NavigationStep>? navigationSteps,
    int? currentStepIndex,
    double? remainingDistanceMeters,
    int? remainingDurationSeconds,
    double? distanceToNextStepMeters,
    double? distanceToDestinationMeters,
    bool? isRecalculating,
    LatLng? destinoAjustado,
    bool? llegoAlDestino,
    String? error,
    NavigationCameraUpdate? cameraUpdate,
    bool clearCameraUpdate = false,
  }) {
    return MapaNavigationState(
      rutaCompartida: rutaCompartida ?? this.rutaCompartida,
      groupProgress: groupProgress ?? this.groupProgress,
      remainingPolyline: remainingPolyline ?? this.remainingPolyline,
      completePolylinePoints: completePolylinePoints ?? this.completePolylinePoints,
      navigationSteps: navigationSteps ?? this.navigationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      remainingDistanceMeters: remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds: remainingDurationSeconds ?? this.remainingDurationSeconds,
      distanceToNextStepMeters: distanceToNextStepMeters ?? this.distanceToNextStepMeters,
      distanceToDestinationMeters: distanceToDestinationMeters ?? this.distanceToDestinationMeters,
      isRecalculating: isRecalculating ?? this.isRecalculating,
      destinoAjustado: destinoAjustado ?? this.destinoAjustado,
      llegoAlDestino: llegoAlDestino ?? this.llegoAlDestino,
      error: error,
      cameraUpdate: clearCameraUpdate ? null : (cameraUpdate ?? this.cameraUpdate),
    );
  }

  // Helper to allow nullifying values
  MapaNavigationState copyWithNullRuta() {
    return const MapaNavigationState(
      rutaCompartida: null,
      groupProgress: {},
      remainingPolyline: [],
      completePolylinePoints: [],
      navigationSteps: null,
      currentStepIndex: null,
      remainingDistanceMeters: 0,
      remainingDurationSeconds: 0,
      distanceToNextStepMeters: null,
      distanceToDestinationMeters: null,
      isRecalculating: false,
      destinoAjustado: null,
      llegoAlDestino: false,
      error: null,
      cameraUpdate: null,
    );
  }
  
  MapaNavigationState copyWithNullDestinoAjustado() {
    return MapaNavigationState(
      rutaCompartida: rutaCompartida,
      groupProgress: groupProgress,
      remainingPolyline: remainingPolyline,
      completePolylinePoints: completePolylinePoints,
      navigationSteps: navigationSteps,
      currentStepIndex: currentStepIndex,
      remainingDistanceMeters: remainingDistanceMeters,
      remainingDurationSeconds: remainingDurationSeconds,
      distanceToNextStepMeters: distanceToNextStepMeters,
      distanceToDestinationMeters: distanceToDestinationMeters,
      isRecalculating: isRecalculating,
      destinoAjustado: null,
      llegoAlDestino: llegoAlDestino,
      error: error,
      cameraUpdate: cameraUpdate,
    );
  }

  @override
  List<Object?> get props => [
        rutaCompartida,
        groupProgress,
        remainingPolyline,
        completePolylinePoints,
        navigationSteps,
        currentStepIndex,
        remainingDistanceMeters,
        remainingDurationSeconds,
        distanceToNextStepMeters,
        distanceToDestinationMeters,
        isRecalculating,
        destinoAjustado,
        llegoAlDestino,
        error,
        cameraUpdate,
      ];
}
