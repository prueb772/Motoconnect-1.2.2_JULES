part of 'unirse_grupo_bloc.dart';

enum UnirseGrupoStatus { initial, loading, success, error }

class UnirseGrupoState extends Equatable {
  const UnirseGrupoState({
    this.status = UnirseGrupoStatus.initial,
    this.solicitud,
    this.errorMessage,
  });

  final UnirseGrupoStatus status;
  final SolicitudGrupoModel? solicitud;
  final String? errorMessage;

  UnirseGrupoState copyWith({
    UnirseGrupoStatus? status,
    SolicitudGrupoModel? solicitud,
    String? errorMessage,
  }) {
    return UnirseGrupoState(
      status: status ?? this.status,
      solicitud: solicitud ?? this.solicitud,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, solicitud, errorMessage];
}
