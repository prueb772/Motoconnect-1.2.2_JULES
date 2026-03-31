/// Caso de Uso: Actualizar Progreso de Navegación
///
/// Responsabilidades:
/// - Determinar paso actual basado en ubicación GPS
/// - Calcular distancia restante
/// - Calcular ETA dinámico
/// - Actualizar progreso en Supabase (para grupos)
/// - Retornar sesión actualizada
library;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/navigation_session.dart';
import '../../../data/services/navigation/navigation_tracking_service.dart';
import '../../../data/repositories/navigation_repository.dart';

class UpdateNavigationProgressUseCase {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  final NavigationTrackingService _trackingService;
  final NavigationRepository _navigationRepository;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  UpdateNavigationProgressUseCase({
    required NavigationTrackingService trackingService,
    required NavigationRepository navigationRepository,
  })  : _trackingService = trackingService,
        _navigationRepository = navigationRepository;

  // ========================================
  // MÉTODO PRINCIPAL
  // ========================================

  /// Ejecuta la actualización de progreso
  ///
  /// [currentSession] - Sesión actual de navegación
  /// [currentLocation] - Ubicación actual del usuario
  /// [currentSpeedKmh] - Velocidad actual en km/h
  ///
  /// Retorna:
  /// - NavigationSession actualizada
  Future<NavigationSession> execute({
    required NavigationSession currentSession,
    required LatLng currentLocation,
    required double currentSpeedKmh,
  }) async {
    // 1. Determinar paso actual
    final newStepIndex = _trackingService.determineCurrentStep(
      currentLocation: currentLocation,
      steps: currentSession.steps,
      lastStepIndex: currentSession.currentStepIndex,
    );

    // 2. Calcular distancia restante
    final remainingDistance = _trackingService.calculateRemainingDistance(
      currentLocation: currentLocation,
      steps: currentSession.steps,
      currentStepIndex: newStepIndex,
    );

    // 3. Calcular duración restante
    final remainingDuration = _trackingService.calculateRemainingDuration(
      steps: currentSession.steps,
      currentStepIndex: newStepIndex,
    );

    // 4. Calcular ETA
    final eta = _trackingService.calculateETA(
      remainingDistanceMeters: remainingDistance,
      currentSpeedKmh: currentSpeedKmh,
      remainingDurationSeconds: remainingDuration,
    );

    final etaSeconds = eta.difference(DateTime.now()).inSeconds;

    // 5. Calcular distancia al final del paso actual
    double? distanceToNextStep;
    if (newStepIndex < currentSession.steps.length) {
      distanceToNextStep = _trackingService.calculateDistanceToStepEnd(
        currentLocation: currentLocation,
        currentStep: currentSession.steps[newStepIndex],
      );
    }

    // 6. Actualizar en Supabase en background (NO bloquea si falla - bug fix)
    _navigationRepository
        .updateNavigationProgress(
          sessionId: currentSession.id,
          currentStepIndex: newStepIndex,
          currentLocation: currentLocation,
          distanceToNextStep: distanceToNextStep,
          etaSeconds: etaSeconds,
          remainingDistance: remainingDistance,
        )
        .catchError((e) {
      debugPrint('Warning: No se pudo actualizar progreso en Supabase: $e');
      return null;
    });

    // 7. Calcular distancia recorrida
    final distanceTraveled =
        currentSession.totalDistanceMeters - remainingDistance;

    // 8. Calcular tiempo transcurrido
    final elapsedTime = DateTime.now().difference(currentSession.startTime);

    // 9. Retornar sesión actualizada (siempre, independiente de Supabase)
    return currentSession.copyWith(
      currentStepIndex: newStepIndex,
      distanceTraveledMeters: distanceTraveled > 0 ? distanceTraveled : 0,
      elapsedTime: elapsedTime,
    );
  }
}
