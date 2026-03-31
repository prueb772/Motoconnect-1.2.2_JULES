/// RoutesRepository — Interfaz abstracta
///
/// Define el contrato para operaciones sobre rutas realizadas.
/// La implementación concreta se encuentra en impl/routes_repository_impl.dart.
library;

import '../models/ruta_realizada_model.dart';

abstract class RoutesRepository {
  /// Obtiene el ID del usuario autenticado actual.
  String? getCurrentUserId();

  /// Guarda una nueva ruta realizada. Retorna la ruta guardada con ID asignado.
  Future<void> saveRoute(RutaRealizadaModel route);

  /// Carga una ruta por su ID.
  Future<RutaRealizadaModel> getRouteById(String routeId);
}
