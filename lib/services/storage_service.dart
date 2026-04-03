import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Servicio para gestionar la subida y eliminación de archivos en Supabase Storage
///
/// Responsabilidades:
/// - Subir avatares de usuario al bucket 'avatars'
/// - Eliminar avatares antiguos
/// - Obtener URLs públicas de los archivos
class StorageService {
  // ========================================
  // CLIENTE SUPABASE
  // ========================================

  /// Cliente de Supabase - Getter para evaluación perezosa
  SupabaseClient get _supabase => SupabaseConfig.client;

  // ========================================
  // CONSTANTES
  // ========================================

  static const String _avatarsBucket = 'avatars';
  static const String _communityMediaBucket = 'community-media';
  static const String _avatarFileName = 'avatar.jpg';
  static const int _maxFileSizeInBytes = 5 * 1024 * 1024; // 5 MB
  static const int _maxVideoSizeInBytes = 50 * 1024 * 1024; // 50 MB para videos

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  /// Sube un avatar para el usuario actual
  ///
  /// [imageFile] - Archivo de imagen a subir
  /// [userId] - ID del usuario (debe coincidir con el usuario autenticado)
  ///
  /// Retorna:
  /// - String con la URL pública del avatar subido
  ///
  /// Lanza:
  /// - Exception si el archivo es muy grande
  /// - Exception si falla la subida
  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Verificar tamaño del archivo
      final fileSize = await imageFile.length();
      if (fileSize > _maxFileSizeInBytes) {
        throw Exception(
          'El archivo es demasiado grande. Máximo permitido: ${_maxFileSizeInBytes ~/ (1024 * 1024)} MB',
        );
      }

      // Leer los bytes del archivo
      final bytes = await imageFile.readAsBytes();

      // Ruta del archivo en el bucket: avatars/{userId}/avatar.jpg
      final filePath = '$userId/$_avatarFileName';

      // Verificar si ya existe un avatar y eliminarlo
      try {
        await _supabase.storage.from(_avatarsBucket).remove([filePath]);
      } catch (e) {
        // Si no existe el archivo, no hay problema
        print('No hay avatar anterior para eliminar (esto es normal): $e');
      }

