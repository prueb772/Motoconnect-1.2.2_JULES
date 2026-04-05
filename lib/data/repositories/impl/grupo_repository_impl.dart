/// Implementación concreta del Repository de Grupos
///
/// Implementa GrupoRepository usando Supabase como backend.
///
/// Patrón Repository (Clean Architecture):
/// - Implementa la interfaz abstracta GrupoRepository
/// - Accede directamente a Supabase
/// - Es instanciada solo en composition roots (BlocProviders)
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/grupo_ruta_model.dart';
import '../../models/miembro_grupo_model.dart';
import '../../models/sesion_ruta_activa_model.dart';
import '../../models/ubicacion_tiempo_real_model.dart';
import '../../models/participante_sesion_model.dart';
import '../../models/ruta_sesion_model.dart';
import '../../models/ruta_compartida_model.dart';
import '../../models/solicitud_grupo_model.dart';

import '../../models/usuario_bloqueado_grupo_model.dart';
import '../grupo_repository.dart';

class GrupoRepositoryImpl implements GrupoRepository {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  /// Cliente de Supabase
  final SupabaseClient _supabase;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  /// Constructor con inyección de dependencias
  GrupoRepositoryImpl({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  // ========================================
  // MÉTODOS DE GRUPOS
  // ========================================

  @override
  Future<GrupoRutaModel> crearGrupo({
    required String nombre,
    String? descripcion,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Generar código único de invitación
      final codigoInvitacion = await _generarCodigoUnico();

      final response = await _supabase.from('grupos_ruta').insert({
        'nombre': nombre,
        'descripcion': descripcion,
        'codigo_invitacion': codigoInvitacion,
        'creado_por': userId,
        'activo': true,
      }).select().single();

      return GrupoRutaModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear grupo: ${e.toString()}');
    }
  }

  @override
  Future<List<GrupoRutaModel>> obtenerMisGrupos() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Primero obtener los IDs de grupos donde es miembro
      final miembrosResponse = await _supabase
          .from('miembros_grupo')
          .select('grupo_id')
          .eq('usuario_id', userId);

      // Si no tiene grupos, retornar lista vacía
      if (miembrosResponse.isEmpty) {
        return [];
      }

      // Extraer los IDs de grupos
      final grupoIds = (miembrosResponse as List)
          .map((e) => e['grupo_id'] as String)
          .toList();

      // Obtener los grupos
      final response = await _supabase
          .from('grupos_ruta')
          .select()
          .inFilter('id', grupoIds);

      return (response as List)
          .map((json) => GrupoRutaModel.fromJson(json))
          .toList();
    } catch (e) {
      // Si no hay grupos, retornar lista vacía
      if (e.toString().contains('empty')) {
        return [];
      }
      throw Exception('Error al obtener grupos: ${e.toString()}');
    }
  }

