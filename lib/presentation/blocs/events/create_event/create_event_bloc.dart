import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/grupo_ruta_model.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/grupo_repository.dart';

part 'create_event_event.dart';
part 'create_event_state.dart';

/// CreateEventBloc - Gestiona el estado de la pantalla de crear/editar evento
///
/// Es responsable de:
/// - Cargar grupos del usuario
/// - Cargar grupos asociados al evento (en modo edición)
/// - Subir imágenes a Storage (delegando al repositorio)
/// - Crear y actualizar eventos
class CreateEventBloc extends Bloc<CreateEventEvent, CreateEventState> {
  CreateEventBloc({
    required EventRepository eventRepository,
    required GrupoRepository grupoRepository,
  })  : _eventRepository = eventRepository,
        _grupoRepository = grupoRepository,
        super(const CreateEventState()) {
    on<CreateEventGruposLoadRequested>(_onGruposLoadRequested);
    on<CreateEventGruposForEventLoadRequested>(
        _onGruposForEventLoadRequested);
    on<CreateEventSaveRequested>(_onSaveRequested);
    on<CreateEventErrorCleared>(_onErrorCleared);
  }

  final EventRepository _eventRepository;
  final GrupoRepository _grupoRepository;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _eventRepository.getCurrentUserId();

  /// Carga los grupos del usuario actual
  Future<void> _onGruposLoadRequested(
    CreateEventGruposLoadRequested event,
    Emitter<CreateEventState> emit,
  ) async {
    emit(state.copyWith(isLoadingGrupos: true));

    try {
      final grupos = await _grupoRepository.obtenerMisGrupos();
      emit(state.copyWith(
        grupos: grupos,
        isLoadingGrupos: false,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingGrupos: false,
        errorMessage: 'Error al cargar grupos: ${e.toString()}',
      ));
      debugPrint('Error en CreateEventBloc._onGruposLoadRequested: $e');
    }
  }

  /// Carga los grupos asociados a un evento (modo edición)
  Future<void> _onGruposForEventLoadRequested(
    CreateEventGruposForEventLoadRequested event,
    Emitter<CreateEventState> emit,
  ) async {
    try {
      final ids = await _eventRepository.getGruposForEvent(event.eventId);
      emit(state.copyWith(selectedGrupoIds: ids.toList()));
    } catch (_) {
      // Si la tabla aún no existe, ignorar
    }
  }

  /// Guarda (crea o actualiza) un evento
  Future<void> _onSaveRequested(
    CreateEventSaveRequested event,
    Emitter<CreateEventState> emit,
  ) async {
    emit(state.copyWith(status: CreateEventStatus.saving));

    try {
      final userId = _eventRepository.getCurrentUserId();
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Subir imagen si hay una nueva (delegando al repositorio)
      String? fotoUrl = event.existingImageUrl;
      if (event.imageFile != null) {
        fotoUrl = await _eventRepository.uploadEventImage(
          imageFile: event.imageFile!,
          userId: userId,
        );
      }

      if (event.existingEventId == null) {
        // Crear nuevo evento
        await _eventRepository.createEvent(
          title: event.title,
          description: event.description,
          date: event.dateTime,
          destino: event.destinoTexto,
          createdBy: userId,
          puntoEncuentro: event.puntoEncuentroTexto,
          puntoEncuentroLat: event.puntoEncuentroLat,
          puntoEncuentroLng: event.puntoEncuentroLng,
          destinoLat: event.destinoLat,
          destinoLng: event.destinoLng,
          fotoUrl: fotoUrl,
          gruposIds: event.gruposIds,
          isPublic: event.isPublic,
        );
      } else {
        // Actualizar evento existente
        await _eventRepository.updateEvent(
          eventId: event.existingEventId!,
          title: event.title,
          description: event.description,
          date: event.dateTime,
          puntoEncuentro: event.puntoEncuentroTexto,
          destino: event.destinoTexto,
          puntoEncuentroLat: event.puntoEncuentroLat,
          puntoEncuentroLng: event.puntoEncuentroLng,
          destinoLat: event.destinoLat,
          destinoLng: event.destinoLng,
          fotoUrl: fotoUrl,
          gruposIds: event.gruposIds,
          isPublic: event.isPublic,
        );
      }

      emit(state.copyWith(
        status: CreateEventStatus.saved,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CreateEventStatus.error,
        errorMessage: 'Error al guardar evento: ${e.toString()}',
      ));
      debugPrint('Error en CreateEventBloc._onSaveRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    CreateEventErrorCleared event,
    Emitter<CreateEventState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
