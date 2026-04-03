/// Interfaz abstracta del Repository de Autenticación
///
/// Define el contrato para operaciones de autenticación.
/// La implementación concreta está en impl/auth_repository_impl.dart.
///
/// Patrón: Clean Architecture — interfaz en data/repositories/,
/// implementación en data/repositories/impl/
library;

import '../models/user_model.dart';

abstract class AuthRepository {
  /// Stream de cambios de estado de autenticación
  Stream<UserModel?> get onAuthStateChange;

  /// Verifica si hay un usuario autenticado
  Future<bool> isAuthenticated();

  /// Inicia sesión con email y contraseña
  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  /// Registra un nuevo usuario
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String nombre,
  });

  /// Cierra la sesión del usuario actual
  Future<void> signOut();

  /// Obtiene el usuario actual (null si no hay sesión activa)
  Future<UserModel?> getCurrentUser();

  /// Envía correo de recuperación de contraseña
  Future<void> resetPassword(String email);

  /// Actualiza la contraseña del usuario autenticado
  Future<void> updatePassword(String newPassword);

  /// Inicia sesión con Google
  Future<UserModel> signInWithGoogle();
}
