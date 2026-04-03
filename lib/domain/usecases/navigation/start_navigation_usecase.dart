/// Caso de Uso: Iniciar Navegación
///
/// Responsabilidades:
/// - Obtener ubicación actual
/// - Llamar a Google Directions API
/// - Parsear pasos de navegación
/// - Crear sesión en Supabase
/// - Retornar NavigationSession lista para usar
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/navigation_session.dart';
import '../../../data/services/navigation/google_directions_service.dart';
import '../../../data/repositories/navigation_repository.dart';
import '../../../services/location_tracking_service.dart';

class StartNavigationUseCase {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  final GoogleDirectionsService _directionsService;
  final NavigationRepository _navigationRepository;
  final LocationTrackingService _locationService;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  StartNavigationUseCase({
    required GoogleDirectionsService directionsService,
    required NavigationRepository navigationRepository,
    required LocationTrackingService locationService,
  })  : _directionsService = directionsService,
        _navigationRepository = navigationRepository,
        _locationService = locationService;

  // ========================================
  // MÉTODO PRINCIPAL
  // ========================================

  /// Ejecuta el caso de uso de iniciar navegación
  ///
  /// [destination] - Destino final
  /// [destinationName] - Nombre del destino (opcional)
  /// [sesionGrupalId] - ID de sesión grupal (null si es individual)
  /// [mode] - Modo de transporte ('driving', 'walking', 'bicycling')
  ///
  /// Retorna:
  /// - NavigationSession creada y lista para usar
  ///
  /// Lanza:
  /// - Exception si hay error en cualquier paso
  Future<NavigationSession> execute({
    required LatLng destination,
    String? destinationName,
    String? sesionGrupalId,
    String mode = 'driving',
  }) async {
    try {
      // 1. Obtener ubicación actual del usuario
      final currentLocation =
          await _locationService.obtenerUbicacionActualLatLng();

      // 2. Llamar a Google Directions API
      final directionsResponse = await _directionsService.getDirections(
        origin: currentLocation,
        destination: destination,
        mode: mode,
      );

      // 3. Validar respuesta
      if (!directionsResponse.isSuccess ||
          directionsResponse.routes.isEmpty) {
        throw Exception(
          'No se encontró ninguna ruta. '
          'Status: ${directionsResponse.status}',
        );
      }

      // 4. Extraer steps de navegación
      final steps = _directionsService.extractNavigationSteps(
        directionsResponse,
      );

      if (steps.isEmpty) {
        throw Exception('No se pudieron extraer pasos de navegación');
      }

      // 5. Extraer polyline completa
      final completePolyline = _directionsService.extractCompletePolyline(
        directionsResponse,
      );

      if (completePolyline.isEmpty) {
        throw Exception('No se pudo extraer polyline de la ruta');
      }

      // 6. Crear sesión en Supabase
      final session = await _navigationRepository.createNavigationSession(
        origin: currentLocation,
        destination: destination,
        destinationName: destinationName,
        sesionGrupalId: sesionGrupalId,
        steps: steps,
        completePolyline: completePolyline,
      );

      return session;
    } catch (e) {
      throw Exception('Error al iniciar navegación: ${e.toString()}');
    }
  }
}
