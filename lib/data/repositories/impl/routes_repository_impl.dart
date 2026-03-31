/// RoutesRepositoryImpl — Implementación concreta con Supabase
///
/// Implementa [RoutesRepository] usando Supabase como fuente de datos.
/// Esta es la ÚNICA clase del módulo Routes que conoce Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../models/ruta_realizada_model.dart';
import '../routes_repository.dart';

class RoutesRepositoryImpl implements RoutesRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  @override
  String? getCurrentUserId() => _supabase.auth.currentUser?.id;

  @override
  Future<void> saveRoute(RutaRealizadaModel route) async {
    final insertData = route.toJson()..remove('id');
    await _supabase.from('rutas_realizadas').insert(insertData);
  }

  @override
  Future<RutaRealizadaModel> getRouteById(String routeId) async {
    final respuesta = await _supabase
        .from('rutas_realizadas')
        .select()
        .eq('id', routeId)
        .single();

    return RutaRealizadaModel.fromJson(respuesta);
  }
}
