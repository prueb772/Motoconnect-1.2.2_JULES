/// ProfileRepositoryImpl — Implementación concreta con Supabase
///
/// Implementa [ProfileRepository] usando Supabase como fuente de datos.
/// Esta es la ÚNICA clase del módulo Profile que conoce Supabase.
library;

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../models/user_metadata.dart';
import '../profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    StorageService? storageService,
  }) : _storageService = storageService ?? StorageService();

  SupabaseClient get _supabase => SupabaseConfig.client;
  final StorageService _storageService;

  @override
  String? getCurrentUserId() => _supabase.auth.currentUser?.id;

  @override
  String? getCurrentUserEmail() => _supabase.auth.currentUser?.email;

  @override
  UserMetadata? getCurrentUserMetadata() {
    final raw = _supabase.auth.currentUser?.userMetadata;
    if (raw == null) return null;
    return UserMetadata.fromJson(raw);
  }

  @override
  Future<UserModel?> getProfile(String userId) async {
    final respuesta = await _supabase
        .from('usuarios')
        .select('id, correo, nombre, modelo_moto, foto_perfil_url, apodo')
        .eq('id', userId)
        .maybeSingle();

    if (respuesta == null) return null;
    return UserModel.fromJson(respuesta);
  }

  @override
  Future<void> createProfile(UserModel user) async {
    await _supabase.from('usuarios').insert(user.toJson());
  }

  @override
  Future<void> updateProfile(UserModel user) async {
    await _supabase.from('usuarios').upsert(user.toJson());
  }

  @override
  Future<String?> getAvatarUrl(String userId) async {
    final respuesta = await _supabase
        .from('usuarios')
        .select('foto_perfil_url')
        .eq('id', userId)
        .maybeSingle();

    return respuesta?['foto_perfil_url'] as String?;
  }

  @override
  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  }) async {
    // Subir imagen a Storage
    final url = await _storageService.uploadAvatar(
      imageFile: imageFile,
      userId: userId,
    );

    // Actualizar la URL en la tabla usuarios
    await _supabase
        .from('usuarios')
        .update({'foto_perfil_url': url})
        .eq('id', userId);

    return url;
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    // Eliminar de Storage
    await _storageService.deleteAvatar(userId: userId);

    // Limpiar la URL en la tabla usuarios
    await _supabase
        .from('usuarios')
        .update({'foto_perfil_url': null})
        .eq('id', userId);
  }
}
