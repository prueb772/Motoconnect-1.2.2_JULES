part of 'unirse_grupo_bloc.dart';

sealed class UnirseGrupoEvent extends Equatable {
  const UnirseGrupoEvent();
  @override
  List<Object?> get props => [];
}

class UnirseGrupoSubmitted extends UnirseGrupoEvent {
  const UnirseGrupoSubmitted(this.codigo);
  final String codigo;

  @override
  List<Object?> get props => [codigo];
}
