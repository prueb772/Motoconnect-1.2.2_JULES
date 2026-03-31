/// Implementación concreta del Repository de Autenticación
///
/// Patrón Repository:
/// - Implementa la interfaz AuthRepository
/// - Delega operaciones al AuthApiService
/// - Facilita testing con mocks
///
/// Responsabilidades:
/// - Operaciones de autenticación (login, registro, logout)
/// - Gestión de sesión
/// - Comunicación con AuthApiService
library;

import '../../services/api/auth_api_service.dart';
import '../../models/user_model.dart';
import '../auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  /// Servicio de API de autenticación
  final AuthApiService _apiService;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  /// Constructor con inyección de dependencias
  ///
  /// [apiService] - Servicio para llamadas a API de autenticación
  AuthRepositoryImpl({AuthApiService? apiService})
    : _apiService = apiService ?? AuthApiService();

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  @override
  Stream<UserModel?> get onAuthStateChange => _apiService.onAuthStateChange;

  @override
  Future<bool> isAuthenticated() async {
    try {
      final user = await _apiService.getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _apiService.signIn(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      return await _apiService.signUp(
        email: email,
        password: password,
        nombre: nombre,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _apiService.signOut();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      return await _apiService.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _apiService.resetPassword(email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _apiService.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      return await _apiService.signInWithGoogle();
    } catch (e) {
      rethrow;
    }
  }
}
