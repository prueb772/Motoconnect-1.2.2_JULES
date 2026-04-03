/// Caso de Uso: Finalizar Navegación
///
/// Responsabilidades:
/// - Finalizar sesión en Supabase
/// - Detener tracking de ubicación
/// - Limpiar progreso en tiempo real
library;

import '../../../data/models/navigation_session.dart';
import '../../../data/repositories/navigation_repository.dart';
import '../../../services/location_tracking_service.dart';

class EndNavigationUseCase {
  final NavigationRepository _repository;
  final LocationTrackingService _locationService;

  EndNavigationUseCase({
    required NavigationRepository repository,
    required LocationTrackingService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  /// Ejecuta el caso de uso
  ///
  /// [sessionId] - ID de la sesión
  /// [completed] - true si llegó al destino, false si canceló
  Future<void> execute({
    required String sessionId,
    required bool completed,
  }) async {
    try {
      // Finalizar en Supabase
      await _repository.endNavigation(
        sessionId: sessionId,
        status: completed
            ? NavigationStatus.completed
            : NavigationStatus.cancelled,
      );

      // Eliminar progreso en tiempo real
      await _repository.deleteUserProgress(sessionId);

      // Detener tracking de ubicación
      await _locationService.detenerTracking();
    } catch (e) {
      throw Exception('Error al finalizar navegación: ${e.toString()}');
    }
  }
}
