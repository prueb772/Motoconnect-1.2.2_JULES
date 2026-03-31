import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/grupo_repository.dart';
import '../../../../data/models/grupo_ruta_model.dart';

part 'crear_grupo_event.dart';
part 'crear_grupo_state.dart';

/// CrearGrupoBloc — Gestiona la creación de nuevos grupos
///
/// Responsabilidades:
/// - Crear grupo vía repositorio
/// - Subir foto de grupo si existe
/// - Gestionar estados de carga y error
class CrearGrupoBloc extends Bloc<CrearGrupoEvent, CrearGrupoState> {
  CrearGrupoBloc({
    required GrupoRepository grupoRepository,
  })  : _grupoRepository = grupoRepository,
        super(const CrearGrupoState()) {
    on<CrearGrupoSubmitted>(_onSubmitted);
  }

  final GrupoRepository _grupoRepository;

  Future<void> _onSubmitted(
    CrearGrupoSubmitted event,
    Emitter<CrearGrupoState> emit,
  ) async {
    emit(state.copyWith(status: CrearGrupoStatus.loading));

    try {
      final grupo = await _grupoRepository.crearGrupo(
        nombre: event.nombre,
        descripcion: event.descripcion,
      );

      // Si hay foto, subirla y actualizar el grupo
      if (event.imagePath != null) {
        final fotoUrl = await _grupoRepository.subirFotoGrupo(
          grupoId: grupo.id,
          imagePath: event.imagePath!,
        );
        await _grupoRepository.actualizarGrupo(
          grupoId: grupo.id,
          fotoUrl: fotoUrl,
        );
      }

      emit(state.copyWith(
        status: CrearGrupoStatus.success,
        grupoCreado: grupo,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CrearGrupoStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
