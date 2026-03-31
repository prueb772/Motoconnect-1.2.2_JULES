part of 'navigation_bloc.dart';

/// Estado del NavigationBloc
class NavigationState extends Equatable {
  const NavigationState({
    this.status = NavigationStatus.planning,
    this.currentSession,
    this.lastKnownLocation,
    this.isCalculating = false,
    this.routeSaved = false,
    this.errorMessage,
    this.remainingPolyline = const [],
    this.realizedTrack = const [],
    this.realizedDistanceMeters = 0.0,
    this.currentHeading = 0.0,
    this.currentSpeedKmh = 0.0,
    this.distanceToNextStepMeters,
    this.distanceToDestinationMeters,
  });

  final NavigationStatus status;
  final NavigationSession? currentSession;
  final LatLng? lastKnownLocation;
  final bool isCalculating;
  final bool routeSaved;
  final String? errorMessage;

  /// Polyline restante desde la posición actual hasta el destino
  final List<LatLng> remainingPolyline;

  /// Track GPS real acumulado durante la navegación activa.
  ///
  /// Contiene posiciones snapped-to-road con filtro de distancia mínima (15m).
  /// Se usa al guardar la ruta al finalizar la navegación.
  /// Se resetea al iniciar una nueva navegación.
  final List<LatLng> realizedTrack;

  /// Distancia total real recorrida en metros (suma de segmentos del realizedTrack).
  ///
  /// A diferencia de session.totalDistanceMeters (que se reemplaza en cada
  /// recálculo con la distancia del nuevo tramo planificado), este acumulador
  /// nunca se resetea por desvíos/recálculos — solo al iniciar nueva navegación.
  /// Es la fuente correcta para mostrar al usuario al finalizar la ruta.
  final double realizedDistanceMeters;

  /// Rumbo actual del usuario (grados, 0 = norte)
  final double currentHeading;

  /// Velocidad actual en km/h (para zoom dinámico de cámara)
  final double currentSpeedKmh;

  /// Distancia en metros al final del paso actual (próximo giro)
  final double? distanceToNextStepMeters;

  /// Distancia en metros al destino final.
  /// Solo tiene valor cuando el usuario está en el último paso de la ruta.
  /// Se usa para mostrar el botón "Ya llegué" y controlar el auto-arribo.
  final double? distanceToDestinationMeters;

  // ========================================
  // GETTERS DE CONVENIENCIA
  // ========================================

  NavigationStep? get currentStep => currentSession?.currentStep;
  NavigationStep? get nextStep => currentSession?.nextStep;
  bool get isNavigating => status == NavigationStatus.navigating;
  bool get isPaused => status == NavigationStatus.paused;
  bool get isOffRoute => status == NavigationStatus.offRoute;
  bool get isCompleted => status == NavigationStatus.completed;
  bool get isCancelled => status == NavigationStatus.cancelled;
  bool get hasActiveSession => currentSession != null;

  String? get etaFormatted {
    if (currentSession == null) return null;
    final eta = currentSession!.estimatedArrivalTime;
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  NavigationState copyWith({
    NavigationStatus? status,
    NavigationSession? currentSession,
    LatLng? lastKnownLocation,
    bool? isCalculating,
    bool? routeSaved,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
    List<LatLng>? remainingPolyline,
    List<LatLng>? realizedTrack,
    double? realizedDistanceMeters,
    double? currentHeading,
    double? currentSpeedKmh,
    double? distanceToNextStepMeters,
    bool clearDistanceToNext = false,
    double? distanceToDestinationMeters,
    bool clearDistanceToDestination = false,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentSession:
          clearSession ? null : (currentSession ?? this.currentSession),
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      isCalculating: isCalculating ?? this.isCalculating,
      routeSaved: routeSaved ?? this.routeSaved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      remainingPolyline: remainingPolyline ?? this.remainingPolyline,
      realizedTrack: realizedTrack ?? this.realizedTrack,
      realizedDistanceMeters:
          realizedDistanceMeters ?? this.realizedDistanceMeters,
      currentHeading: currentHeading ?? this.currentHeading,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      distanceToNextStepMeters: clearDistanceToNext
          ? null
          : (distanceToNextStepMeters ?? this.distanceToNextStepMeters),
      distanceToDestinationMeters: clearDistanceToDestination
          ? null
          : (distanceToDestinationMeters ?? this.distanceToDestinationMeters),
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentSession,
        lastKnownLocation,
        isCalculating,
        routeSaved,
        errorMessage,
        currentHeading,
        currentSpeedKmh,
        distanceToNextStepMeters,
        // NOTE: remainingPolyline excluido de props intencionalmente.
        // lastKnownLocation ya dispara rebuilds. Evitamos comparación O(n) de listas en cada update.
      ];
}
