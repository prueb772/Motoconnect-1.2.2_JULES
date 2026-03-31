part of 'events_bloc.dart';

/// Eventos del EventsBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Eventos.
sealed class EventsEvent extends Equatable {
  const EventsEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar lista de eventos
class EventsLoadRequested extends EventsEvent {
  const EventsLoadRequested();
}

/// Refrescar lista de eventos
class EventsRefreshRequested extends EventsEvent {
  const EventsRefreshRequested();
}

