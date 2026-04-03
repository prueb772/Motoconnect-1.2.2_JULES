/// Interfaz abstracta del Repository de Grupos
///
/// Define el contrato que debe seguir cualquier implementación
/// de acceso a datos de grupos.
///
/// Patrón Repository (Clean Architecture):
/// - Esta interfaz vive en data/repositories/
/// - La implementación concreta vive en data/repositories/impl/
/// - Los BLoCs reciben esta interfaz por constructor (DI)
///
/// Responsabilidades:
/// - Operaciones CRUD de grupos de rutas
/// - Gestión de miembros de grupos
/// - Gestión de sesiones activas
/// - Gestión de ubicaciones en tiempo real
/// - Gestión de participantes de sesión
/// - Gestión de rutas compartidas
/// - Gestión de solicitudes de grupo
/// - Gestión de bloqueos
library;

import '../models/grupo_ruta_model.dart';
import '../models/miembro_grupo_model.dart';
import '../models/sesion_ruta_activa_model.dart';
import '../models/ubicacion_tiempo_real_model.dart';
import '../models/participante_sesion_model.dart';
import '../models/ruta_sesion_model.dart';
import '../models/ruta_compartida_model.dart';
import '../models/solicitud_grupo_model.dart';


/// Interfaz abstracta del repositorio de Grupos
abstract class GrupoRepository {
  // ========================================
  // MÉTODOS DE GRUPOS
  // ========================================

  /// Crea un nuevo grupo
  Future<GrupoRutaModel> crearGrupo({
    required String nombre,
    String? descripcion,
  });

  /// Obtiene los grupos del usuario actual
  Future<List<GrupoRutaModel>> obtenerMisGrupos();

  /// Obtiene un grupo por ID
  Future<GrupoRutaModel?> obtenerGrupo(String grupoId);

  /// Actualiza un grupo
  Future<void> actualizarGrupo({
    required String grupoId,
    String? nombre,
    String? descripcion,
    bool? activo,
    String? fotoUrl,
  });

  /// Sube una foto de grupo a Storage
  Future<String> subirFotoGrupo({
    required String grupoId,
    required String imagePath,
  });

  /// Elimina un grupo (solo admins)
  Future<void> eliminarGrupo(String grupoId);

  // ========================================
  // MÉTODOS DE MIEMBROS
  // ========================================

  /// Unirse a un grupo mediante código
  Future<GrupoRutaModel> unirseAGrupo(String codigo);

  /// Obtiene los miembros de un grupo
  Future<List<MiembroGrupoModel>> obtenerMiembrosGrupo(String grupoId);

  /// Verifica si el usuario actual es miembro de un grupo
  Future<bool> esMiembroDeGrupo(String grupoId);

  /// Verifica si el usuario actual es admin de un grupo
  Future<bool> esAdminDeGrupo(String grupoId);

  /// Salir de un grupo
  Future<void> salirDeGrupo(String grupoId);

  /// Eliminar un miembro del grupo (solo admins)
  Future<void> eliminarMiembro(String grupoId, String usuarioId);

  /// Busca un grupo por código de invitación
  Future<GrupoRutaModel?> buscarGrupoPorCodigo(String codigo);

  // ========================================
  // MÉTODOS DE SESIONES
  // ========================================

  /// Inicia una nueva sesión de ruta activa
  Future<SesionRutaActivaModel> iniciarSesion({
    required String grupoId,
    required String nombreSesion,
    String? descripcion,
    String? rutaId,
  });

  /// Obtiene las sesiones activas de un grupo
  Future<List<SesionRutaActivaModel>> obtenerSesionesActivas(String grupoId);

  /// Verifica si el usuario actual tiene sesiones activas como líder
  Future<SesionRutaActivaModel?> obtenerSesionActivaDelUsuario();

  /// Obtiene una sesión por ID
  Future<SesionRutaActivaModel?> obtenerSesion(String sesionId);

  /// Actualiza el estado de una sesión
  Future<void> actualizarEstadoSesion({
    required String sesionId,
    required EstadoSesion estado,
  });

  /// Finaliza una sesión
  Future<void> finalizarSesion(String sesionId);

  /// Stream del estado de una sesión en tiempo real
  Stream<SesionRutaActivaModel?> streamEstadoSesion(String sesionId);

  // ========================================
  // MÉTODOS DE UBICACIONES EN TIEMPO REAL
  // ========================================

  /// Actualiza la ubicación del usuario en una sesión
  Future<void> actualizarUbicacion({
    required String sesionId,
    required double latitud,
    required double longitud,
    double? velocidad,
    double? direccion,
    double? altitud,
    double? precisionMetros,
  });

  /// Obtiene las ubicaciones actuales de todos los miembros en una sesión
  Future<List<UbicacionTiempoRealModel>> obtenerUbicacionesActuales(
    String sesionId,
  );

