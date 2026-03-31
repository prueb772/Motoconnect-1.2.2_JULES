/// Servicio de API de Eventos
///
/// Capa más baja de abstracción - interactúa directamente con Supabase
///
/// Responsabilidades:
/// - Llamadas a Supabase para eventos
/// - Conversión de respuestas a modelos
/// - Manejo de errores de API
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/api_constants.dart';
import '../../models/event_model.dart';
import '../../models/event_participant_model.dart';

class EventApiService {
  // ========================================
  // CLIENTE SUPABASE
  // ========================================

  /// Cliente de Supabase
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ========================================
  // MÉTODOS PÚBLICOS - CRUD EVENTOS
  // ========================================

  /// Obtiene todos los eventos
  Future<List<Event>> getEvents() async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .order('fecha_hora', ascending: true);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos: ${e.toString()}');
    }
  }

  /// Obtiene un evento por ID
  Future<Event?> getEventById(String eventId) async {
    try {
      final response =
          await _supabase
              .from(ApiConstants.eventsTable)
              .select('''
                *,
                evento_grupos(grupo_id, grupos_ruta(nombre))
              ''')
              .eq('id', eventId)
              .maybeSingle();

      if (response == null) return null;

      final grupos = response['evento_grupos'] as List? ?? [];
      if (grupos.isNotEmpty) {
        response['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
        response['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
      }

      return Event.fromJson(response);
    } catch (e) {
      throw Exception('Error al obtener evento: ${e.toString()}');
    }
  }

  /// Crea un nuevo evento
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
      final Map<String, dynamic> data = {
        'titulo': title,
        'descripcion': description,
        'fecha_hora': date.toIso8601String(),
        'destino': destino,
        'creado_por': createdBy,
        'is_public': isPublic,
      };

      if (puntoEncuentro != null) data['punto_encuentro'] = puntoEncuentro;
      if (puntoEncuentroLat != null) data['punto_encuentro_lat'] = puntoEncuentroLat;
      if (puntoEncuentroLng != null) data['punto_encuentro_lng'] = puntoEncuentroLng;
      if (destinoLat != null) data['destino_lat'] = destinoLat;
      if (destinoLng != null) data['destino_lng'] = destinoLng;
      if (fotoUrl != null) data['foto_url'] = fotoUrl;

      final response =
          await _supabase
              .from(ApiConstants.eventsTable)
              .insert(data)
              .select()
              .single();

      final eventId = response['id'] as String;
      if (gruposIds.isNotEmpty) {
        await _supabase.from('evento_grupos').insert(
          gruposIds.map((gid) => {'evento_id': eventId, 'grupo_id': gid}).toList(),
        );
      }

      return Event.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear evento: ${e.toString()}');
    }
  }

  /// Actualiza un evento
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
      final Map<String, dynamic> updates = {};
      if (title != null) updates['titulo'] = title;
      if (description != null) updates['descripcion'] = description;
      if (date != null) updates['fecha_hora'] = date.toIso8601String();
      if (puntoEncuentro != null) updates['punto_encuentro'] = puntoEncuentro;
      if (destino != null) updates['destino'] = destino;
      if (puntoEncuentroLat != null) updates['punto_encuentro_lat'] = puntoEncuentroLat;
      if (puntoEncuentroLng != null) updates['punto_encuentro_lng'] = puntoEncuentroLng;
      if (destinoLat != null) updates['destino_lat'] = destinoLat;
      if (destinoLng != null) updates['destino_lng'] = destinoLng;
      if (fotoUrl != null) updates['foto_url'] = fotoUrl;
      if (isPublic != null) updates['is_public'] = isPublic;

      await _supabase
          .from(ApiConstants.eventsTable)
          .update(updates)
          .eq('id', eventId);

      // Actualizar grupos asociados si se proporciona la lista
      if (gruposIds != null) {
        await _supabase.from('evento_grupos').delete().eq('evento_id', eventId);
        if (gruposIds.isNotEmpty) {
          await _supabase.from('evento_grupos').insert(
            gruposIds.map((gid) => {'evento_id': eventId, 'grupo_id': gid}).toList(),
          );
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar evento: ${e.toString()}');
    }
  }

  /// Elimina un evento
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from(ApiConstants.eventsTable).delete().eq('id', eventId);
    } catch (e) {
      throw Exception('Error al eliminar evento: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS PÚBLICOS - PARTICIPANTES
  // ========================================

  /// Registra un usuario a un evento con estado de asistencia
  Future<void> joinEvent(
    String eventId,
    String userId, {
    EstadoAsistencia estado = EstadoAsistencia.confirmado,
  }) async {
    try {
      await _supabase.from(ApiConstants.eventParticipantsTable).insert({
        'evento_id': eventId,
        'usuario_id': userId,
        'estado': estado.toStringValue(),
      });
    } catch (e) {
      throw Exception('Error al unirse al evento: ${e.toString()}');
    }
  }

  /// Actualiza el estado de asistencia de un participante
  Future<void> updateAttendanceStatus(
    String eventId,
    String userId,
    EstadoAsistencia estado,
  ) async {
    try {
      await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .update({'estado': estado.toStringValue()})
          .eq('evento_id', eventId)
          .eq('usuario_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar estado de asistencia: ${e.toString()}');
    }
  }

  /// Cancela participación
  Future<void> leaveEvent(String eventId, String userId) async {
    try {
      await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .delete()
          .eq('evento_id', eventId)
          .eq('usuario_id', userId);
    } catch (e) {
      throw Exception('Error al cancelar participación: ${e.toString()}');
    }
  }

  /// Obtiene participantes de un evento (solo IDs de confirmados)
  Future<List<String>> getEventParticipants(String eventId) async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .select('usuario_id')
          .eq('evento_id', eventId)
          .eq('estado', 'confirmado');

      return (response as List)
          .map((item) => item['usuario_id'] as String)
          .toList();
    } catch (e) {
      throw Exception('Error al obtener participantes: ${e.toString()}');
    }
  }

  /// Obtiene participantes detallados de un evento con información de usuario
  Future<List<EventParticipantModel>> getEventParticipantsDetailed(
    String eventId,
  ) async {
    try {
      // Join con usuarios para obtener información completa
      final response = await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .select('''
            *,
            usuarios (
              id,
              nombre,
              apodo,
              foto_perfil_url
            )
          ''')
          .eq('evento_id', eventId)
          .order('fecha_registro', ascending: true);

      return (response as List)
          .map((json) => EventParticipantModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener participantes detallados: ${e.toString()}');
    }
  }

  /// Verifica si un usuario está registrado
  Future<bool> isUserJoined(String eventId, String userId) async {
    try {
      final response =
          await _supabase
              .from(ApiConstants.eventParticipantsTable)
              .select()
              .eq('evento_id', eventId)
              .eq('usuario_id', userId)
              .eq('estado', 'confirmado')
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Busca eventos por título o ubicación
  Future<List<Event>> searchEvents(String query) async {
    try {
      if (query.isEmpty) return [];

      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .or('titulo.ilike.%$query%,punto_encuentro.ilike.%$query%,destino.ilike.%$query%')
          .order('fecha_hora', ascending: true)
          .limit(20);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al buscar eventos: ${e.toString()}');
    }
  }

  /// Obtiene eventos próximos (futuro)
  Future<List<Event>> getUpcomingEvents() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .gte('fecha_hora', now)
          .order('fecha_hora', ascending: true);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos próximos: ${e.toString()}');
    }
  }

  /// Obtiene eventos pasados
  Future<List<Event>> getPastEvents() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .lt('fecha_hora', now)
          .order('fecha_hora', ascending: false);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos pasados: ${e.toString()}');
    }
  }

  /// Obtiene eventos creados por un usuario
  Future<List<Event>> getEventsByUser(String userId) async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .eq('creado_por', userId)
          .order('fecha_hora', ascending: false);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos del usuario: ${e.toString()}');
    }
  }

  /// Obtiene eventos en los que participa un usuario
  Future<List<Event>> getEventsUserJoined(String userId) async {
    try {
      // Obtener IDs de eventos donde el usuario es participante
      final participations = await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .select('evento_id')
          .eq('usuario_id', userId)
          .eq('estado', 'confirmado');

      if ((participations as List).isEmpty) return [];

      final eventIds = participations.map((p) => p['evento_id']).toList();

      // Obtener los eventos correspondientes
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .inFilter('id', eventIds)
          .order('fecha_hora', ascending: true);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception(
          'Error al obtener eventos donde participa el usuario: ${e.toString()}');
    }
  }

  /// Obtiene el conteo de participantes de un evento
  Future<int> getEventParticipantsCount(String eventId) async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventParticipantsTable)
          .select('usuario_id')
          .eq('evento_id', eventId)
          .eq('estado', 'confirmado');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Verifica si un usuario es el creador de un evento
  Future<bool> isUserCreator(String eventId, String userId) async {
    try {
      final event = await getEventById(eventId);
      return event?.createdBy == userId;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene eventos por ubicación cercana
  Future<List<Event>> getEventsByLocation({
    required String location,
  }) async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .or('punto_encuentro.ilike.%$location%,destino.ilike.%$location%')
          .order('fecha_hora', ascending: true);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener eventos por ubicación: ${e.toString()}');
    }
  }

  /// Obtiene eventos en un rango de fechas
  Future<List<Event>> getEventsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from(ApiConstants.eventsTable)
          .select('''
            *,
            evento_grupos(grupo_id, grupos_ruta(nombre))
          ''')
          .gte('fecha_hora', startDate.toIso8601String())
          .lte('fecha_hora', endDate.toIso8601String())
          .order('fecha_hora', ascending: true);

      return (response as List).map((json) {
        final grupos = json['evento_grupos'] as List? ?? [];
        if (grupos.isNotEmpty) {
          json['grupo_nombre'] = grupos.first['grupos_ruta']?['nombre'];
          json['grupos_ids'] = grupos.map((g) => g['grupo_id'] as String).toList();
        }
        return Event.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception(
          'Error al obtener eventos por rango de fechas: ${e.toString()}');
    }
  }
}
