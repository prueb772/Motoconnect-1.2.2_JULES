import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/models/event_participant_model.dart';

part 'event_detail_event.dart';
part 'event_detail_state.dart';

/// EventDetailBloc - Gestiona el estado de la pantalla de detalle de evento
///
/// Es responsable de:
/// - Cargar detalles del evento
/// - Cargar participantes
/// - Gestionar estado de asistencia del usuario
/// - Eliminar evento
class EventDetailBloc extends Bloc<EventDetailEvent, EventDetailState> {
  EventDetailBloc({
    required EventRepository eventRepository,
    required String eventId,
  })  : _eventRepository = eventRepository,
        _eventId = eventId,
        super(const EventDetailState()) {
    on<EventDetailLoadRequested>(_onLoadRequested);
    on<EventDetailParticipantsLoadRequested>(_onParticipantsLoadRequested);
    on<EventDetailAttendanceUpdateRequested>(_onAttendanceUpdateRequested);
    on<EventDetailDeleteRequested>(_onDeleteRequested);
    on<EventDetailRefreshRequested>(_onRefreshRequested);
    on<EventDetailErrorCleared>(_onErrorCleared);
  }

  final EventRepository _eventRepository;
  final String _eventId;

  /// Carga los detalles del evento
  Future<void> _onLoadRequested(
    EventDetailLoadRequested event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(status: EventDetailStatus.loading));

    try {
      final eventData = await _eventRepository.getEventById(_eventId);
      final currentUserId = _eventRepository.getCurrentUserId();

      emit(state.copyWith(
        status: EventDetailStatus.loaded,
        event: eventData,
        currentUserId: currentUserId,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EventDetailStatus.error,
        errorMessage: 'Error al cargar evento: ${e.toString()}',
      ));
      debugPrint('Error en EventDetailBloc._onLoadRequested: $e');
    }
  }

  /// Carga los participantes del evento
  Future<void> _onParticipantsLoadRequested(
    EventDetailParticipantsLoadRequested event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(isLoadingParticipants: true));

    try {
      final participants =
          await _eventRepository.getEventParticipantsDetailed(_eventId);

      final userId = _eventRepository.getCurrentUserId();
      EstadoAsistencia? userStatus;

      if (userId != null) {
        final userParticipant = participants.where(
          (p) => p.usuarioId == userId,
        ).firstOrNull;
        userStatus = userParticipant?.estado;
      }

      emit(state.copyWith(
        participants: participants,
        userAttendanceStatus: userStatus,
        isLoadingParticipants: false,
        clearUserStatus: userStatus == null,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingParticipants: false,
        errorMessage: 'Error al cargar participantes: ${e.toString()}',
      ));
      debugPrint('Error en EventDetailBloc._onParticipantsLoadRequested: $e');
    }
  }

  /// Actualiza el estado de asistencia del usuario
  Future<void> _onAttendanceUpdateRequested(
    EventDetailAttendanceUpdateRequested event,
    Emitter<EventDetailState> emit,
  ) async {
    final userId = _eventRepository.getCurrentUserId();
    if (userId == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión'));
      return;
    }

    try {
      if (state.userAttendanceStatus == null) {
        // Usuario no está registrado, hacer join con el estado
        await _eventRepository.joinEvent(
          _eventId,
          userId,
          estado: event.newStatus,
        );
      } else if (event.newStatus == state.userAttendanceStatus) {
        // Si hace clic en el mismo estado, lo desinscribe
        await _eventRepository.leaveEvent(_eventId, userId);
      } else {
        // Actualizar estado existente
        await _eventRepository.updateAttendanceStatus(
          _eventId,
          userId,
          event.newStatus,
        );
      }

      // Recargar participantes
      add(const EventDetailParticipantsLoadRequested());

      emit(state.copyWith(
        status: EventDetailStatus.attendanceUpdated,
        clearError: true,
      ));

      // Volver al estado loaded
      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: EventDetailStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Error al actualizar asistencia: ${e.toString()}',
      ));
      debugPrint('Error en EventDetailBloc._onAttendanceUpdateRequested: $e');
    }
  }

  /// Elimina el evento
  Future<void> _onDeleteRequested(
    EventDetailDeleteRequested event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(status: EventDetailStatus.deleting));

    try {
      await _eventRepository.deleteEvent(_eventId);

      emit(state.copyWith(
        status: EventDetailStatus.deleted,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EventDetailStatus.error,
        errorMessage: 'Error al eliminar evento: ${e.toString()}',
      ));
      debugPrint('Error en EventDetailBloc._onDeleteRequested: $e');
    }
  }

  /// Refresca todo (evento + participantes)
  Future<void> _onRefreshRequested(
    EventDetailRefreshRequested event,
    Emitter<EventDetailState> emit,
  ) async {
    add(const EventDetailLoadRequested());
    add(const EventDetailParticipantsLoadRequested());
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    EventDetailErrorCleared event,
    Emitter<EventDetailState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
