/// Caso de Uso: Recalcular Ruta
///
/// Responsabilidades:
/// - Obtener ubicación actual
/// - Calcular nueva ruta desde ubicación actual
/// - Actualizar sesión con nuevos steps
/// - Retornar sesión actualizada
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/navigation_session.dart';
import '../../../data/services/navigation/google_directions_service.dart';
import '../../../services/location_tracking_service.dart';

class RecalculateRouteUseCase {
  final GoogleDirectionsService _directionsService;
  final LocationTrackingService _locationService;

  RecalculateRouteUseCase({
    required GoogleDirectionsService directionsService,
    required LocationTrackingService locationService,
  })  : _directionsService = directionsService,
        _locationService = locationService;

  /// Ejecuta la recalculación de ruta
  ///
  /// [currentSession] - Sesión actual
  /// [currentLocation] - Posición actual ya conocida. Si se provee, se omite
  ///   la lectura GPS redundante (ahorra 1-3s). Si es null, se obtiene del sistema.
  ///
  /// Retorna:
  /// - NavigationSession con ruta recalculada
  Future<NavigationSession> execute({
    required NavigationSession currentSession,
    LatLng? currentLocation,
  }) async {
    try {
      // 1. Usar ubicación provista o, como fallback, obtener una nueva lectura GPS
      currentLocation ??=
          await _locationService.obtenerUbicacionActualLatLng();

      // 2. Llamar a Google Directions API con nueva ruta
      final directionsResponse =
          await _directionsService.recalculateRoute(
        currentLocation: currentLocation,
        destination: currentSession.destination,
      );

      // 3. Validar respuesta
      if (!directionsResponse.isSuccess) {
        throw Exception('No se pudo recalcular la ruta');
      }

      // 4. Extraer nuevos steps
      final newSteps = _directionsService.extractNavigationSteps(
        directionsResponse,
      );

      // 5. Extraer nueva polyline
      final newPolyline = _directionsService.extractCompletePolyline(
        directionsResponse,
      );

      // 6. Calcular nuevos totales
      final newTotalDistance = _directionsService.getTotalDistance(
        directionsResponse,
      );

      final newTotalDuration = _directionsService.getTotalDuration(
        directionsResponse,
      );

      // 7. Retornar sesión actualizada
      return currentSession.copyWith(
        steps: newSteps,
        completePolyline: newPolyline,
        totalDistanceMeters: newTotalDistance,
        totalDurationSeconds: newTotalDuration,
        currentStepIndex: 0, // Reiniciar al primer paso
        status: NavigationStatus.navigating, // Volver a navegando
      );
    } catch (e) {
      throw Exception('Error al recalcular ruta: ${e.toString()}');
    }
  }
}
