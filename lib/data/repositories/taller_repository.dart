/// TallerRepository — Interfaz abstracta
///
/// Define el contrato para operaciones sobre talleres.
/// La implementación concreta se encuentra en impl/taller_repository_impl.dart.
library;

import '../models/taller_model.dart';

/// Clase auxiliar que agrupa un taller con el nombre de su creador.
class TallerConCreadorData {
  final TallerModel taller;
  final String nombreCreador;

  const TallerConCreadorData({
    required this.taller,
    required this.nombreCreador,
  });
}

abstract class TallerRepository {
  /// Obtiene el ID del usuario autenticado actual.
  String? getCurrentUserId();

  /// Carga la lista de talleres con el nombre de su creador.
  Future<List<TallerConCreadorData>> getTalleres();

  /// Crea un nuevo taller.
  Future<void> createTaller({
    required TallerModel taller,
    required String userId,
  });

  /// Actualiza un taller existente.
  Future<void> updateTaller({
    required String tallerId,
    required TallerModel taller,
  });

  /// Elimina un taller.
  Future<void> deleteTaller(String tallerId);

  /// Comparte un taller en la comunidad.
  Future<void> shareTallerToCommunity({
    required String userId,
    required TallerModel taller,
    String? message,
  });

  /// Obtiene el nombre de un usuario por su ID.
  Future<String?> getNombreUsuario(String userId);
}
