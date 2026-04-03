import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/taller_repository.dart';
import '../../../data/models/taller_model.dart';

part 'talleres_event.dart';
part 'talleres_state.dart';

/// TalleresBloc - Gestiona el estado de la pantalla de Talleres
///
/// Este BLoC reemplaza a TalleresViewModel.
/// Es responsable de:
/// - Cargar, crear, actualizar y eliminar talleres
/// - Compartir talleres en la comunidad
/// - Filtrar talleres
class TalleresBloc extends Bloc<TalleresEvent, TalleresState> {
  TalleresBloc({
    required TallerRepository tallerRepository,
  })  : _tallerRepository = tallerRepository,
        super(const TalleresState()) {
    on<TalleresLoadRequested>(_onLoadRequested);
    on<TalleresRefreshRequested>(_onRefreshRequested);
    on<TallerCreateRequested>(_onCreateRequested);
    on<TallerUpdateRequested>(_onUpdateRequested);
    on<TallerDeleteRequested>(_onDeleteRequested);
    on<TallerShareRequested>(_onShareRequested);
    on<TalleresErrorCleared>(_onErrorCleared);
  }

  final TallerRepository _tallerRepository;

  /// Carga la lista de talleres
  Future<void> _onLoadRequested(
    TalleresLoadRequested event,
    Emitter<TalleresState> emit,
  ) async {
    emit(state.copyWith(status: TalleresStatus.loading));

    try {
      final talleresData = await _tallerRepository.getTalleres();
      final currentUserId = _tallerRepository.getCurrentUserId();

      final talleres = talleresData
          .map((data) => TallerConCreador(
                tallerData: data.taller,
                nombreCreador: data.nombreCreador,
              ))
          .toList();

      emit(state.copyWith(
        status: TalleresStatus.loaded,
        talleres: talleres,
        currentUserId: currentUserId,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TalleresStatus.error,
        errorMessage: 'Error al cargar talleres: ${e.toString()}',
      ));
      debugPrint('Error en TalleresBloc._onLoadRequested: $e');
    }
  }

  /// Refresca la lista de talleres
  Future<void> _onRefreshRequested(
    TalleresRefreshRequested event,
    Emitter<TalleresState> emit,
  ) async {
    await _onLoadRequested(const TalleresLoadRequested(), emit);
  }

  /// Crea un nuevo taller
  Future<void> _onCreateRequested(
    TallerCreateRequested event,
    Emitter<TalleresState> emit,
  ) async {
    final currentUserUid = _tallerRepository.getCurrentUserId();

    if (currentUserUid == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión'));
      return;
    }

    if (event.tallerData.nombre.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'El nombre del taller es obligatorio'));
      return;
    }

    emit(state.copyWith(status: TalleresStatus.saving));

    try {
      await _tallerRepository.createTaller(
        taller: event.tallerData,
        userId: currentUserUid,
      );

      emit(state.copyWith(status: TalleresStatus.saved));

      // Recargar la lista de talleres
      add(const TalleresLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: TalleresStatus.error,
        errorMessage: 'Error al crear taller: ${e.toString()}',
      ));
      debugPrint('Error en TalleresBloc._onCreateRequested: $e');
    }
  }

  /// Actualiza un taller existente
  Future<void> _onUpdateRequested(
    TallerUpdateRequested event,
    Emitter<TalleresState> emit,
  ) async {
    if (event.tallerData.nombre.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'El nombre del taller es obligatorio'));
      return;
    }

    emit(state.copyWith(status: TalleresStatus.saving));

    try {
      await _tallerRepository.updateTaller(
        tallerId: event.tallerId,
        taller: event.tallerData,
      );

      emit(state.copyWith(status: TalleresStatus.saved));

      // Recargar la lista de talleres
      add(const TalleresLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: TalleresStatus.error,
        errorMessage: 'Error al actualizar taller: ${e.toString()}',
      ));
      debugPrint('Error en TalleresBloc._onUpdateRequested: $e');
    }
  }

  /// Elimina un taller
  Future<void> _onDeleteRequested(
    TallerDeleteRequested event,
    Emitter<TalleresState> emit,
  ) async {
    emit(state.copyWith(status: TalleresStatus.processing));

    try {
      await _tallerRepository.deleteTaller(event.tallerId);

      // Remover de la lista local
      final updatedTalleres = state.talleres
          .where((t) => t.tallerData.id != event.tallerId)
          .toList();

      emit(state.copyWith(
        status: TalleresStatus.deleted,
        talleres: updatedTalleres,
        clearError: true,
      ));

      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: TalleresStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: TalleresStatus.error,
        errorMessage: 'Error al eliminar taller: ${e.toString()}',
      ));
      debugPrint('Error en TalleresBloc._onDeleteRequested: $e');
    }
  }

  /// Comparte un taller en la comunidad
  Future<void> _onShareRequested(
    TallerShareRequested event,
    Emitter<TalleresState> emit,
  ) async {
    final currentUserUid = _tallerRepository.getCurrentUserId();

    if (currentUserUid == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión para compartir'));
      return;
    }

    emit(state.copyWith(status: TalleresStatus.processing));

    try {
      await _tallerRepository.shareTallerToCommunity(
        userId: currentUserUid,
        taller: event.tallerData,
        message: event.message,
      );

      emit(state.copyWith(
        status: TalleresStatus.shared,
        clearError: true,
      ));

      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: TalleresStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: TalleresStatus.error,
        errorMessage: 'Error al compartir taller: ${e.toString()}',
      ));
      debugPrint('Error en TalleresBloc._onShareRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    TalleresErrorCleared event,
    Emitter<TalleresState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  /// Verifica si el usuario actual es el creador de un taller
  bool esCreadorDelTaller(TallerModel tallerData) {
    final currentUserUid = state.currentUserId;
    return currentUserUid != null && tallerData.creadoPor == currentUserUid;
  }
}
