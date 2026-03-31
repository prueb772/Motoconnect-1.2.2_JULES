part of 'crear_grupo_bloc.dart';

enum CrearGrupoStatus { initial, loading, success, error }

class CrearGrupoState extends Equatable {
  const CrearGrupoState({
    this.status = CrearGrupoStatus.initial,
    this.grupoCreado,
    this.errorMessage,
  });

  final CrearGrupoStatus status;
  final GrupoRutaModel? grupoCreado;
  final String? errorMessage;

  CrearGrupoState copyWith({
    CrearGrupoStatus? status,
    GrupoRutaModel? grupoCreado,
    String? errorMessage,
  }) {
    return CrearGrupoState(
      status: status ?? this.status,
      grupoCreado: grupoCreado ?? this.grupoCreado,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, grupoCreado, errorMessage];
}
