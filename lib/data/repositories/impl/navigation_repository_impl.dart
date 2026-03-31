/// NavigationRepositoryImpl — Implementación concreta
///
/// Implementa [NavigationRepository] usando Supabase como fuente de datos.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/navigation_session.dart';
import '../../models/navigation_progress.dart';
import '../../models/navigation_step.dart';
import '../navigation_repository.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  /// Cliente de Supabase
  final SupabaseClient _supabase;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  /// Constructor con inyección de dependencias
  NavigationRepositoryImpl({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  // ========================================
  // MÉTODOS DE SESIONES DE NAVEGACIÓN
  // ========================================

  @override
  Future<NavigationSession> createNavigationSession({
    required LatLng origin,
    required LatLng destination,
    String? destinationName,
    String? sesionGrupalId,
    required List<NavigationStep> steps,
    required List<LatLng> completePolyline,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    final totalDistance = steps.fold<double>(
      0.0,
      (sum, step) => sum + step.distanceMeters,
    );
    final totalDuration = steps.fold<int>(
      0,
      (sum, step) => sum + step.durationSeconds,
    );

    try {
      final stepsJson = steps.map((s) => s.toJson()).toList();
      final polylineJson = completePolyline
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();

      final response = await _supabase.from('sesiones_navegacion').insert({
        'usuario_id': userId,
        'sesion_grupal_id': sesionGrupalId,
        'origen_lat': origin.latitude,
        'origen_lng': origin.longitude,
        'destino_lat': destination.latitude,
        'destino_lng': destination.longitude,
        'destino_nombre': destinationName,
        'steps': stepsJson,
        'polyline': polylineJson,
        'distancia_total_metros': totalDistance,
        'duracion_total_segundos': totalDuration,
        'estado': 'navigating',
        'paso_actual': 0,
        'distancia_recorrida_metros': 0,
      }).select().single();

      return NavigationSession.fromJson(response);
    } catch (e) {
      // Supabase no disponible → crear sesión local para que la navegación funcione igual
      debugPrint('Warning: Supabase no disponible, usando sesión local: $e');
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      return NavigationSession(
        id: localId,
        userId: userId,
        sesionGrupalId: sesionGrupalId,
        origin: origin,
        destination: destination,
        destinationName: destinationName,
        steps: steps,
        completePolyline: completePolyline,
        status: NavigationStatus.navigating,
        startTime: DateTime.now(),
        totalDistanceMeters: totalDistance,
        totalDurationSeconds: totalDuration,
      );
    }
  }

  @override
  Future<NavigationSession?> getNavigationSession(String sessionId) async {
    try {
      final response = await _supabase
          .from('sesiones_navegacion')
          .select()
          .eq('id', sessionId)
          .maybeSingle();

      if (response == null) return null;

      return NavigationSession.fromJson(response);
    } catch (e) {
      throw Exception(
          'Error al obtener sesión de navegación: ${e.toString()}');
    }
  }

  @override
  Future<List<NavigationSession>> getUserNavigationSessions({
    int limit = 20,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('sesiones_navegacion')
          .select()
          .eq('usuario_id', userId)
          .order('fecha_inicio', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => NavigationSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception(
          'Error al obtener sesiones del usuario: ${e.toString()}');
    }
  }

  @override
  Future<void> updateNavigationSession({
    required String sessionId,
    int? currentStepIndex,
    double? distanceTraveled,
    NavigationStatus? status,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (currentStepIndex != null) {
        updates['paso_actual'] = currentStepIndex;
      }

      if (distanceTraveled != null) {
        updates['distancia_recorrida_metros'] = distanceTraveled;
      }

      if (status != null) {
        updates['estado'] = status.toStringValue();
      }

      if (updates.isEmpty) return;

      await _supabase.from('sesiones_navegacion').update(updates).eq(
            'id',
            sessionId,
          );
    } catch (e) {
      throw Exception(
          'Error al actualizar sesión de navegación: ${e.toString()}');
    }
  }

  @override
  Future<void> pauseNavigation(String sessionId) async {
    try {
      await _supabase.from('sesiones_navegacion').update({
        'estado': 'paused',
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Error al pausar navegación: ${e.toString()}');
    }
  }

  @override
  Future<void> resumeNavigation(String sessionId) async {
    try {
      await _supabase.from('sesiones_navegacion').update({
        'estado': 'navigating',
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Error al reanudar navegación: ${e.toString()}');
    }
  }

  @override
  Future<void> endNavigation({
    required String sessionId,
    required NavigationStatus status,
  }) async {
    try {
      if (status != NavigationStatus.completed &&
          status != NavigationStatus.cancelled) {
        throw Exception('Estado final debe ser completed o cancelled');
      }

      await _supabase.from('sesiones_navegacion').update({
        'estado': status.toStringValue(),
        'fecha_fin': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      throw Exception('Error al finalizar navegación: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS DE PROGRESO EN TIEMPO REAL
  // ========================================

  @override
  Future<void> updateNavigationProgress({
    required String sessionId,
    required int currentStepIndex,
    required LatLng currentLocation,
    double? distanceToNextStep,
    int? etaSeconds,
    double? remainingDistance,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('progreso_navegacion_tiempo_real').upsert({
        'sesion_navegacion_id': sessionId,
        'usuario_id': userId,
        'paso_actual': currentStepIndex,
        'ubicacion_lat': currentLocation.latitude,
        'ubicacion_lng': currentLocation.longitude,
        'distancia_siguiente_paso': distanceToNextStep,
        'eta_segundos': etaSeconds,
        'distancia_restante_metros': remainingDistance,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      });

      // También actualizar la sesión principal
      await updateNavigationSession(
        sessionId: sessionId,
        currentStepIndex: currentStepIndex,
      );
    } catch (e) {
      throw Exception(
          'Error al actualizar progreso de navegación: ${e.toString()}');
    }
  }

  @override
  Stream<List<NavigationProgress>> streamGroupNavigationProgress(
    String sesionGrupalId,
  ) {
    return _supabase
        .from('vista_progreso_navegacion_actual')
        .stream(primaryKey: ['id'])
        .eq('sesion_grupal_id', sesionGrupalId)
        .map((data) {
          return (data as List)
              .map((json) => NavigationProgress.fromJson(json))
              .toList();
        });
  }

  @override
  Future<NavigationProgress?> getUserProgress({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('progreso_navegacion_tiempo_real')
          .select()
          .eq('sesion_navegacion_id', sessionId)
          .eq('usuario_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return NavigationProgress.fromJson(response);
    } catch (e) {
      throw Exception(
          'Error al obtener progreso del usuario: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUserProgress(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('progreso_navegacion_tiempo_real')
          .delete()
          .eq('sesion_navegacion_id', sessionId)
          .eq('usuario_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar progreso: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS DE UTILIDAD
  // ========================================

  @override
  Future<void> deleteNavigationSession(String sessionId) async {
    try {
      await _supabase.from('sesiones_navegacion').delete().eq('id', sessionId);
    } catch (e) {
      throw Exception('Error al eliminar sesión: ${e.toString()}');
    }
  }

  @override
  Future<NavigationSession?> getActiveNavigation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('sesiones_navegacion')
          .select()
          .eq('usuario_id', userId)
          .eq('estado', 'navigating')
          .order('fecha_inicio', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return NavigationSession.fromJson(response);
    } catch (e) {
      throw Exception(
          'Error al verificar navegación activa: ${e.toString()}');
    }
  }
}