  @override
  Future<GrupoRutaModel?> obtenerGrupo(String grupoId) async {
    try {
      final response = await _supabase
          .from('grupos_ruta')
          .select()
          .eq('id', grupoId)
          .single();

      return GrupoRutaModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GrupoRutaModel?> buscarGrupoPorCodigo(String codigo) async {
    try {
      final response = await _supabase
          .from('grupos_ruta')
          .select()
          .eq('codigo_invitacion', codigo.toUpperCase())
          .eq('activo', true)
          .single();

      return GrupoRutaModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> actualizarGrupo({
    required String grupoId,
    String? nombre,
    String? descripcion,
    bool? activo,
    String? fotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nombre != null) updates['nombre'] = nombre;
      if (descripcion != null) updates['descripcion'] = descripcion;
      if (activo != null) updates['activo'] = activo;
      if (fotoUrl != null) updates['foto_url'] = fotoUrl;

      if (updates.isEmpty) {
        throw Exception('No se proporcionaron campos para actualizar');
      }

      await _supabase.from('grupos_ruta').update(updates).eq('id', grupoId);

      debugPrint('✅ Grupo actualizado: $updates');
    } catch (e) {
      debugPrint('❌ Error al actualizar grupo: $e');
      throw Exception('Error al actualizar grupo: ${e.toString()}');
    }
  }

  @override
  Future<String> subirFotoGrupo({
    required String grupoId,
    required String imagePath,
  }) async {
    try {
      debugPrint('📤 Subiendo foto de grupo: $grupoId');

      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final extension = path.extension(imagePath);
      final fileName = '${grupoId}_${DateTime.now().millisecondsSinceEpoch}$extension';

      debugPrint('   Archivo: $fileName (${bytes.length} bytes)');

      // Subir a bucket 'grupos'
      await _supabase.storage.from('grupos').uploadBinary(fileName, bytes);

      // Obtener URL pública
      final url = _supabase.storage.from('grupos').getPublicUrl(fileName);

      debugPrint('✅ Foto de grupo subida: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error al subir foto de grupo: $e');
      throw Exception('Error al subir foto: ${e.toString()}');
    }
  }

  @override
  Future<void> eliminarGrupo(String grupoId) async {
    try {
      await _supabase.from('grupos_ruta').delete().eq('id', grupoId);
    } catch (e) {
      throw Exception('Error al eliminar grupo: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS DE MIEMBROS
  // ========================================

  @override
  Future<GrupoRutaModel> unirseAGrupo(String codigo) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Buscar el grupo por código
      final grupo = await buscarGrupoPorCodigo(codigo);
      if (grupo == null) {
        throw Exception('Código de invitación inválido');
      }

      // Verificar si ya es miembro
      final yaMiembro = await esMiembroDeGrupo(grupo.id);
      if (yaMiembro) {
        throw Exception('Ya eres miembro de este grupo');
      }

      // Agregar como miembro
      await _supabase.from('miembros_grupo').insert({
        'grupo_id': grupo.id,
        'usuario_id': userId,
        'es_admin': false,
      });

      return grupo;
    } catch (e) {
      throw Exception('Error al unirse al grupo: ${e.toString()}');
    }
  }

  @override
  Future<List<MiembroGrupoModel>> obtenerMiembrosGrupo(String grupoId) async {
    try {
      final response = await _supabase
          .from('miembros_grupo')
          .select('*, usuarios(*)')
          .eq('grupo_id', grupoId)
          .order('fecha_union');

      return (response as List)
          .map((json) => MiembroGrupoModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener miembros: ${e.toString()}');
    }
  }

  @override
  Future<bool> esMiembroDeGrupo(String grupoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('miembros_grupo')
          .select('id')
          .eq('grupo_id', grupoId)
          .eq('usuario_id', userId);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> esAdminDeGrupo(String grupoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('miembros_grupo')
          .select('es_admin')
          .eq('grupo_id', grupoId)
          .eq('usuario_id', userId)
          .single();

      return response['es_admin'] as bool;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> salirDeGrupo(String grupoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      await _supabase
          .from('miembros_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', userId);
    } catch (e) {
      throw Exception('Error al salir del grupo: ${e.toString()}');
    }
  }

  @override
  Future<void> eliminarMiembro(String grupoId, String usuarioId) async {
    try {
      await _supabase
          .from('miembros_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', usuarioId);
    } catch (e) {
      throw Exception('Error al eliminar miembro: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS DE SESIONES
  // ========================================

  @override
  Future<SesionRutaActivaModel> iniciarSesion({
    required String grupoId,
    required String nombreSesion,
    String? descripcion,
    String? rutaId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // VALIDACIÓN: Verificar si el usuario ya tiene una sesión activa
      final sesionExistente = await obtenerSesionActivaDelUsuario();
      if (sesionExistente != null) {
        throw Exception(
          'Ya tienes una sesión activa: "${sesionExistente.nombreSesion}". '
          'Por favor finalízala antes de crear una nueva.',
        );
      }

      // Crear sesión
      final response = await _supabase.from('sesiones_ruta_activa').insert({
        'grupo_id': grupoId,
        'ruta_id': rutaId,
        'nombre_sesion': nombreSesion,
        'descripcion': descripcion,
        'estado': 'activa',
        'iniciada_por': userId,
      }).select().single();

      final sesion = SesionRutaActivaModel.fromJson(response);

      // IMPORTANTE: Asegurar que el líder esté registrado como participante auto-aprobado
      await _supabase.from('participantes_sesion').upsert(
        {
          'sesion_id': sesion.id,
          'usuario_id': userId,
          'estado_aprobacion': 'aprobado',
          'fecha_aprobacion': DateTime.now().toIso8601String(),
          'aprobado_por': userId,
          'tracking_activo': true,
        },
        onConflict: 'sesion_id,usuario_id',
      );

      return sesion;
    } catch (e) {
      throw Exception('Error al iniciar sesión: ${e.toString()}');
    }
  }

  @override
  Future<List<SesionRutaActivaModel>> obtenerSesionesActivas(
    String grupoId,
  ) async {
    try {
      final response = await _supabase
          .from('sesiones_ruta_activa')
          .select()
          .eq('grupo_id', grupoId)
          .eq('estado', 'activa')
          .order('fecha_inicio', ascending: false);

      return (response as List)
          .map((json) => SesionRutaActivaModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<SesionRutaActivaModel?> obtenerSesionActivaDelUsuario() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('sesiones_ruta_activa')
          .select()
          .eq('iniciada_por', userId)
          .eq('estado', 'activa')
          .maybeSingle();

      if (response == null) return null;

      return SesionRutaActivaModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SesionRutaActivaModel?> obtenerSesion(String sesionId) async {
    try {
      final response = await _supabase
          .from('sesiones_ruta_activa')
          .select()
          .eq('id', sesionId)
          .single();

      return SesionRutaActivaModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> actualizarEstadoSesion({
    required String sesionId,
    required EstadoSesion estado,
  }) async {
    try {
      final updates = <String, dynamic>{
        'estado': estado.toStringValue(),
      };

      // Si se finaliza, agregar fecha de fin
      if (estado == EstadoSesion.finalizada) {
        updates['fecha_fin'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('sesiones_ruta_activa')
          .update(updates)
          .eq('id', sesionId);
    } catch (e) {
      throw Exception('Error al actualizar sesión: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizarSesion(String sesionId) async {
    await actualizarEstadoSesion(
      sesionId: sesionId,
      estado: EstadoSesion.finalizada,
    );
  }

  @override
  Stream<SesionRutaActivaModel?> streamEstadoSesion(String sesionId) {
    debugPrint('📡 Creando stream de estado para sesión: $sesionId');
    return _supabase
        .from('sesiones_ruta_activa')
        .stream(primaryKey: ['id'])
        .eq('id', sesionId)
        .map((data) {
          if (data.isEmpty) {
            debugPrint('⚠️ Stream de estado: sesión no encontrada o eliminada');
            return null;
          }
          final sesion = SesionRutaActivaModel.fromJson(data.first);
          debugPrint('📡 Stream de estado emitió: ${sesion.estado}');
          return sesion;
        });
  }

  // ========================================
  // MÉTODOS DE UBICACIONES EN TIEMPO REAL
  // ========================================

  @override
  Future<void> actualizarUbicacion({
    required String sesionId,
    required double latitud,
    required double longitud,
    double? velocidad,
    double? direccion,
    double? altitud,
    double? precisionMetros,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Insertar nueva ubicación
      await _supabase.from('ubicaciones_tiempo_real').insert({
        'sesion_id': sesionId,
        'usuario_id': userId,
        'latitud': latitud,
        'longitud': longitud,
        'velocidad': velocidad,
        'direccion': direccion,
        'altitud': altitud,
        'precision_metros': precisionMetros,
      });
    } catch (e) {
      throw Exception('Error al actualizar ubicación: ${e.toString()}');
    }
  }

  @override
  Future<List<UbicacionTiempoRealModel>> obtenerUbicacionesActuales(
    String sesionId,
  ) async {
    try {
      // Usar la vista que ya trae solo las ubicaciones más recientes
      final response = await _supabase
          .from('vista_ubicaciones_sesion_actual')
          .select()
          .eq('sesion_id', sesionId);

      return (response as List)
          .map((json) => UbicacionTiempoRealModel.fromJson(json))
          .toList();
    } catch (e) {
      // Si falla la vista, intentar con query manual
      try {
        return await _obtenerUbicacionesActualesManual(sesionId);
      } catch (e2) {
        return [];
      }
    }
  }

  /// Método auxiliar para obtener ubicaciones cuando la vista no está disponible
  Future<List<UbicacionTiempoRealModel>> _obtenerUbicacionesActualesManual(
    String sesionId,
  ) async {
    final response = await _supabase
        .from('ubicaciones_tiempo_real')
        .select()
        .eq('sesion_id', sesionId)
        .order('ultima_actualizacion', ascending: false);

    // Agrupar por usuario y tomar solo la más reciente de cada uno
    final Map<String, Map<String, dynamic>> ubicacionesPorUsuario = {};

    for (final item in response as List) {
      final usuarioId = item['usuario_id'] as String;
      if (!ubicacionesPorUsuario.containsKey(usuarioId)) {
        ubicacionesPorUsuario[usuarioId] = item;
      }
    }

    return ubicacionesPorUsuario.values
        .map((json) => UbicacionTiempoRealModel.fromJson(json))
        .toList();
  }

  @override
  Stream<List<UbicacionTiempoRealModel>> suscribirseAUbicaciones(
    String sesionId,
  ) {
    return _supabase
        .from('ubicaciones_tiempo_real')
        .stream(primaryKey: ['id'])
        .eq('sesion_id', sesionId)
        .order('ultima_actualizacion', ascending: false)
        .map((data) {
          // Agrupar por usuario y tomar solo la más reciente
          final Map<String, Map<String, dynamic>> ubicacionesPorUsuario = {};

          for (final item in data) {
            final usuarioId = item['usuario_id'] as String;
            if (!ubicacionesPorUsuario.containsKey(usuarioId)) {
              ubicacionesPorUsuario[usuarioId] = item;
            }
          }

          return ubicacionesPorUsuario.values
              .map((json) => UbicacionTiempoRealModel.fromJson(json))
              .toList();
        });
  }

  // ========================================
  // MÉTODOS DE PARTICIPANTES DE SESIÓN
  // ========================================

  @override
  Future<ParticipanteSesionModel> solicitarUnirseASesion({
    required String sesionId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Verificar si ya existe solicitud
    final existente = await _supabase
        .from('participantes_sesion')
        .select()
        .eq('sesion_id', sesionId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (existente != null) {
      return ParticipanteSesionModel.fromJson(existente);
    }

    // Crear nueva solicitud
    final response = await _supabase
        .from('participantes_sesion')
        .insert({
          'sesion_id': sesionId,
          'usuario_id': userId,
          'estado_aprobacion': 'pendiente',
        })
        .select()
        .single();

    return ParticipanteSesionModel.fromJson(response);
  }

  @override
  Future<List<ParticipanteSesionModel>> obtenerParticipantes(
    String sesionId,
  ) async {
    final participantesData = await _supabase
        .from('participantes_sesion')
        .select()
        .eq('sesion_id', sesionId)
        .order('fecha_solicitud');

    if ((participantesData as List).isEmpty) {
      return [];
    }

    final userIds = participantesData
        .map((p) => p['usuario_id'] as String)
        .toSet()
        .toList();

    final usuarios = await _supabase
        .from('usuarios')
        .select('id, nombre, apodo, foto_perfil_url')
        .inFilter('id', userIds);

    final usuariosMap = <String, dynamic>{
      for (final u in usuarios) u['id']: u
    };

    return participantesData.map((p) {
      final usuario = usuariosMap[p['usuario_id']] ?? {};
      return ParticipanteSesionModel.fromJson({
        ...p,
        'nombre': usuario['nombre'],
        'apodo': usuario['apodo'],
        'foto_perfil_url': usuario['foto_perfil_url'],
      });
    }).toList();
  }

  @override
  Future<List<ParticipanteSesionModel>> obtenerParticipantesAprobados(
    String sesionId,
  ) async {
    final participantesData = await _supabase
        .from('participantes_sesion')
        .select()
        .eq('sesion_id', sesionId)
        .eq('estado_aprobacion', 'aprobado')
        .order('fecha_aprobacion');

    if ((participantesData as List).isEmpty) {
      return [];
    }

    final userIds = participantesData
        .map((p) => p['usuario_id'] as String)
        .toSet()
        .toList();

    final usuarios = await _supabase
        .from('usuarios')
        .select('id, nombre, apodo, foto_perfil_url')
        .inFilter('id', userIds);

    final usuariosMap = <String, dynamic>{
      for (final u in usuarios) u['id']: u
    };

    return participantesData.map((p) {
      final usuario = usuariosMap[p['usuario_id']] ?? {};
      return ParticipanteSesionModel.fromJson({
        ...p,
        'nombre': usuario['nombre'],
        'apodo': usuario['apodo'],
        'foto_perfil_url': usuario['foto_perfil_url'],
      });
    }).toList();
  }

  @override
  Future<List<ParticipanteSesionModel>> obtenerSolicitudesPendientes(
    String sesionId,
  ) async {
    // Obtener participantes pendientes desde tabla base
    final participantesData = await _supabase
        .from('participantes_sesion')
        .select()
        .eq('sesion_id', sesionId)
        .eq('estado_aprobacion', 'pendiente')
        .order('fecha_solicitud');

    if ((participantesData as List).isEmpty) {
      return [];
    }

    // Obtener IDs únicos de usuarios
    final userIds = participantesData
        .map((p) => p['usuario_id'] as String)
        .toSet()
        .toList();

    // Fetch datos de usuarios en una sola query (batch)
    final usuarios = await _supabase
        .from('usuarios')
        .select('id, nombre, apodo, foto_perfil_url')
        .inFilter('id', userIds);

    debugPrint('🔍 DEBUG Solicitudes Pendientes:');
    debugPrint('   - Participantes pendientes: ${participantesData.length}');
    debugPrint('   - Usuarios obtenidos: ${(usuarios as List).length}');
    debugPrint('   - Datos usuarios: $usuarios');

    // Crear map para lookup O(1)
    final usuariosMap = <String, dynamic>{
      for (final u in usuarios) u['id']: u
    };

    // Combinar datos
    return participantesData.map((p) {
      final usuario = usuariosMap[p['usuario_id']] ?? {};
      debugPrint('   - Usuario ${p['usuario_id']}: nombre=${usuario['nombre']}, apodo=${usuario['apodo']}');
      return ParticipanteSesionModel.fromJson({
        ...p,
        'nombre': usuario['nombre'],
        'apodo': usuario['apodo'],
        'foto_perfil_url': usuario['foto_perfil_url'],
      });
    }).toList();
  }

  @override
  Future<ParticipanteSesionModel> aprobarParticipante({
    required String participanteId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    await _supabase
        .from('participantes_sesion')
        .update({
          'estado_aprobacion': 'aprobado',
          'fecha_aprobacion': DateTime.now().toIso8601String(),
          'aprobado_por': userId,
        })
        .eq('id', participanteId);

    // Obtener info completa del participante con join a usuarios
    final participanteData = await _supabase
        .from('participantes_sesion')
        .select('*, usuarios(nombre, apodo, foto_perfil_url)')
        .eq('id', participanteId)
        .single();

    final usuario = participanteData['usuarios'] ?? {};
    return ParticipanteSesionModel.fromJson({
      ...participanteData,
      'nombre': usuario['nombre'],
      'apodo': usuario['apodo'],
      'foto_perfil_url': usuario['foto_perfil_url'],
    });
  }

  @override
  Future<void> rechazarParticipante({
    required String participanteId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    await _supabase
        .from('participantes_sesion')
        .update({
          'estado_aprobacion': 'rechazado',
          'aprobado_por': userId,
        })
        .eq('id', participanteId);
  }

  @override
  Stream<List<ParticipanteSesionModel>> streamParticipantes(
    String sesionId,
  ) {
    return _supabase
        .from('participantes_sesion')
        .stream(primaryKey: ['id'])
        .eq('sesion_id', sesionId)
        .order('fecha_solicitud')
        .asyncMap((participantesData) async {
      // Manejar lista vacía
      if (participantesData.isEmpty) {
        return <ParticipanteSesionModel>[];
      }

      // Obtener IDs únicos de usuarios para fetch eficiente
      final userIds = (participantesData as List)
          .map((p) => p['usuario_id'] as String)
          .toSet()
          .toList();

      // Fetch datos de usuarios en una sola query (batch)
      final usuarios = await _supabase
          .from('usuarios')
          .select('id, nombre, apodo, foto_perfil_url')
          .inFilter('id', userIds);

      debugPrint('🔍 DEBUG Stream Participantes:');
      debugPrint('   - Participantes en sesión: ${participantesData.length}');
      debugPrint('   - Usuarios obtenidos: ${(usuarios as List).length}');
      if ((usuarios as List).isNotEmpty) {
        debugPrint('   - Primer usuario de ejemplo: ${usuarios[0]}');
      }

      // Crear map para lookup O(1)
      final usuariosMap = <String, dynamic>{
        for (final u in usuarios) u['id']: u
      };

      // Combinar datos de participantes con datos de usuarios
      return participantesData.map((p) {
        final usuario = usuariosMap[p['usuario_id']] ?? {};
        debugPrint('   - Mapeando usuario ${p['usuario_id']}: nombre=${usuario['nombre']}, apodo=${usuario['apodo']}');
        return ParticipanteSesionModel.fromJson({
          ...p,
          'nombre': usuario['nombre'],
          'apodo': usuario['apodo'],
          'foto_perfil_url': usuario['foto_perfil_url'],
        });
      }).toList();
    });
  }

  @override
  Future<bool> estaAprobadoEnSesion({
    required String sesionId,
    String? usuarioId,
  }) async {
    final userId = usuarioId ?? _supabase.auth.currentUser?.id;

    if (userId == null) return false;

    final response = await _supabase
        .from('participantes_sesion')
        .select('estado_aprobacion')
        .eq('sesion_id', sesionId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (response == null) return false;

    return response['estado_aprobacion'] == 'aprobado';
  }

  @override
  Future<bool> esLiderDeSesion({
    required String sesionId,
    String? usuarioId,
  }) async {
    final userId = usuarioId ?? _supabase.auth.currentUser?.id;

    if (userId == null) return false;

    final response = await _supabase
        .from('sesiones_ruta_activa')
        .select('iniciada_por')
        .eq('id', sesionId)
        .single();

    return response['iniciada_por'] == userId;
  }

  @override
  Future<void> cambiarEstadoTracking({
    required String sesionId,
    required bool activo,
    bool conexionPerdida = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    await _supabase
        .from('participantes_sesion')
        .update({
          'tracking_activo': activo,
          'conexion_perdida': conexionPerdida,
        })
        .eq('sesion_id', sesionId)
        .eq('usuario_id', userId);
  }

  @override
  Future<void> salirDeSesion(String sesionId) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Eliminar ubicación del usuario en la sesión
    await _supabase
        .from('ubicaciones_tiempo_real')
        .delete()
        .eq('sesion_id', sesionId)
        .eq('usuario_id', userId);

    // Eliminar de participantes
    await _supabase
        .from('participantes_sesion')
        .delete()
        .eq('sesion_id', sesionId)
        .eq('usuario_id', userId);
  }

  // ========================================
  // MÉTODOS DE RUTAS COMPARTIDAS EN SESIÓN
  // ========================================

  @override
  Future<void> compartirRuta({
    required String sesionId,
    required double destinoLat,
    required double destinoLng,
    String? destinoNombre,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Eliminar ruta anterior si existe (solo una ruta activa por sesión)
    await _supabase
        .from('rutas_sesion')
        .delete()
        .eq('sesion_id', sesionId);

    // Insertar nueva ruta
    await _supabase.from('rutas_sesion').insert({
      'sesion_id': sesionId,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'destino_nombre': destinoNombre,
      'compartida_por': userId,
    });
  }

  @override
  Future<RutaCompartidaModel?> obtenerRutaCompartida(String sesionId) async {
    try {
      final response = await _supabase
          .from('rutas_sesion')
          .select()
          .eq('sesion_id', sesionId)
          .maybeSingle();

      if (response == null) return null;
      return RutaCompartidaModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<RutaCompartidaModel?> streamRutaCompartida(String sesionId) {
    debugPrint('📡 Creando stream de ruta compartida para sesión: $sesionId');

    return _supabase
        .from('rutas_sesion')
        .stream(primaryKey: ['id'])
        .map((allData) {
          // Filtrar manualmente las rutas de esta sesión
          final rutasSesion = allData.where((ruta) =>
            ruta['sesion_id'] == sesionId
          ).toList();

          if (rutasSesion.isEmpty) {
            debugPrint('📡 Stream: No hay ruta para sesión $sesionId (emitiendo null)');
            return null;
          }

          debugPrint('📡 Stream: Ruta encontrada para sesión $sesionId');
          return RutaCompartidaModel.fromJson(rutasSesion.first);
        });
  }

  @override
  Future<void> eliminarRutaCompartida(String sesionId) async {
    debugPrint('🗑️ Eliminando ruta compartida de sesión: $sesionId');
    await _supabase
        .from('rutas_sesion')
        .delete()
        .eq('sesion_id', sesionId);
    debugPrint('✅ DELETE ejecutado en rutas_sesion');
  }

  // ========================================
  // MÉTODOS AUXILIARES
  // ========================================

  /// Genera un código de invitación único
  Future<String> _generarCodigoUnico() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    int intentos = 0;
    const maxIntentos = 10;

    while (intentos < maxIntentos) {
      // Generar código de 6 caracteres
      final codigo = List.generate(
        6,
        (index) => chars[random.nextInt(chars.length)],
      ).join();

      // Verificar si ya existe
      final existe = await _codigoExiste(codigo);
      if (!existe) {
        return codigo;
      }

      intentos++;
    }

    throw Exception('No se pudo generar un código único');
  }

  /// Verifica si un código ya existe
  Future<bool> _codigoExiste(String codigo) async {
    try {
      final response = await _supabase
          .from('grupos_ruta')
          .select('id')
          .eq('codigo_invitacion', codigo);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ========================================
  // MÉTODOS DE GESTIÓN DE MIEMBROS (BLOQUEOS)
  // ========================================

  @override
  Future<bool> estaUsuarioBloqueado(String grupoId, [String? usuarioId]) async {
    try {
      final userId = usuarioId ?? _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('usuarios_bloqueados_grupo')
          .select('id')
          .eq('grupo_id', grupoId)
          .eq('usuario_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Bloquea a un usuario en un grupo (uso interno)
  Future<void> _bloquearUsuario({
    required String grupoId,
    required String usuarioId,
    required MotivoBloqueo motivo,
    String? bloqueadoPor,
  }) async {
    try {
      await _supabase.from('usuarios_bloqueados_grupo').insert({
        'grupo_id': grupoId,
        'usuario_id': usuarioId,
        'bloqueado_por': bloqueadoPor,
        'motivo': motivo.toStringValue(),
      });

      debugPrint('✅ Usuario bloqueado: $usuarioId en grupo $grupoId (motivo: ${motivo.name})');
    } catch (e) {
      debugPrint('❌ Error al bloquear usuario: $e');
      throw Exception('Error al bloquear usuario: ${e.toString()}');
    }
  }

  @override
  Future<void> expulsarMiembro(String grupoId, String usuarioId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que el usuario actual es admin
      final esAdmin = await esAdminDeGrupo(grupoId);
      if (!esAdmin) {
        throw Exception('No tienes permisos para expulsar miembros');
      }

      // Eliminar de miembros_grupo
      await _supabase
          .from('miembros_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', usuarioId);

      // Agregar a usuarios_bloqueados_grupo
      await _bloquearUsuario(
        grupoId: grupoId,
        usuarioId: usuarioId,
        motivo: MotivoBloqueo.expulsado,
        bloqueadoPor: currentUserId,
      );

      debugPrint('✅ Miembro expulsado: $usuarioId del grupo $grupoId');
    } catch (e) {
      debugPrint('❌ Error al expulsar miembro: $e');
      throw Exception('Error al expulsar miembro: ${e.toString()}');
    }
  }

  @override
  Future<void> salirDeGrupoConBloqueo(String grupoId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que no es el único admin
      final miembros = await obtenerMiembrosGrupo(grupoId);
      final admins = miembros.where((m) => m.esAdmin).toList();
      final esAdmin = admins.any((a) => a.usuarioId == userId);

      if (esAdmin && admins.length == 1) {
        throw Exception(
          'No puedes salir del grupo siendo el único administrador. '
          'Asigna otro admin primero o elimina el grupo.',
        );
      }

      // Eliminar de miembros_grupo
      await _supabase
          .from('miembros_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', userId);

      // Agregar a usuarios_bloqueados_grupo con motivo abandono
      await _bloquearUsuario(
        grupoId: grupoId,
        usuarioId: userId,
        motivo: MotivoBloqueo.abandono,
        bloqueadoPor: userId, // Auto-bloqueo
      );

      debugPrint('✅ Usuario salió del grupo con bloqueo: $grupoId');
    } catch (e) {
      debugPrint('❌ Error al salir del grupo: $e');
      throw Exception('Error al salir del grupo: ${e.toString()}');
    }
  }

  @override
  Future<void> desbloquearUsuario(String grupoId, String usuarioId) async {
    try {
      final esAdmin = await esAdminDeGrupo(grupoId);
      if (!esAdmin) {
        throw Exception('No tienes permisos para desbloquear usuarios');
      }

      await _supabase
          .from('usuarios_bloqueados_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', usuarioId);

      debugPrint('✅ Usuario desbloqueado: $usuarioId en grupo $grupoId');
    } catch (e) {
      debugPrint('❌ Error al desbloquear usuario: $e');
      throw Exception('Error al desbloquear usuario: ${e.toString()}');
    }
  }

  // ========================================
  // MÉTODOS DE SOLICITUDES DE GRUPO
  // ========================================

  @override
  Future<SolicitudGrupoModel> solicitarUnirseAGrupo(String codigo) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Buscar el grupo por código
      final grupo = await buscarGrupoPorCodigo(codigo);
      if (grupo == null) {
        throw Exception('Código de invitación inválido');
      }

      // Verificar si ya es miembro
      final yaMiembro = await esMiembroDeGrupo(grupo.id);
      if (yaMiembro) {
        throw Exception('Ya eres miembro de este grupo');
      }

      // Verificar si ya tiene una solicitud (cualquier estado)
      final solicitudExistente = await _supabase
          .from('solicitudes_grupo')
          .select()
          .eq('grupo_id', grupo.id)
          .eq('usuario_id', userId)
          .maybeSingle();

      // Verificar si estaba bloqueado (para marcar fueBloqueadoAntes)
      final estabaBloqueado = await estaUsuarioBloqueado(grupo.id, userId);

      Map<String, dynamic> response;

      if (solicitudExistente != null) {
        // Ya existe una solicitud
        final estadoActual = solicitudExistente['estado'] as String;

        if (estadoActual == 'pendiente') {
          throw Exception('Ya tienes una solicitud pendiente para este grupo');
        }

        // Si fue aprobada o rechazada, actualizarla a pendiente nuevamente
        response = await _supabase
            .from('solicitudes_grupo')
            .update({
              'estado': 'pendiente',
              'fecha_solicitud': DateTime.now().toIso8601String(),
              'fecha_resolucion': null,
              'resuelto_por': null,
              'fue_bloqueado_antes': estabaBloqueado,
            })
            .eq('id', solicitudExistente['id'])
            .select()
            .single();

        debugPrint('✅ Solicitud reactivada para grupo: ${grupo.nombre}');
      } else {
        // Crear nueva solicitud
        response = await _supabase.from('solicitudes_grupo').insert({
          'grupo_id': grupo.id,
          'usuario_id': userId,
          'estado': 'pendiente',
          'fue_bloqueado_antes': estabaBloqueado,
        }).select().single();

        debugPrint('✅ Solicitud creada para grupo: ${grupo.nombre}');
      }

      return SolicitudGrupoModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error al solicitar unirse: $e');
      throw Exception('Error al solicitar unirse: ${e.toString()}');
    }
  }

  @override
  Future<List<SolicitudGrupoModel>> obtenerSolicitudesPendientesGrupo(
    String grupoId,
  ) async {
    try {
      final response = await _supabase
          .from('vista_solicitudes_grupo')
          .select()
          .eq('grupo_id', grupoId)
          .eq('estado', 'pendiente')
          .order('fecha_solicitud');

      return (response as List)
          .map((json) => SolicitudGrupoModel.fromJson(json))
          .toList();
    } catch (e) {
      // Si la vista no existe, usar query manual
      try {
        return await _obtenerSolicitudesPendientesManual(grupoId);
      } catch (e2) {
        debugPrint('❌ Error al obtener solicitudes: $e2');
        return [];
      }
    }
  }

  /// Método auxiliar cuando la vista no está disponible
  Future<List<SolicitudGrupoModel>> _obtenerSolicitudesPendientesManual(
    String grupoId,
  ) async {
    final solicitudesData = await _supabase
        .from('solicitudes_grupo')
        .select()
        .eq('grupo_id', grupoId)
        .eq('estado', 'pendiente')
        .order('fecha_solicitud');

    if ((solicitudesData as List).isEmpty) {
      return [];
    }

    // Obtener IDs únicos de usuarios
    final userIds = solicitudesData
        .map((s) => s['usuario_id'] as String)
        .toSet()
        .toList();

    // Fetch datos de usuarios
    final usuarios = await _supabase
        .from('usuarios')
        .select('id, nombre, apodo, foto_perfil_url')
        .inFilter('id', userIds);

    // Crear map para lookup
    final usuariosMap = <String, dynamic>{
      for (final u in usuarios as List) u['id']: u
    };

    // Combinar datos
    return solicitudesData.map((s) {
      final usuario = usuariosMap[s['usuario_id']] ?? {};
      return SolicitudGrupoModel.fromJson({
        ...s,
        'nombre': usuario['nombre'],
        'apodo': usuario['apodo'],
        'foto_perfil_url': usuario['foto_perfil_url'],
      });
    }).toList();
  }

  @override
  Future<void> aprobarSolicitudGrupo(String solicitudId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener la solicitud
      final solicitud = await _supabase
          .from('solicitudes_grupo')
          .select()
          .eq('id', solicitudId)
          .single();

      final grupoId = solicitud['grupo_id'] as String;
      final usuarioId = solicitud['usuario_id'] as String;

      // Verificar que es admin
      final esAdmin = await esAdminDeGrupo(grupoId);
      if (!esAdmin) {
        throw Exception('No tienes permisos para aprobar solicitudes');
      }

      // Remover bloqueo si existe
      await _supabase
          .from('usuarios_bloqueados_grupo')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('usuario_id', usuarioId);

      // Agregar como miembro
      await _supabase.from('miembros_grupo').insert({
        'grupo_id': grupoId,
        'usuario_id': usuarioId,
        'es_admin': false,
      });

      // Actualizar solicitud
      await _supabase
          .from('solicitudes_grupo')
          .update({
            'estado': 'aprobado',
            'fecha_resolucion': DateTime.now().toIso8601String(),
            'resuelto_por': currentUserId,
          })
          .eq('id', solicitudId);

      debugPrint('✅ Solicitud aprobada: $solicitudId');
    } catch (e) {
      debugPrint('❌ Error al aprobar solicitud: $e');
      throw Exception('Error al aprobar solicitud: ${e.toString()}');
    }
  }

  @override
  Future<void> rechazarSolicitudGrupo(String solicitudId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener la solicitud para verificar permisos
      final solicitud = await _supabase
          .from('solicitudes_grupo')
          .select()
          .eq('id', solicitudId)
          .single();

      final grupoId = solicitud['grupo_id'] as String;

      // Verificar que es admin
      final esAdmin = await esAdminDeGrupo(grupoId);
      if (!esAdmin) {
        throw Exception('No tienes permisos para rechazar solicitudes');
      }

      // Actualizar solicitud
      await _supabase
          .from('solicitudes_grupo')
          .update({
            'estado': 'rechazado',
            'fecha_resolucion': DateTime.now().toIso8601String(),
            'resuelto_por': currentUserId,
          })
          .eq('id', solicitudId);

      debugPrint('✅ Solicitud rechazada: $solicitudId');
    } catch (e) {
      debugPrint('❌ Error al rechazar solicitud: $e');
      throw Exception('Error al rechazar solicitud: ${e.toString()}');
    }
  }

  @override
  Stream<List<SolicitudGrupoModel>> streamSolicitudesGrupo(String grupoId) {
    return _supabase
        .from('solicitudes_grupo')
        .stream(primaryKey: ['id'])
        .eq('grupo_id', grupoId)
        .order('fecha_solicitud')
        .asyncMap((solicitudesData) async {
      // Filtrar solo pendientes
      final pendientes = (solicitudesData as List)
          .where((s) => s['estado'] == 'pendiente')
          .toList();

      if (pendientes.isEmpty) {
        return <SolicitudGrupoModel>[];
      }

      // Obtener IDs únicos de usuarios
      final userIds = pendientes
          .map((s) => s['usuario_id'] as String)
          .toSet()
          .toList();

      // Fetch datos de usuarios
      final usuarios = await _supabase
          .from('usuarios')
          .select('id, nombre, apodo, foto_perfil_url')
          .inFilter('id', userIds);

      // Crear map para lookup
      final usuariosMap = <String, dynamic>{
        for (final u in usuarios as List) u['id']: u
      };

      // Combinar datos
      return pendientes.map((s) {
        final usuario = usuariosMap[s['usuario_id']] ?? {};
        return SolicitudGrupoModel.fromJson({
          ...s,
          'nombre': usuario['nombre'],
          'apodo': usuario['apodo'],
          'foto_perfil_url': usuario['foto_perfil_url'],
        });
      }).toList();
    });
  }

  @override
  Future<int> contarSolicitudesPendientes(String grupoId) async {
    try {
      final response = await _supabase
          .from('solicitudes_grupo')
          .select('id')
          .eq('grupo_id', grupoId)
          .eq('estado', 'pendiente');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ========================================
  // REGENERACIÓN DE CÓDIGO DE INVITACIÓN
  // ========================================

  @override
  Future<String> regenerarCodigoInvitacion(String grupoId) async {
    try {
      final esAdmin = await esAdminDeGrupo(grupoId);
      if (!esAdmin) {
        throw Exception('No tienes permisos para regenerar el código');
      }

      // Generar nuevo código único
      final nuevoCodigo = await _generarCodigoUnico();

      // Actualizar el grupo
      await _supabase
          .from('grupos_ruta')
          .update({'codigo_invitacion': nuevoCodigo})
          .eq('id', grupoId);

      debugPrint('✅ Código regenerado para grupo $grupoId: $nuevoCodigo');
      return nuevoCodigo;
    } catch (e) {
      debugPrint('❌ Error al regenerar código: $e');
      throw Exception('Error al regenerar código: ${e.toString()}');
    }
  }

  // ========================================
  // NOTIFICACIONES (SOS)
  // ========================================

  @override
  Future<void> enviarSOS({
    required String sesionId,
    required String grupoId,
    required String usuarioId,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-session-notification',
        body: {
          'event_type': 'sos',
          'sesion_id': sesionId,
          'grupo_id': grupoId,
          'usuario_id': usuarioId,
        },
      );
      debugPrint('🚨 SOS enviado correctamente a sesión $sesionId');
    } catch (e) {
      debugPrint('❌ Error al invocar Edge Function de SOS: $e');
      throw Exception('Error al enviar SOS: $e');
    }
  }
}
