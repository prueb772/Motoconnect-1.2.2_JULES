/// SavedRoutesRepository — Interfaz abstracta
///
/// Define el contrato para operaciones sobre rutas guardadas.
/// La implementación concreta se encuentra en impl/saved_routes_repository_impl.dart.
library;

import '../models/ruta_realizada_model.dart';

abstract class SavedRoutesRepository {
  /// Obtiene el ID del usuario autenticado actual.
  String? getCurrentUserId();

  /// Carga las rutas guardadas del usuario actual, ordenadas por fecha.
  Future<List<RutaRealizadaModel>> getSavedRoutes(String userId);

  /// Elimina una ruta guardada.
  Future<void> deleteRoute(String routeId);

  /// Comparte una ruta en la comunidad.
  Future<void> shareRouteToCommunity({
    required String userId,
    required RutaRealizadaModel route,
    String? message,
  });
}
