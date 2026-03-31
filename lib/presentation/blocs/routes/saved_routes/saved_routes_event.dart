part of 'saved_routes_bloc.dart';

/// Eventos del SavedRoutesBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Rutas Guardadas.
sealed class SavedRoutesEvent extends Equatable {
  const SavedRoutesEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar rutas guardadas
class SavedRoutesLoadRequested extends SavedRoutesEvent {
  const SavedRoutesLoadRequested();
}

/// Refrescar rutas
class SavedRoutesRefreshRequested extends SavedRoutesEvent {
  const SavedRoutesRefreshRequested();
}

/// Eliminar una ruta
class SavedRouteDeleteRequested extends SavedRoutesEvent {
  const SavedRouteDeleteRequested({
    required this.routeId,
    required this.routeName,
  });

  final String routeId;
  final String routeName;

  @override
  List<Object?> get props => [routeId, routeName];
}

/// Compartir ruta en la comunidad
class SavedRouteShareRequested extends SavedRoutesEvent {
  const SavedRouteShareRequested({
    required this.routeData,
    this.message,
  });

  final RutaRealizadaModel routeData;
  final String? message;

  @override
  List<Object?> get props => [routeData, message];
}

/// Limpiar mensaje de error
class SavedRoutesErrorCleared extends SavedRoutesEvent {
  const SavedRoutesErrorCleared();
}
