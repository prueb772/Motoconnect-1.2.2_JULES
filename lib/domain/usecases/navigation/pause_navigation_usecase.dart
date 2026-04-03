/// Caso de Uso: Pausar Navegación
///
/// Responsabilidades:
/// - Pausar sesión en Supabase
/// - Pausar tracking de ubicación
library;

import '../../../data/repositories/navigation_repository.dart';
import '../../../services/location_tracking_service.dart';

class PauseNavigationUseCase {
  final NavigationRepository _repository;
  final LocationTrackingService _locationService;

  PauseNavigationUseCase({
    required NavigationRepository repository,
    required LocationTrackingService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  Future<void> execute(String sessionId) async {
    try {
      // Pausar en Supabase
      await _repository.pauseNavigation(sessionId);

      // Pausar tracking de ubicación
      _locationService.pausarTracking();
    } catch (e) {
      throw Exception('Error al pausar navegación: ${e.toString()}');
    }
  }
}
