import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/grupo_repository.dart';
import '../../../../data/models/solicitud_grupo_model.dart';

part 'unirse_grupo_event.dart';
part 'unirse_grupo_state.dart';

/// UnirseGrupoBloc — Gestiona la solicitud de unirse a un grupo
class UnirseGrupoBloc extends Bloc<UnirseGrupoEvent, UnirseGrupoState> {
  UnirseGrupoBloc({
    required GrupoRepository grupoRepository,
  })  : _grupoRepository = grupoRepository,
        super(const UnirseGrupoState()) {
    on<UnirseGrupoSubmitted>(_onSubmitted);
  }

  final GrupoRepository _grupoRepository;

  Future<void> _onSubmitted(
    UnirseGrupoSubmitted event,
    Emitter<UnirseGrupoState> emit,
  ) async {
    emit(state.copyWith(status: UnirseGrupoStatus.loading));

    try {
      final solicitud = await _grupoRepository.solicitarUnirseAGrupo(
        event.codigo,
      );

      emit(state.copyWith(
        status: UnirseGrupoStatus.success,
        solicitud: solicitud,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: UnirseGrupoStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
