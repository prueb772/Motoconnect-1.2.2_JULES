/// Caso de Uso: Reanudar Navegación
///
/// Responsabilidades:
/// - Reanudar sesión en Supabase
/// - Reanudar tracking de ubicación
library;

import '../../../data/repositories/navigation_repository.dart';
import '../../../services/location_tracking_service.dart';

class ResumeNavigationUseCase {
  final NavigationRepository _repository;
  final LocationTrackingService _locationService;

  ResumeNavigationUseCase({
    required NavigationRepository repository,
    required LocationTrackingService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  Future<void> execute(String sessionId) async {
    try {
      // Reanudar en Supabase
      await _repository.resumeNavigation(sessionId);

      // Reanudar tracking de ubicación
      _locationService.reanudarTracking();
    } catch (e) {
      throw Exception('Error al reanudar navegación: ${e.toString()}');
    }
  }
}