  /// Suscribirse a cambios de ubicaciones en tiempo real
  Stream<List<UbicacionTiempoRealModel>> suscribirseAUbicaciones(
    String sesionId,
  );

  // ========================================
  // MÉTODOS DE PARTICIPANTES DE SESIÓN
  // ========================================

  /// Solicitar unirse a una sesión
  Future<ParticipanteSesionModel> solicitarUnirseASesion({
    required String sesionId,
  });

  /// Obtener participantes de una sesión
  Future<List<ParticipanteSesionModel>> obtenerParticipantes(String sesionId);

  /// Obtener solo participantes aprobados
  Future<List<ParticipanteSesionModel>> obtenerParticipantesAprobados(
    String sesionId,
  );

  /// Obtener solicitudes pendientes
  Future<List<ParticipanteSesionModel>> obtenerSolicitudesPendientes(
    String sesionId,
  );

  /// Aprobar participante
  Future<ParticipanteSesionModel> aprobarParticipante({
    required String participanteId,
  });

  /// Rechazar participante
  Future<void> rechazarParticipante({required String participanteId});

  /// Stream de participantes (tiempo real)
  Stream<List<ParticipanteSesionModel>> streamParticipantes(String sesionId);

  /// Verificar si usuario está aprobado en sesión
  Future<bool> estaAprobadoEnSesion({
    required String sesionId,
    String? usuarioId,
  });

  /// Verificar si usuario es líder de la sesión
  Future<bool> esLiderDeSesion({
    required String sesionId,
    String? usuarioId,
  });

  // ========================================
  // TRACKING Y SALIDA
  // ========================================

  /// Pausar/reanudar tracking de participante
  Future<void> cambiarEstadoTracking({
    required String sesionId,
    required bool activo,
    bool conexionPerdida = false,
  });

  /// Salir de una sesión como participante
  Future<void> salirDeSesion(String sesionId);

  // ========================================
  // RUTAS COMPARTIDAS EN SESIÓN
  // ========================================

  /// Compartir ruta con la sesión (solo líder)
  Future<void> compartirRuta({
    required String sesionId,
    required double destinoLat,
    required double destinoLng,
    String? destinoNombre,
  });

  /// Obtener ruta compartida de una sesión
  Future<RutaCompartidaModel?> obtenerRutaCompartida(String sesionId);

  /// Stream de ruta compartida (tiempo real)
  Stream<RutaCompartidaModel?> streamRutaCompartida(String sesionId);

  /// Eliminar ruta compartida
  Future<void> eliminarRutaCompartida(String sesionId);

  // ========================================
  // GESTIÓN DE MIEMBROS (BLOQUEOS)
  // ========================================

  /// Verifica si un usuario está bloqueado en un grupo
  Future<bool> estaUsuarioBloqueado(String grupoId, [String? usuarioId]);

  /// Expulsa a un miembro del grupo (solo admins)
  Future<void> expulsarMiembro(String grupoId, String usuarioId);

  /// Salir de un grupo con bloqueo (no permite reingreso directo)
  Future<void> salirDeGrupoConBloqueo(String grupoId);

  /// Desbloquea a un usuario de un grupo (solo admins)
  Future<void> desbloquearUsuario(String grupoId, String usuarioId);

  // ========================================
  // SOLICITUDES DE GRUPO
  // ========================================

  /// Solicita unirse a un grupo mediante código
  Future<SolicitudGrupoModel> solicitarUnirseAGrupo(String codigo);

  /// Obtiene las solicitudes pendientes de un grupo
  Future<List<SolicitudGrupoModel>> obtenerSolicitudesPendientesGrupo(
    String grupoId,
  );

  /// Aprueba una solicitud de grupo
  Future<void> aprobarSolicitudGrupo(String solicitudId);

  /// Rechaza una solicitud de grupo
  Future<void> rechazarSolicitudGrupo(String solicitudId);

  /// Stream de solicitudes pendientes de un grupo (tiempo real)
  Stream<List<SolicitudGrupoModel>> streamSolicitudesGrupo(String grupoId);

  /// Obtiene el conteo de solicitudes pendientes
  Future<int> contarSolicitudesPendientes(String grupoId);

  // ========================================
  // REGENERACIÓN DE CÓDIGO DE INVITACIÓN
  // ========================================

  /// Regenera el código de invitación de un grupo
  Future<String> regenerarCodigoInvitacion(String grupoId);

  // ========================================
  // NOTIFICACIONES (SOS)
  // ========================================

  /// Envía notificación SOS a todos los participantes de una sesión
  Future<void> enviarSOS({
    required String sesionId,
    required String grupoId,
    required String usuarioId,
  });
}
