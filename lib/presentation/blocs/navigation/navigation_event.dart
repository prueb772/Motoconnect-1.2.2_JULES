part of 'navigation_bloc.dart';

/// Eventos del NavigationBloc
///
/// Define las acciones que pueden ocurrir durante la navegación.
sealed class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

/// Iniciar navegación
class NavigationStartRequested extends NavigationEvent {
  const NavigationStartRequested({
    required this.destination,
    this.destinationName,
    this.sesionGrupalId,
    this.mode = 'driving',
  });

  final LatLng destination;
  final String? destinationName;
  final String? sesionGrupalId;
  final String mode;

  @override
  List<Object?> get props => [destination, destinationName, sesionGrupalId, mode];
}

/// Finalizar navegación
class NavigationEndRequested extends NavigationEvent {
  const NavigationEndRequested({this.completed = false});

  final bool completed;

  @override
  List<Object?> get props => [completed];
}

/// Recalcular ruta
class NavigationRecalculateRequested extends NavigationEvent {
  const NavigationRecalculateRequested();
}

/// Guardar ruta completada
class NavigationSaveRouteRequested extends NavigationEvent {
  const NavigationSaveRouteRequested({
    required this.routeName,
    this.routeDescription,
  });

  final String routeName;
  final String? routeDescription;

  @override
  List<Object?> get props => [routeName, routeDescription];
}

/// Limpiar error
class NavigationErrorCleared extends NavigationEvent {
  const NavigationErrorCleared();
}

/// Evento interno: Actualización de ubicación
class _NavigationLocationUpdated extends NavigationEvent {
  const _NavigationLocationUpdated(this.position);

  final Position position;

  @override
  List<Object?> get props => [position];
}

/// Evento interno: Anuncio periódico de progreso
class _NavigationProgressAnnouncement extends NavigationEvent {
  const _NavigationProgressAnnouncement();
}
