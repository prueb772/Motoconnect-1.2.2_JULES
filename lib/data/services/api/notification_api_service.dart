import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/api_constants.dart';

/// Servicio para gestionar tokens FCM en Supabase.
///
/// Responsabilidades:
/// - Registrar/actualizar el token FCM del dispositivo actual
/// - Eliminar el token al cerrar sesión
class NotificationApiService {
  final SupabaseClient _supabase;

  NotificationApiService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Guarda o actualiza el token FCM del usuario en Supabase.
  ///
  /// Usa upsert por (usuario_id, token) para evitar duplicados.
  Future<void> saveToken({
    required String userId,
    required String token,
  }) async {
    await _supabase.from(ApiConstants.fcmTokensTable).upsert(
      {
        'usuario_id': userId,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'usuario_id, token',
    );
  }

  /// Elimina el token FCM del usuario (usar al cerrar sesión).
  Future<void> deleteToken({
    required String userId,
    required String token,
  }) async {
    await _supabase
        .from(ApiConstants.fcmTokensTable)
        .delete()
        .eq('usuario_id', userId)
        .eq('token', token);
  }
}
