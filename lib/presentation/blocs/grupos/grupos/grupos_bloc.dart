import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/grupo_ruta_model.dart';
import '../../../../data/repositories/grupo_repository.dart';

part 'grupos_event.dart';
part 'grupos_state.dart';

/// GruposBloc — Gestiona la lista de grupos del usuario
class GruposBloc extends Bloc<GruposEvent, GruposState> {
  GruposBloc({
    required GrupoRepository grupoRepository,
  })  : _grupoRepository = grupoRepository,
        super(const GruposState()) {
    on<GruposLoadRequested>(_onLoadRequested);
  }

  final GrupoRepository _grupoRepository;

  Future<void> _onLoadRequested(
    GruposLoadRequested event,
    Emitter<GruposState> emit,
  ) async {
    emit(state.copyWith(status: GruposStatus.loading));

    try {
      final grupos = await _grupoRepository.obtenerMisGrupos();
      emit(state.copyWith(
        status: GruposStatus.loaded,
        grupos: grupos,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: GruposStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
