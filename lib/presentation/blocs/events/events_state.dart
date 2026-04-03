part of 'events_bloc.dart';

/// Estados posibles de la pantalla de Eventos
enum EventsStatus {
  /// Estado inicial
  initial,

  /// Cargando lista de eventos
  loading,

  /// Eventos cargados correctamente
  success,

  /// Error al cargar eventos
  error,
}

/// Estado del EventsBloc
///
/// Representa el estado de la pantalla de Eventos.
class EventsState extends Equatable {
  const EventsState({
    this.status = EventsStatus.initial,
    this.events = const [],
    this.errorMessage,
  });

  /// Estado actual
  final EventsStatus status;

  /// Lista de eventos
  final List<Event> events;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Crea una copia del estado con los campos modificados
  EventsState copyWith({
    EventsStatus? status,
    List<Event>? events,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EventsState(
      status: status ?? this.status,
      events: events ?? this.events,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, events, errorMessage];
}
