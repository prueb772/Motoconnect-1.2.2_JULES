import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/saved_routes_repository.dart';
import '../../../../data/models/ruta_realizada_model.dart';

part 'saved_routes_event.dart';
part 'saved_routes_state.dart';

/// SavedRoutesBloc - Gestiona el estado de la pantalla de Rutas Guardadas
///
/// Este BLoC reemplaza a SavedRoutesViewModel.
/// Es responsable de:
/// - Cargar rutas guardadas del usuario
/// - Eliminar rutas
/// - Compartir rutas en la comunidad
class SavedRoutesBloc extends Bloc<SavedRoutesEvent, SavedRoutesState> {
  SavedRoutesBloc({
    required SavedRoutesRepository savedRoutesRepository,
  })  : _savedRoutesRepository = savedRoutesRepository,
        super(const SavedRoutesState()) {
    on<SavedRoutesLoadRequested>(_onLoadRequested);
    on<SavedRoutesRefreshRequested>(_onRefreshRequested);
    on<SavedRouteDeleteRequested>(_onDeleteRequested);
    on<SavedRouteShareRequested>(_onShareRequested);
    on<SavedRoutesErrorCleared>(_onErrorCleared);
  }

  final SavedRoutesRepository _savedRoutesRepository;

  /// Carga las rutas guardadas del usuario
  Future<void> _onLoadRequested(
    SavedRoutesLoadRequested event,
    Emitter<SavedRoutesState> emit,
  ) async {
    emit(state.copyWith(status: SavedRoutesStatus.loading));

    try {
      final currentUserUid = _savedRoutesRepository.getCurrentUserId();

      if (currentUserUid == null) {
        emit(state.copyWith(
          status: SavedRoutesStatus.loaded,
          routes: [],
        ));
        return;
      }

      final routes = await _savedRoutesRepository.getSavedRoutes(currentUserUid);

      emit(state.copyWith(
        status: SavedRoutesStatus.loaded,
        routes: routes,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: 'Error al cargar rutas: ${e.toString()}',
      ));
      debugPrint('Error en SavedRoutesBloc._onLoadRequested: $e');
    }
  }

  /// Refresca las rutas
  Future<void> _onRefreshRequested(
    SavedRoutesRefreshRequested event,
    Emitter<SavedRoutesState> emit,
  ) async {
    await _onLoadRequested(const SavedRoutesLoadRequested(), emit);
  }

  /// Elimina una ruta
  Future<void> _onDeleteRequested(
    SavedRouteDeleteRequested event,
    Emitter<SavedRoutesState> emit,
  ) async {
    emit(state.copyWith(status: SavedRoutesStatus.processing));

    try {
      await _savedRoutesRepository.deleteRoute(event.routeId);

      // Remover la ruta de la lista local
      final updatedRoutes = state.routes
          .where((r) => r.id != event.routeId)
          .toList();

      emit(state.copyWith(
        status: SavedRoutesStatus.deleted,
        routes: updatedRoutes,
        clearError: true,
      ));

      // Volver al estado loaded después de un breve delay
      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: SavedRoutesStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: 'Error al eliminar la ruta: ${e.toString()}',
      ));
      debugPrint('Error en SavedRoutesBloc._onDeleteRequested: $e');
    }
  }

  /// Comparte una ruta en la comunidad
  Future<void> _onShareRequested(
    SavedRouteShareRequested event,
    Emitter<SavedRoutesState> emit,
  ) async {
    final currentUserUid = _savedRoutesRepository.getCurrentUserId();

    if (currentUserUid == null) {
      emit(state.copyWith(
        errorMessage: 'Debes iniciar sesión para compartir',
      ));
      return;
    }

    emit(state.copyWith(status: SavedRoutesStatus.processing));

    try {
      await _savedRoutesRepository.shareRouteToCommunity(
        userId: currentUserUid,
        route: event.routeData,
        message: event.message,
      );

      emit(state.copyWith(
        status: SavedRoutesStatus.shared,
        clearError: true,
      ));

      // Volver al estado loaded después de un breve delay
      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: SavedRoutesStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: 'Error al compartir la ruta: ${e.toString()}',
      ));
      debugPrint('Error en SavedRoutesBloc._onShareRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    SavedRoutesErrorCleared event,
    Emitter<SavedRoutesState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
