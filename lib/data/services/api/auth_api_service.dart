/// Servicio de API de Autenticación
///
/// Capa más baja de abstracción - interactúa directamente con Supabase
///
/// Responsabilidades:
/// - Llamadas a Supabase Auth
/// - Conversión de respuestas a modelos
/// - Manejo de errores de API
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/api_constants.dart';
import '../../models/user_model.dart';

/// Excepción personalizada para errores de autenticación
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthApiService {
  // ========================================
  // CLIENTE SUPABASE
  // ========================================

  /// Cliente de Supabase - Getter para evaluación perezosa (lazy evaluation)
  /// Esto previene el error de acceso a Supabase antes de inicialización
  SupabaseClient get _supabase => SupabaseConfig.client;

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  /// Stream de cambios de estado de autenticación
  Stream<UserModel?> get onAuthStateChange {
    return _supabase.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        nombre: user.userMetadata?['nombre'] as String? ?? user.userMetadata?['full_name'] as String? ?? '',
      );
    });
  }

  /// Obtiene el usuario actual
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        nombre: user.userMetadata?['nombre'] as String? ?? '',
      );
    } catch (e) {
      throw AuthException('Error al obtener usuario actual');
    }
  }

  /// Inicia sesión
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Error al iniciar sesión');
      }

      return UserModel(
        id: response.user!.id,
        email: response.user!.email ?? '',
        nombre: response.user!.userMetadata?['nombre'] as String? ?? '',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_mapErrorMessage(e.toString()));
    }
  }

  /// Registra nuevo usuario
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': nombre},
      );

      if (response.user == null) {
        throw AuthException('Error al crear usuario');
      }

      // Crear el perfil del usuario en la tabla usuarios
      // Esto es un backup por si el trigger de Supabase falla
      try {
        await _supabase.from('usuarios').upsert({
          'id': response.user!.id,
          'correo': email,
          'nombre': nombre,
          'modelo_moto': null,
        });
      } catch (e) {
        // Si falla, el trigger debería haberlo creado
        // Log del error pero no fallar el registro
        print('Advertencia: No se pudo crear perfil inicial: $e');
      }

      return UserModel(
        id: response.user!.id,
        email: response.user!.email ?? '',
        nombre: nombre,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_mapErrorMessage(e.toString()));
    }
  }

  /// Cierra sesión
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw AuthException('Error al cerrar sesión');
    }
  }

  /// Envía correo de recuperación
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: ApiConstants.resetPasswordRedirectUrl,
      );
    } catch (e) {
      throw AuthException('Error al enviar correo de recuperación');
    }
  }

  /// Actualiza la contraseña del usuario autenticado
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw AuthException('Error al actualizar la contraseña');
    }
  }

  /// Inicia sesión con Google
  Future<UserModel> signInWithGoogle() async {
    try {
      // Configurar Google Sign In
      // Web Client ID de Google Cloud Console (para Supabase)
      const webClientId = SupabaseConfig.googleWebClientId;

      // Inicializar Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      // 1. Realizar el sign in con Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException('Inicio de sesión cancelado');
      }

      // 2. Obtener los tokens de autenticación
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw AuthException('Error al obtener tokens de Google');
      }

      // 3. Autenticar con Supabase usando los tokens de Google
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw AuthException('Error al iniciar sesión con Google');
      }

      // 4. Crear el modelo de usuario
      final user = response.user!;
      final nombre = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          googleUser.displayName ??
          '';

      // Crear el perfil del usuario en la tabla usuarios si es un nuevo usuario
      // Esto es un backup por si el trigger de Supabase falla
      try {
        await _supabase.from('usuarios').upsert({
          'id': user.id,
          'correo': user.email ?? '',
          'nombre': nombre,
          'modelo_moto': null,
        });
      } catch (e) {
        // Si falla, el trigger debería haberlo creado o el usuario ya existe
        // Log del error pero no fallar el login
        print('Advertencia: No se pudo crear/actualizar perfil: $e');
      }

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        nombre: nombre,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_mapErrorMessage(e.toString()));
    }
  }

  // ========================================
  // MÉTODOS PRIVADOS
  // ========================================

  /// Mapea mensajes de error a español
  String _mapErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    } else if (error.contains('Email not confirmed')) {
      return 'Por favor confirma tu correo electrónico';
    } else if (error.contains('User already registered')) {
      return 'Este correo ya está registrado';
    } else if (error.contains('Password')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return 'Error de autenticación';
  }
}
