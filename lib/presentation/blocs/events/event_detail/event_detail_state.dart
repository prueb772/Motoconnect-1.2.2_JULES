part of 'event_detail_bloc.dart';

/// Estados posibles del detalle de evento
enum EventDetailStatus {
  /// Estado inicial
  initial,

  /// Cargando datos
  loading,

  /// Datos cargados
  loaded,

  /// Estado de asistencia actualizado
  attendanceUpdated,

  /// Eliminando evento
  deleting,

  /// Evento eliminado
  deleted,

  /// Error
  error,
}

/// Estado del EventDetailBloc
class EventDetailState extends Equatable {
  const EventDetailState({
    this.status = EventDetailStatus.initial,
    this.event,
    this.participants = const [],
    this.userAttendanceStatus,
    this.isLoadingParticipants = false,
    this.currentUserId,
    this.errorMessage,
  });

  /// Estado actual
  final EventDetailStatus status;

  /// Datos del evento
  final Event? event;

  /// Lista de participantes
  final List<EventParticipantModel> participants;

  /// Estado de asistencia del usuario actual
  final EstadoAsistencia? userAttendanceStatus;

  /// Si está cargando participantes
  final bool isLoadingParticipants;

  /// ID del usuario autenticado
  final String? currentUserId;

  /// Mensaje de error
  final String? errorMessage;

  /// Verifica si el usuario actual es el creador del evento
  bool get isCreator =>
      currentUserId != null && event?.createdBy == currentUserId;

  /// Crea una copia del estado con los campos modificados
  EventDetailState copyWith({
    EventDetailStatus? status,
    Event? event,
    List<EventParticipantModel>? participants,
    EstadoAsistencia? userAttendanceStatus,
    bool? isLoadingParticipants,
    String? currentUserId,
    String? errorMessage,
    bool clearError = false,
    bool clearUserStatus = false,
  }) {
    return EventDetailState(
      status: status ?? this.status,
      event: event ?? this.event,
      participants: participants ?? this.participants,
      userAttendanceStatus: clearUserStatus
          ? null
          : (userAttendanceStatus ?? this.userAttendanceStatus),
      isLoadingParticipants:
          isLoadingParticipants ?? this.isLoadingParticipants,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        event,
        participants,
        userAttendanceStatus,
        isLoadingParticipants,
        currentUserId,
        errorMessage,
      ];
}
