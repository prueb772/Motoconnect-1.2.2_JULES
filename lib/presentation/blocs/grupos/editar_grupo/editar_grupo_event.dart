part of 'editar_grupo_bloc.dart';

sealed class EditarGrupoEvent extends Equatable {
  const EditarGrupoEvent();
  @override
  List<Object?> get props => [];
}

class EditarGrupoSubmitted extends EditarGrupoEvent {
  const EditarGrupoSubmitted({
    required this.grupoId,
    required this.nombre,
    this.descripcion,
    this.imagePath,
    this.fotoUrlActual,
  });

  final String grupoId;
  final String nombre;
  final String? descripcion;
  final String? imagePath;
  final String? fotoUrlActual;

  @override
  List<Object?> get props => [grupoId, nombre, descripcion, imagePath, fotoUrlActual];
}
