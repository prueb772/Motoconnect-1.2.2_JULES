/// EventRepositoryImpl — Implementación concreta
///
/// Implementa [EventRepository] usando Supabase como fuente de datos
/// a través de [EventApiService].
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api/event_api_service.dart';
import '../../models/event_model.dart';
import '../../models/event_participant_model.dart';
import '../event_repository.dart';
import '../../../core/constants/api_constants.dart';

class EventRepositoryImpl implements EventRepository {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  /// Servicio de API de eventos
  final EventApiService _apiService;

  /// Cliente de Supabase
  final SupabaseClient _supabase;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  /// Constructor con inyección de dependencias
  ///
  /// [apiService] - Servicio para llamadas a API de eventos
  EventRepositoryImpl({
    EventApiService? apiService,
    SupabaseClient? supabaseClient,
  })  : _apiService = apiService ?? EventApiService(),
        _supabase = supabaseClient ?? Supabase.instance.client;

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  @override
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  @override
  Future<List<Event>> getEvents() async {
    try {
      return await _apiService.getEvents();
    } catch (e) {
      throw Exception('Error al obtener eventos: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getUpcomingEvents() async {
    try {
      final allEvents = await _apiService.getEvents();
      final now = DateTime.now();
      return allEvents.where((event) => event.date.isAfter(now)).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos próximos: ${e.toString()}');
    }
  }

  @override
  Future<Event?> getEventById(String eventId) async {
    try {
      return await _apiService.getEventById(eventId);
    } catch (e) {
      throw Exception('Error al obtener evento: ${e.toString()}');
    }
  }

  @override
  Future<Event> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required String destino,
    required String createdBy,
    String? puntoEncuentro,
    double? puntoEncuentroLat,
    double? puntoEncuentroLng,
    double? destinoLat,
    double? destinoLng,
    String? fotoUrl,
    List<String> gruposIds = const [],
    bool isPublic = true,
  }) async {
    try {
      return await _apiService.createEvent(
        title: title,
        description: description,
        date: date,
        destino: destino,
        createdBy: createdBy,
        puntoEncuentro: puntoEncuentro,
        puntoEncuentroLat: puntoEncuentroLat,
        puntoEncuentroLng: puntoEncuentroLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
        fotoUrl: fotoUrl,
        gruposIds: gruposIds,
        isPublic: isPublic,
      );
    } catch (e) {
      throw Exception('Error al crear evento: ${e.toString()}');
    }
  }

  @override
  Future<void> updateEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? date,
    String? puntoEncuentro,
    String? destino,
    double? puntoEncuentroLat,
    double? puntoEncuentroLng,
    double? destinoLat,
    double? destinoLng,
    String? fotoUrl,
    List<String>? gruposIds,
    bool? isPublic,
  }) async {
    try {
      await _apiService.updateEvent(
        eventId: eventId,
        title: title,
        description: description,
        date: date,
        puntoEncuentro: puntoEncuentro,
        destino: destino,
        puntoEncuentroLat: puntoEncuentroLat,
        puntoEncuentroLng: puntoEncuentroLng,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
        fotoUrl: fotoUrl,
        gruposIds: gruposIds,
        isPublic: isPublic,
      );
    } catch (e) {
      throw Exception('Error al actualizar evento: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _apiService.deleteEvent(eventId);
    } catch (e) {
      throw Exception('Error al eliminar evento: ${e.toString()}');
    }
  }

  @override
  Future<void> joinEvent(
    String eventId,
    String userId, {
    EstadoAsistencia estado = EstadoAsistencia.confirmado,
  }) async {
    try {
      await _apiService.joinEvent(eventId, userId, estado: estado);
    } catch (e) {
      throw Exception('Error al unirse al evento: ${e.toString()}');
    }
  }

  @override
  Future<void> updateAttendanceStatus(
    String eventId,
    String userId,
    EstadoAsistencia estado,
  ) async {
    try {
      await _apiService.updateAttendanceStatus(eventId, userId, estado);
    } catch (e) {
      throw Exception('Error al actualizar estado de asistencia: ${e.toString()}');
    }
  }

  @override
  Future<void> leaveEvent(String eventId, String userId) async {
    try {
      await _apiService.leaveEvent(eventId, userId);
    } catch (e) {
      throw Exception('Error al cancelar participación: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getEventParticipants(String eventId) async {
    try {
      return await _apiService.getEventParticipants(eventId);
    } catch (e) {
      throw Exception('Error al obtener participantes: ${e.toString()}');
    }
  }

  @override
  Future<bool> isUserJoined(String eventId, String userId) async {
    try {
      return await _apiService.isUserJoined(eventId, userId);
    } catch (e) {
      throw Exception('Error al verificar participación: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      return await _apiService.searchEvents(query);
    } catch (e) {
      throw Exception('Error al buscar eventos: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getPastEvents() async {
    try {
      return await _apiService.getPastEvents();
    } catch (e) {
      throw Exception('Error al obtener eventos pasados: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getEventsByUser(String userId) async {
    try {
      return await _apiService.getEventsByUser(userId);
    } catch (e) {
      throw Exception('Error al obtener eventos del usuario: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getEventsUserJoined(String userId) async {
    try {
      return await _apiService.getEventsUserJoined(userId);
    } catch (e) {
      throw Exception(
          'Error al obtener eventos donde participa el usuario: ${e.toString()}');
    }
  }

  @override
  Future<int> getEventParticipantsCount(String eventId) async {
    try {
      return await _apiService.getEventParticipantsCount(eventId);
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<EventParticipantModel>> getEventParticipantsDetailed(
    String eventId,
  ) async {
    try {
      return await _apiService.getEventParticipantsDetailed(eventId);
    } catch (e) {
      throw Exception('Error al obtener participantes detallados: ${e.toString()}');
    }
  }

  @override
  Future<bool> isUserCreator(String eventId, String userId) async {
    try {
      return await _apiService.isUserCreator(eventId, userId);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Event>> getEventsByLocation({required String location}) async {
    try {
      return await _apiService.getEventsByLocation(location: location);
    } catch (e) {
      throw Exception('Error al obtener eventos por ubicación: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getEventsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await _apiService.getEventsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      throw Exception(
          'Error al obtener eventos por rango de fechas: ${e.toString()}');
    }
  }

  @override
  Future<List<Event>> getAllEvents() async {
    try {
      return await getEvents();
    } catch (e) {
      throw Exception('Error al obtener todos los eventos: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS NUEVOS (antes en CreateEventBloc)
  // ========================================

  @override
  Future<Set<String>> getGruposForEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('evento_grupos')
          .select('grupo_id')
          .eq('evento_id', eventId);
      return (response as List)
          .map((r) => r['grupo_id'] as String)
          .toSet();
    } catch (_) {
      // Si la tabla aún no existe, retornar vacío
      return {};
    }
  }

  @override
  Future<String?> uploadEventImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final fileName =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from(ApiConstants.eventsBucket)
          .upload(
            fileName,
            imageFile,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _supabase.storage
          .from(ApiConstants.eventsBucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      return null;
    }
  }
}
