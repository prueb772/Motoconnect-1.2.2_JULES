/// CommunityRepository — Interfaz abstracta
///
/// Define el contrato para operaciones de la comunidad.
/// La implementación concreta se encuentra en impl/community_repository_impl.dart.
library;

import '../models/comentario_comunidad_model.dart';
import '../models/event_model.dart';
import '../models/autor_info.dart';

abstract class CommunityRepository {
  /// Obtiene el ID del usuario autenticado actual.
  String? getCurrentUserId();

  /// Carga todas las publicaciones de la comunidad ordenadas por fecha.
  Future<List<ComentarioComunidadModel>> getPublicaciones();

  /// Obtiene datos de un usuario por su ID (nombre y foto de perfil).
  Future<AutorInfo> getDatosUsuario(String userId);

  /// Obtiene el nombre de una ruta compartida por su ID.
  Future<String?> getNombreRuta(String rutaId);

  /// Obtiene los datos de un evento compartido por su ID.
  Future<Event?> getEventoCompartido(String eventoId);

  /// Crea una publicación de texto.
  Future<void> createTextPost({
    required String userId,
    required String content,
  });

  /// Crea una publicación con media (imagen o video).
  Future<void> createMediaPost({
    required String userId,
    required String tipo,
    String? content,
    String? mediaUrl,
  });

  /// Edita el contenido de una publicación existente.
  Future<void> editPost({
    required String postId,
    required String userId,
    required String newContent,
  });

  /// Elimina una publicación.
  Future<void> deletePost({
    required String postId,
    required String userId,
  });
}
