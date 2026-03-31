part of 'create_event_bloc.dart';

/// Estados posibles de crear/editar evento
enum CreateEventStatus {
  /// Estado inicial
  initial,

  /// Guardando evento
  saving,

  /// Evento guardado exitosamente
  saved,

  /// Error
  error,
}

/// Estado del CreateEventBloc
class CreateEventState extends Equatable {
  const CreateEventState({
    this.status = CreateEventStatus.initial,
    this.grupos = const [],
    this.selectedGrupoIds = const [],
    this.isLoadingGrupos = false,
    this.errorMessage,
  });

  /// Estado actual
  final CreateEventStatus status;

  /// Lista de grupos disponibles
  final List<GrupoRutaModel> grupos;

  /// IDs de grupos seleccionados (para modo edición)
  final List<String> selectedGrupoIds;

  /// Si está cargando grupos
  final bool isLoadingGrupos;

  /// Mensaje de error
  final String? errorMessage;

  /// Crea una copia del estado con campos modificados
  CreateEventState copyWith({
    CreateEventStatus? status,
    List<GrupoRutaModel>? grupos,
    List<String>? selectedGrupoIds,
    bool? isLoadingGrupos,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateEventState(
      status: status ?? this.status,
      grupos: grupos ?? this.grupos,
      selectedGrupoIds: selectedGrupoIds ?? this.selectedGrupoIds,
      isLoadingGrupos: isLoadingGrupos ?? this.isLoadingGrupos,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        grupos,
        selectedGrupoIds,
        isLoadingGrupos,
        errorMessage,
      ];
}
