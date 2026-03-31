part of 'routes_bloc.dart';

/// Eventos del RoutesBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Rutas.
sealed class RoutesEvent extends Equatable {
  const RoutesEvent();

  @override
  List<Object?> get props => [];
}


/// Inicializar el BLoC
class RoutesInitialized extends RoutesEvent {
  const RoutesInitialized();
}

/// Mapa creado
class RoutesMapCreated extends RoutesEvent {
  const RoutesMapCreated(this.controller);

  final GoogleMapController controller;

  @override
  List<Object?> get props => [controller];
}

/// Solicitar ubicación del usuario
class RoutesUserLocationRequested extends RoutesEvent {
  const RoutesUserLocationRequested();
}

/// Cambio en la búsqueda de lugares
class RoutesSearchQueryChanged extends RoutesEvent {
  const RoutesSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Predicción de búsqueda seleccionada
class RoutesPredictionSelected extends RoutesEvent {
  const RoutesPredictionSelected(this.prediction);

  final AutocompletePrediction prediction;

  @override
  List<Object?> get props => [prediction];
}

/// Establecer destino directamente (sin búsqueda)
class RoutesDestinationSet extends RoutesEvent {
  const RoutesDestinationSet({
    required this.destination,
    this.destinationName,
  });

  final LatLng destination;
  final String? destinationName;

  @override
  List<Object?> get props => [destination, destinationName];
}

/// Calcular ruta a un destino
class RoutesCalculateRequested extends RoutesEvent {
  const RoutesCalculateRequested(this.destination);

  final LatLng destination;

  @override
  List<Object?> get props => [destination];
}

/// Limpiar búsqueda y ruta
class RoutesSearchCleared extends RoutesEvent {
  const RoutesSearchCleared();
}

/// Iniciar seguimiento de ruta
class RoutesTrackingStarted extends RoutesEvent {
  const RoutesTrackingStarted();
}

/// Detener seguimiento de ruta
class RoutesTrackingStopped extends RoutesEvent {
  const RoutesTrackingStopped();
}

/// Guardar ruta actual
class RoutesSaveRequested extends RoutesEvent {
  const RoutesSaveRequested({
    required this.routeName,
    this.routeDescription,
  });

  final String routeName;
  final String? routeDescription;

  @override
  List<Object?> get props => [routeName, routeDescription];
}

/// Cargar y mostrar ruta guardada
class RoutesSavedRouteLoadRequested extends RoutesEvent {
  const RoutesSavedRouteLoadRequested(this.routeData);

  final RutaRealizadaModel routeData;

  @override
  List<Object?> get props => [routeData];
}


/// Cargar ruta por ID
class RoutesLoadByIdRequested extends RoutesEvent {
  const RoutesLoadByIdRequested(this.routeId);

  final String routeId;

  @override
  List<Object?> get props => [routeId];
}

/// Limpiar error
class RoutesErrorCleared extends RoutesEvent {
  const RoutesErrorCleared();
}

/// Marcador de destino arrastrado a nueva posición
class RoutesMarkerDragged extends RoutesEvent {
  const RoutesMarkerDragged(this.newPosition);

  final LatLng newPosition;

  @override
  List<Object?> get props => [newPosition];
}

/// Evento interno: Actualización de ubicación durante seguimiento
class _RoutesLocationUpdated extends RoutesEvent {
  const _RoutesLocationUpdated(this.position);

  final Position position;

  @override
  List<Object?> get props => [position];
}
