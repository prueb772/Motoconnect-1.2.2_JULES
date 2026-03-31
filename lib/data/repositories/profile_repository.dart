/// ProfileRepository — Interfaz abstracta
///
/// Define el contrato para operaciones sobre el perfil del usuario.
/// La implementación concreta se encuentra en impl/profile_repository_impl.dart.
library;

import 'dart:io';
import '../models/user_model.dart';
import '../models/user_metadata.dart';

abstract class ProfileRepository {
  /// Obtiene el ID del usuario autenticado actual.
  /// Retorna null si no hay sesión activa.
  String? getCurrentUserId();

  /// Obtiene el correo del usuario autenticado actual.
  String? getCurrentUserEmail();

  /// Obtiene los metadatos del usuario autenticado (nombre, full_name, etc.)
  UserMetadata? getCurrentUserMetadata();

  /// Obtiene el perfil del usuario desde la tabla `usuarios`.
  /// Retorna null si el perfil no existe.
  Future<UserModel?> getProfile(String userId);

  /// Crea un perfil inicial para un usuario nuevo.
  Future<void> createProfile(UserModel user);

  /// Actualiza el perfil del usuario (upsert).
  Future<void> updateProfile(UserModel user);

  /// Obtiene la URL de la foto de perfil del usuario.
  Future<String?> getAvatarUrl(String userId);

  /// Sube una foto de perfil y actualiza la URL en la tabla `usuarios`.
  /// Retorna la URL pública de la imagen subida.
  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  });

  /// Elimina la foto de perfil y limpia la URL en la tabla `usuarios`.
  Future<void> deleteAvatar(String userId);
}
