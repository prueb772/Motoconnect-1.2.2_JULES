/// TallerRepositoryImpl — Implementación concreta con Supabase
///
/// Implementa [TallerRepository] usando Supabase como fuente de datos.
/// Esta es la ÚNICA clase del módulo Talleres que conoce Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../models/taller_model.dart';
import '../taller_repository.dart';

class TallerRepositoryImpl implements TallerRepository {
  SupabaseClient get _supabase => SupabaseConfig.client;

  @override
  String? getCurrentUserId() => _supabase.auth.currentUser?.id;

  @override
  Future<List<TallerConCreadorData>> getTalleres() async {
    final respuesta = await _supabase
        .from('talleres')
        .select('*, usuarios(nombre)')
        .order('nombre', ascending: true);

    final List<TallerConCreadorData> result = [];

    for (final tallerMap in respuesta) {
      String? nombreCreador;

      // Intentar obtener nombre del creador desde el join
      if (tallerMap['usuarios'] != null &&
          tallerMap['usuarios']['nombre'] != null) {
        nombreCreador = tallerMap['usuarios']['nombre'] as String;
      } else if (tallerMap['creado_por'] != null) {
        nombreCreador = await getNombreUsuario(
          tallerMap['creado_por'] as String,
        );
      }

      final taller = TallerModel.fromJson(tallerMap);
      result.add(TallerConCreadorData(
        taller: taller,
        nombreCreador: nombreCreador ?? 'N/A',
      ));
    }

    return result;
  }

  @override
  Future<void> createTaller({
    required TallerModel taller,
    required String userId,
  }) async {
    await _supabase.from('talleres').insert({
      'nombre': taller.nombre,
      'direccion': taller.direccion,
      'telefono': taller.telefono,
      'horario': taller.horario,
      'latitud': taller.latitud,
      'longitud': taller.longitud,
      'creado_por': userId,
    });
  }

  @override
  Future<void> updateTaller({
    required String tallerId,
    required TallerModel taller,
  }) async {
    await _supabase.from('talleres').update({
      'nombre': taller.nombre,
      'direccion': taller.direccion,
      'telefono': taller.telefono,
      'horario': taller.horario,
      'latitud': taller.latitud,
      'longitud': taller.longitud,
    }).eq('id', tallerId);
  }

  @override
  Future<void> deleteTaller(String tallerId) async {
    await _supabase.from('talleres').delete().eq('id', tallerId);
  }

  @override
  Future<void> shareTallerToCommunity({
    required String userId,
    required TallerModel taller,
    String? message,
  }) async {
    String contenido =
        message?.trim().isNotEmpty == true ? message!.trim() : '';

    contenido += '\n\n¡Revisen este taller!: ${taller.nombre}';

    if (taller.direccion != null && taller.direccion!.isNotEmpty) {
      contenido += '\nDirección: ${taller.direccion}';
    }
    if (taller.telefono != null && taller.telefono!.isNotEmpty) {
      contenido += '\nTeléfono: ${taller.telefono}';
    }
    if (taller.horario != null && taller.horario!.isNotEmpty) {
      contenido += '\nHorario: ${taller.horario}';
    }

    await _supabase.from('comentarios_comunidad').insert({
      'usuario_id': userId,
      'contenido': contenido,
      'tipo': 'taller_compartido',
      'referencia_taller_id': taller.id,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<String?> getNombreUsuario(String userId) async {
    try {
      final respuesta = await _supabase
          .from('usuarios')
          .select('nombre')
          .eq('id', userId)
          .single();
      return respuesta['nombre'] as String?;
    } catch (_) {
      return 'Desconocido';
    }
  }
}