      // Subir el nuevo avatar
      await _supabase.storage
          .from(_avatarsBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true, // Sobrescribe si existe
            ),
          );

      // Obtener la URL pública
      final publicUrl = _supabase.storage
          .from(_avatarsBucket)
          .getPublicUrl(filePath);

      // Agregar timestamp para evitar caché
      final urlWithTimestamp =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      return urlWithTimestamp;
    } catch (e) {
      print('Error al subir avatar: $e');
      throw Exception('Error al subir la imagen: ${e.toString()}');
    }
  }

  /// Elimina el avatar del usuario
  ///
  /// [userId] - ID del usuario
  ///
  /// Retorna:
  /// - true si se eliminó exitosamente
  /// - false si hubo un error
  Future<bool> deleteAvatar({required String userId}) async {
    try {
      final filePath = '$userId/$_avatarFileName';
      await _supabase.storage.from(_avatarsBucket).remove([filePath]);
      return true;
    } catch (e) {
      print('Error al eliminar avatar: $e');
      return false;
    }
  }

  /// Obtiene la URL pública del avatar del usuario
  ///
  /// [userId] - ID del usuario
  ///
  /// Retorna:
  /// - String con la URL pública del avatar
  /// - null si no hay avatar
  String? getAvatarUrl({required String userId}) {
    try {
      final filePath = '$userId/$_avatarFileName';
      final publicUrl = _supabase.storage
          .from(_avatarsBucket)
          .getPublicUrl(filePath);
      // Agregar timestamp para evitar caché
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error al obtener URL del avatar: $e');
      return null;
    }
  }

  /// Verifica si el usuario tiene un avatar
  ///
  /// [userId] - ID del usuario
  ///
  /// Retorna:
  /// - true si existe un avatar
  /// - false si no existe
  Future<bool> hasAvatar({required String userId}) async {
    try {
      final files = await _supabase.storage
          .from(_avatarsBucket)
          .list(path: userId);
      return files.any((file) => file.name == _avatarFileName);
    } catch (e) {
      print('Error al verificar avatar: $e');
      return false;
    }
  }

  // ========================================
  // MÉTODOS PARA MEDIA DE COMUNIDAD
  // ========================================

  /// Sube una imagen o video para una publicación de comunidad
  ///
  /// [mediaFile] - Archivo de imagen o video a subir
  /// [userId] - ID del usuario que sube el archivo
  /// [postId] - ID único de la publicación (usar timestamp o UUID)
  /// [isVideo] - true si es un video, false si es imagen
  ///
  /// Retorna:
  /// - String con la URL pública del archivo subido
  ///
  /// Lanza:
  /// - Exception si el archivo es muy grande
  /// - Exception si falla la subida
  Future<String> uploadCommunityMedia({
    required File mediaFile,
    required String userId,
    required String postId,
    required bool isVideo,
  }) async {
    try {
      // Verificar tamaño del archivo
      final fileSize = await mediaFile.length();
      final maxSize = isVideo ? _maxVideoSizeInBytes : _maxFileSizeInBytes;

      if (fileSize > maxSize) {
        throw Exception(
          'El archivo es demasiado grande. Máximo permitido: ${maxSize ~/ (1024 * 1024)} MB',
        );
      }

      // Leer los bytes del archivo
      final bytes = await mediaFile.readAsBytes();

      // Obtener extensión del archivo
      final extension = mediaFile.path.split('.').last.toLowerCase();

      // Ruta del archivo en el bucket: community-media/{userId}/{postId}.{extension}
      final filePath = '$userId/$postId.$extension';

      // Determinar content type
      String contentType;
      if (isVideo) {
        if (extension == 'mp4') {
          contentType = 'video/mp4';
        } else if (extension == 'mov') {
          contentType = 'video/quicktime';
        } else {
          contentType = 'video/$extension';
        }
      } else {
        if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        } else if (extension == 'png') {
          contentType = 'image/png';
        } else {
          contentType = 'image/$extension';
        }
      }

      // Subir el archivo
      await _supabase.storage
          .from(_communityMediaBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false, // No sobrescribir
            ),
          );

      // Obtener la URL pública
      final publicUrl = _supabase.storage
          .from(_communityMediaBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('Error al subir media de comunidad: $e');
      throw Exception('Error al subir el archivo: ${e.toString()}');
    }
  }

  /// Elimina un archivo de media de una publicación de comunidad
  ///
  /// [mediaUrl] - URL pública del archivo a eliminar
  ///
  /// Retorna:
  /// - true si se eliminó exitosamente
  /// - false si hubo un error
  Future<bool> deleteCommunityMedia({required String mediaUrl}) async {
    try {
      // Extraer el path del archivo desde la URL
      // URL típica: https://xxx.supabase.co/storage/v1/object/public/community-media/{userId}/{postId}.ext
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;

      // Encontrar el índice donde está 'community-media'
      final bucketIndex = pathSegments.indexOf(_communityMediaBucket);
      if (bucketIndex == -1) {
        throw Exception('URL inválida para media de comunidad');
      }

      // El path es todo lo que viene después del bucket
      final filePath = pathSegments.skip(bucketIndex + 1).join('/');

      await _supabase.storage.from(_communityMediaBucket).remove([filePath]);
      return true;
    } catch (e) {
      print('Error al eliminar media de comunidad: $e');
      return false;
    }
  }

  /// Elimina todos los archivos de media de un usuario
  ///
  /// [userId] - ID del usuario
  ///
  /// Retorna:
  /// - Número de archivos eliminados
  Future<int> deleteAllUserCommunityMedia({required String userId}) async {
    try {
      // Listar todos los archivos del usuario
      final files = await _supabase.storage
          .from(_communityMediaBucket)
          .list(path: userId);

      if (files.isEmpty) return 0;

      // Crear lista de paths a eliminar
      final filePaths = files.map((file) => '$userId/${file.name}').toList();

      // Eliminar todos
      await _supabase.storage.from(_communityMediaBucket).remove(filePaths);

      return filePaths.length;
    } catch (e) {
      print('Error al eliminar media del usuario: $e');
      return 0;
    }
  }
}
