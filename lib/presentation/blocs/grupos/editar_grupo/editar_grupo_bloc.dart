import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/grupo_repository.dart';

part 'editar_grupo_event.dart';
part 'editar_grupo_state.dart';

/// EditarGrupoBloc — Gestiona la edición de un grupo existente
class EditarGrupoBloc extends Bloc<EditarGrupoEvent, EditarGrupoState> {
  EditarGrupoBloc({
    required GrupoRepository grupoRepository,
  })  : _grupoRepository = grupoRepository,
        super(const EditarGrupoState()) {
    on<EditarGrupoSubmitted>(_onSubmitted);
  }

  final GrupoRepository _grupoRepository;

  Future<void> _onSubmitted(
    EditarGrupoSubmitted event,
    Emitter<EditarGrupoState> emit,
  ) async {
    emit(state.copyWith(status: EditarGrupoStatus.loading));

    try {
      String? fotoUrl = event.fotoUrlActual;

      // Si hay nueva imagen, subirla
      if (event.imagePath != null) {
        fotoUrl = await _grupoRepository.subirFotoGrupo(
          grupoId: event.grupoId,
          imagePath: event.imagePath!,
        );
      }

      // Actualizar grupo
      await _grupoRepository.actualizarGrupo(
        grupoId: event.grupoId,
        nombre: event.nombre,
        descripcion: event.descripcion,
        fotoUrl: fotoUrl,
      );

      emit(state.copyWith(status: EditarGrupoStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: EditarGrupoStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
