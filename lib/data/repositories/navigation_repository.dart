/// NavigationRepository — Interfaz abstracta
///
/// Define el contrato para operaciones de navegación.
/// La implementación concreta se encuentra en impl/navigation_repository_impl.dart.
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_session.dart';
import '../models/navigation_progress.dart';
import '../models/navigation_step.dart';

abstract class NavigationRepository {
  // ========================================
  // MÉTODOS DE SESIONES DE NAVEGACIÓN
  // ========================================

  /// Crea una nueva sesión de navegación
  Future<NavigationSession> createNavigationSession({
    required LatLng origin,
    required LatLng destination,
    String? destinationName,
    String? sesionGrupalId,
    required List<NavigationStep> steps,
    required List<LatLng> completePolyline,
  });

  /// Obtiene una sesión de navegación por ID
  Future<NavigationSession?> getNavigationSession(String sessionId);

  /// Obtiene las sesiones de navegación del usuario actual
  Future<List<NavigationSession>> getUserNavigationSessions({
    int limit = 20,
  });

  /// Actualiza el progreso de una sesión de navegación
  Future<void> updateNavigationSession({
    required String sessionId,
    int? currentStepIndex,
    double? distanceTraveled,
    NavigationStatus? status,
  });

  /// Pausa una sesión de navegación
  Future<void> pauseNavigation(String sessionId);

  /// Reanuda una sesión de navegación
  Future<void> resumeNavigation(String sessionId);

  /// Finaliza una sesión de navegación
  Future<void> endNavigation({
    required String sessionId,
    required NavigationStatus status,
  });

  // ========================================
  // MÉTODOS DE PROGRESO EN TIEMPO REAL
  // ========================================

  /// Actualiza el progreso de navegación en tiempo real
  Future<void> updateNavigationProgress({
    required String sessionId,
    required int currentStepIndex,
    required LatLng currentLocation,
    double? distanceToNextStep,
    int? etaSeconds,
    double? remainingDistance,
  });

  /// Stream de progreso de navegación grupal
  Stream<List<NavigationProgress>> streamGroupNavigationProgress(
    String sesionGrupalId,
  );

  /// Obtiene el progreso actual de un usuario en una sesión
  Future<NavigationProgress?> getUserProgress({
    required String sessionId,
    required String userId,
  });

  /// Elimina el progreso de un usuario (cuando finaliza navegación)
  Future<void> deleteUserProgress(String sessionId);

  // ========================================
  // MÉTODOS DE UTILIDAD
  // ========================================

  /// Elimina una sesión de navegación
  Future<void> deleteNavigationSession(String sessionId);

  /// Verifica si un usuario tiene una navegación activa
  Future<NavigationSession?> getActiveNavigation();
}
