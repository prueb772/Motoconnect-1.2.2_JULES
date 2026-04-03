// ============================================================================
// ARCHIVO 2: lib/core/constants/route_constants.dart
// ============================================================================

/// Constantes de rutas de navegación
///
/// Centraliza todos los nombres de rutas para evitar strings mágicos
/// y facilitar el mantenimiento.
///
/// Uso:
/// ```dart
/// Navigator.pushNamed(context, RouteConstants.home);
/// ```
library;

class RouteConstants {
  // Constructor privado para prevenir instanciación
  RouteConstants._();

  // ========================================
  // AUTENTICACIÓN
  // ========================================

  /// Pantalla de splash (carga inicial)
  static const String splash = '/splash';

  /// Pantalla de inicio de sesión
  static const String login = '/login';

  /// Pantalla de registro
  static const String register = '/register';

  /// Pantalla de recuperación de contraseña
  static const String forgotPassword = '/forgot-password';

  // ========================================
  // PRINCIPAL
  // ========================================

  /// Pantalla principal (home)
  static const String home = '/home';

  /// Pantalla de perfil de usuario
  static const String profile = '/profile';

  // ========================================
  // RUTAS
  // ========================================

  /// Pantalla de rutas (mapa)
  static const String routes = '/routes';

  /// Pantalla de rutas guardadas
  static const String savedRoutes = '/saved-routes';

  /// Selector de ubicación en mapa
  static const String mapPicker = '/map-picker';

  // ========================================
  // EVENTOS
  // ========================================

  /// Pantalla de eventos
  static const String events = '/events';

  /// Detalle de un evento
  static const String eventDetail = '/event-detail';

  /// Crear nuevo evento
  static const String createEvent = '/create-event';

  // ========================================
  // TALLERES
  // ========================================

  /// Pantalla de talleres
  static const String talleres = '/talleres';

  // ========================================
  // COMUNIDAD
  // ========================================

  /// Pantalla de comunidad
  static const String community = '/community';
}
