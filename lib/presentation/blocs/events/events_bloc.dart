import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/event_model.dart';
import '../../../data/repositories/event_repository.dart';

part 'events_event.dart';
part 'events_state.dart';

/// EventsBloc - Gestiona el estado de la pantalla de Eventos
///
/// Este BLoC reemplaza a EventsViewModel.
/// Es responsable de:
/// - Cargar lista de eventos
/// - Cargar detalles de un evento
/// - Registrar/cancelar registro en eventos
/// - Gestionar estados de carga y errores
class EventsBloc extends Bloc<EventsEvent, EventsState> {
  EventsBloc({
    required EventRepository eventRepository,
  })  : _eventRepository = eventRepository,
        super(const EventsState()) {
    on<EventsLoadRequested>(_onLoadRequested);
    on<EventsRefreshRequested>(_onRefreshRequested);
  }

  final EventRepository _eventRepository;

  /// Carga la lista de eventos próximos
  Future<void> _onLoadRequested(
    EventsLoadRequested event,
    Emitter<EventsState> emit,
  ) async {
    emit(state.copyWith(status: EventsStatus.loading));

    try {
      final events = await _eventRepository.getUpcomingEvents();
      emit(state.copyWith(
        status: EventsStatus.success,
        events: events,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EventsStatus.error,
        errorMessage: 'No se pudieron cargar los eventos: ${e.toString()}',
      ));
    }
  }

  /// Refresca la lista de eventos
  Future<void> _onRefreshRequested(
    EventsRefreshRequested event,
    Emitter<EventsState> emit,
  ) async {
    await _onLoadRequested(const EventsLoadRequested(), emit);
  }

}
