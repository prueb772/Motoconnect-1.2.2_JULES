part of 'editar_grupo_bloc.dart';

enum EditarGrupoStatus { initial, loading, success, error }

class EditarGrupoState extends Equatable {
  const EditarGrupoState({
    this.status = EditarGrupoStatus.initial,
    this.errorMessage,
  });

  final EditarGrupoStatus status;
  final String? errorMessage;

  EditarGrupoState copyWith({
    EditarGrupoStatus? status,
    String? errorMessage,
  }) {
    return EditarGrupoState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
