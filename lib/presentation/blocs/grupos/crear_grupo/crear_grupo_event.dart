part of 'crear_grupo_bloc.dart';

sealed class CrearGrupoEvent extends Equatable {
  const CrearGrupoEvent();

  @override
  List<Object?> get props => [];
}

/// Evento: el usuario envía el formulario de creación
class CrearGrupoSubmitted extends CrearGrupoEvent {
  const CrearGrupoSubmitted({
    required this.nombre,
    this.descripcion,
    this.imagePath,
  });

  final String nombre;
  final String? descripcion;
  final String? imagePath;

  @override
  List<Object?> get props => [nombre, descripcion, imagePath];
}
