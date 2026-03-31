part of 'event_detail_bloc.dart';

/// Eventos del EventDetailBloc
sealed class EventDetailEvent extends Equatable {
  const EventDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar detalles del evento
class EventDetailLoadRequested extends EventDetailEvent {
  const EventDetailLoadRequested();
}

/// Cargar participantes del evento
class EventDetailParticipantsLoadRequested extends EventDetailEvent {
  const EventDetailParticipantsLoadRequested();
}

/// Actualizar estado de asistencia
class EventDetailAttendanceUpdateRequested extends EventDetailEvent {
  const EventDetailAttendanceUpdateRequested(this.newStatus);

  final EstadoAsistencia newStatus;

  @override
  List<Object?> get props => [newStatus];
}

/// Eliminar evento
class EventDetailDeleteRequested extends EventDetailEvent {
  const EventDetailDeleteRequested();
}

/// Refrescar todo
class EventDetailRefreshRequested extends EventDetailEvent {
  const EventDetailRefreshRequested();
}

/// Limpiar error
class EventDetailErrorCleared extends EventDetailEvent {
  const EventDetailErrorCleared();
}
