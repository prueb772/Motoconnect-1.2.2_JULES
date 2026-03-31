/// SavedRoutesRepositoryImpl — Implementación concreta con Supabase
///
/// Implementa [SavedRoutesRepository] usando Supabase como fuente de datos.
/// Esta es la ÚNICA clase del módulo SavedRoutes que conoce Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../models/ruta_realizada_model.dart';
import '../saved_routes_repository.dart';

class SavedRoutesRepositoryImpl implements SavedRoutesRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  @override
  String? getCurrentUserId() => _supabase.auth.currentUser?.id;

  @override
  Future<List<RutaRealizadaModel>> getSavedRoutes(String userId) async {
    final respuesta = await _supabase
        .from('rutas_realizadas')
        .select()
        .eq('usuario_id', userId)
        .order('fecha', ascending: false);

    return (respuesta as List)
        .map((json) => RutaRealizadaModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    await _supabase
        .from('rutas_realizadas')
        .delete()
        .eq('id', routeId);
  }

  @override
  Future<void> shareRouteToCommunity({
    required String userId,
    required RutaRealizadaModel route,
    String? message,
  }) async {
    final contenido = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : '¡Echen un vistazo a esta ruta que guardé: ${route.nombreRuta}!';

    await _supabase.from('comentarios_comunidad').insert({
      'usuario_id': userId,
      'contenido': contenido,
      'tipo': 'ruta_compartida',
      'referencia_ruta_id': route.id,
      'fecha': DateTime.now().toIso8601String(),
    });
  }
}
