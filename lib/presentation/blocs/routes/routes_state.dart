part of 'routes_bloc.dart';

/// Estados posibles de la pantalla de rutas
enum RoutesStatus {
  /// Estado inicial
  initial,

  /// Cargando ubicación del usuario
  loadingLocation,

  /// Ubicación cargada
  locationLoaded,

  /// Buscando lugares
  searchingPlaces,

  /// Calculando ruta
  calculatingRoute,

  /// Ruta calculada
  routeCalculated,

  /// Guardando ruta
  savingRoute,

  /// Ruta guardada
  routeSaved,

  /// Cargando ruta guardada
  loadingRoute,

  /// Ruta cargada
  routeLoaded,

  /// Error
  error,
}

/// Estado del RoutesBloc
class RoutesState extends Equatable {
  const RoutesState({
    this.status = RoutesStatus.initial,
    this.currentPosition,
    this.userMarker,
    this.searchedMarker,
    this.polylineCoordinates = const [],
    this.polylines = const {},
    this.predictions = const [],
    this.siguiendoRuta = false,
    this.selectedPlaceName,
    this.errorMessage,
  });

  /// Estado actual
  final RoutesStatus status;

  /// Posición actual del usuario
  final Position? currentPosition;

  /// Marcador del usuario
  final Marker? userMarker;

  /// Marcador del lugar buscado
  final Marker? searchedMarker;

  /// Coordenadas de la polyline (ruta)
  final List<LatLng> polylineCoordinates;

  /// Set de polylines
  final Set<Polyline> polylines;

  /// Predicciones de búsqueda de Google Place
  final List<AutocompletePrediction> predictions;

  /// Indica si se está siguiendo la ruta
  final bool siguiendoRuta;

  /// Nombre del lugar seleccionado
  final String? selectedPlaceName;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Set de marcadores (combinación de user y searched)
  Set<Marker> get markers {
    final Set<Marker> allMarkers = {};
    if (userMarker != null) allMarkers.add(userMarker!);
    if (searchedMarker != null) allMarkers.add(searchedMarker!);
    return allMarkers;
  }

  /// Indica si hay una ruta activa
  bool get tieneRutaActiva =>
      polylines.isNotEmpty && polylineCoordinates.isNotEmpty;

  /// Crea una copia del estado con los campos modificados
  RoutesState copyWith({
    RoutesStatus? status,
    Position? currentPosition,
    Marker? userMarker,
    Marker? searchedMarker,
    List<LatLng>? polylineCoordinates,
    Set<Polyline>? polylines,
    List<AutocompletePrediction>? predictions,
    bool? siguiendoRuta,
    String? selectedPlaceName,
    String? errorMessage,
    bool clearError = false,
    bool clearSearchedMarker = false,
    bool clearPredictions = false,
    bool clearSelectedPlaceName = false,
  }) {
    return RoutesState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      userMarker: userMarker ?? this.userMarker,
      searchedMarker:
          clearSearchedMarker ? null : (searchedMarker ?? this.searchedMarker),
      polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
      polylines: polylines ?? this.polylines,
      predictions: clearPredictions ? [] : (predictions ?? this.predictions),
      siguiendoRuta: siguiendoRuta ?? this.siguiendoRuta,
      selectedPlaceName: clearSelectedPlaceName
          ? null
          : (selectedPlaceName ?? this.selectedPlaceName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentPosition,
        userMarker,
        searchedMarker,
        polylineCoordinates,
        polylines,
        predictions,
        siguiendoRuta,
        selectedPlaceName,
        errorMessage,
      ];
}
