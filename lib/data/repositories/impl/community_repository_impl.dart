/// CommunityRepositoryImpl — Implementación concreta con Supabase
///
/// Implementa [CommunityRepository] usando Supabase como fuente de datos.
/// Esta es la ÚNICA clase del módulo Community que conoce Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../models/comentario_comunidad_model.dart';
import '../../models/event_model.dart';
import '../../models/autor_info.dart';
import '../community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  @override
  String? getCurrentUserId() => _supabase.auth.currentUser?.id;

  @override
  Future<List<ComentarioComunidadModel>> getPublicaciones() async {
    final respuesta = await _supabase
        .from('comentarios_comunidad')
        .select()
        .order('fecha', ascending: false);

    return (respuesta as List)
        .map((json) => ComentarioComunidadModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AutorInfo> getDatosUsuario(String userId) async {
    try {
      final respuesta = await _supabase
          .from('usuarios')
          .select('nombre, foto_perfil_url')
          .eq('id', userId)
          .single();

      return AutorInfo(
        nombre: respuesta['nombre'] as String?,
        fotoPerfilUrl: respuesta['foto_perfil_url'] as String?,
      );
    } catch (_) {
      return const AutorInfo(nombre: 'Usuario Anónimo', fotoPerfilUrl: null);
    }
  }

  @override
  Future<String?> getNombreRuta(String rutaId) async {
    try {
      final rutaRes = await _supabase
          .from('rutas_realizadas')
          .select('nombre_ruta')
          .eq('id', rutaId)
          .single();
      return rutaRes['nombre_ruta'] as String?;
    } catch (_) {
      return 'Ruta eliminada o no encontrada';
    }
  }

  @override
  Future<Event?> getEventoCompartido(String eventoId) async {
    try {
      final eventoRes = await _supabase
          .from('eventos')
          .select()
          .eq('id', eventoId)
          .single();
      return Event.fromJson(eventoRes);
    } catch (_) {
      return Event(
        id: eventoId,
        title: 'Evento no disponible',
        description: 'Este evento pudo haber sido eliminado.',
        date: DateTime.now(),
      );
    }
  }

  @override
  Future<void> createTextPost({
    required String userId,
    required String content,
  }) async {
    await _supabase.from('comentarios_comunidad').insert({
      'usuario_id': userId,
      'contenido': content,
      'tipo': 'texto',
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> createMediaPost({
    required String userId,
    required String tipo,
    String? content,
    String? mediaUrl,
  }) async {
    await _supabase.from('comentarios_comunidad').insert({
      'usuario_id': userId,
      'contenido': content,
      'tipo': tipo,
      'media_url': mediaUrl,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> editPost({
    required String postId,
    required String userId,
    required String newContent,
  }) async {
    await _supabase
        .from('comentarios_comunidad')
        .update({'contenido': newContent})
        .eq('id', postId)
        .eq('usuario_id', userId);
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    await _supabase
        .from('comentarios_comunidad')
        .delete()
        .eq('id', postId)
        .eq('usuario_id', userId);
  }
}
