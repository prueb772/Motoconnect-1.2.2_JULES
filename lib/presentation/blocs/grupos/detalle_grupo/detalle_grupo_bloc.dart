import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/miembro_grupo_model.dart';
import '../../../../data/models/sesion_ruta_activa_model.dart';
import '../../../../data/models/solicitud_grupo_model.dart';
import '../../../../data/repositories/grupo_repository.dart';

part 'detalle_grupo_event.dart';
part 'detalle_grupo_state.dart';

/// DetalleGrupoBloc — Gestiona el detalle de un grupo
///
/// Responsabilidades:
/// - Cargar miembros, sesiones, estado admin, solicitudes
/// - Iniciar sesiones
/// - Expulsar miembros
/// - Aprobar/rechazar solicitudes de grupo
/// - Salir del grupo
/// - Finalizar sesiones
/// - Regenerar código de invitación
/// - Eliminar grupo
class DetalleGrupoBloc extends Bloc<DetalleGrupoEvent, DetalleGrupoState> {
  DetalleGrupoBloc({
    required GrupoRepository grupoRepository,
    required String grupoId,
  })  : _grupoRepository = grupoRepository,
        _grupoId = grupoId,
        super(const DetalleGrupoState()) {
    on<DetalleGrupoLoadRequested>(_onLoadRequested);
    on<DetalleGrupoSesionInitRequested>(_onSesionInitRequested);
    on<DetalleGrupoMiembroExpulsadoRequested>(_onMiembroExpulsado);
    on<DetalleGrupoSolicitudAprobada>(_onSolicitudAprobada);
    on<DetalleGrupoSolicitudRechazada>(_onSolicitudRechazada);
    on<DetalleGrupoSalidaRequested>(_onSalidaRequested);
    on<DetalleGrupoSesionFinalizada>(_onSesionFinalizada);
    on<DetalleGrupoCodigoRegenerado>(_onCodigoRegenerado);
    on<DetalleGrupoEliminado>(_onGrupoEliminado);
    on<DetalleGrupoSolicitudesCountUpdated>(_onSolicitudesCountUpdated);

    // Iniciar stream de solicitudes
    _suscribirseASolicitudes();
  }

  final GrupoRepository _grupoRepository;
  final String _grupoId;
  StreamSubscription<List<SolicitudGrupoModel>>? _solicitudesSubscription;

  /// Obtiene el userId actual vía repositorio helper
  Future<String?> obtenerMiUsuarioId() async {
    // Delegamos al repo para no importar supabase_flutter
    // El BLoC no debe conocer Supabase directamente
    // Usamos esAdminDeGrupo como proxy - si funciona, hay userId
    return null; // Se resolverá en la View vía el state
  }

  void _suscribirseASolicitudes() {
    _solicitudesSubscription = _grupoRepository
        .streamSolicitudesGrupo(_grupoId)
        .listen((solicitudes) {
      add(DetalleGrupoSolicitudesCountUpdated(solicitudes.length));
    });
  }

  @override
  Future<void> close() {
    _solicitudesSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadRequested(
    DetalleGrupoLoadRequested event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    emit(state.copyWith(status: DetalleGrupoStatus.loading));

    try {
      final results = await Future.wait([
        _grupoRepository.obtenerMiembrosGrupo(_grupoId),
        _grupoRepository.obtenerSesionesActivas(_grupoId),
        _grupoRepository.esAdminDeGrupo(_grupoId),
        _grupoRepository.contarSolicitudesPendientes(_grupoId),
      ]);

      emit(state.copyWith(
        status: DetalleGrupoStatus.loaded,
        miembros: results[0] as List<MiembroGrupoModel>,
        sesionesActivas: results[1] as List<SesionRutaActivaModel>,
        esAdmin: results[2] as bool,
        solicitudesPendientes: results[3] as int,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DetalleGrupoStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSesionInitRequested(
    DetalleGrupoSesionInitRequested event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.loading));

    try {
      final sesion = await _grupoRepository.iniciarSesion(
        grupoId: _grupoId,
        nombreSesion: event.nombreSesion,
        descripcion: event.descripcion,
      );

      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.sesionCreada,
        sesionCreada: sesion,
      ));

      // Reset action status
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onMiembroExpulsado(
    DetalleGrupoMiembroExpulsadoRequested event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.expulsarMiembro(_grupoId, event.usuarioId);
      // Recargar datos
      add(const DetalleGrupoLoadRequested());
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.miembroExpulsado,
        actionMessage: '${event.nombreUsuario ?? 'Usuario'} ha sido expulsado',
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onSolicitudAprobada(
    DetalleGrupoSolicitudAprobada event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.aprobarSolicitudGrupo(event.solicitudId);
      // Recargar datos
      add(const DetalleGrupoLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onSolicitudRechazada(
    DetalleGrupoSolicitudRechazada event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.rechazarSolicitudGrupo(event.solicitudId);
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onSalidaRequested(
    DetalleGrupoSalidaRequested event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.salirDeGrupoConBloqueo(_grupoId);
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.grupoSalido,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onSesionFinalizada(
    DetalleGrupoSesionFinalizada event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.finalizarSesion(event.sesionId);
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.sesionFinalizada,
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
      // Recargar datos
      add(const DetalleGrupoLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onCodigoRegenerado(
    DetalleGrupoCodigoRegenerado event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      final nuevoCodigo = await _grupoRepository.regenerarCodigoInvitacion(
        _grupoId,
      );
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.codigoRegenerado,
        nuevoCodigo: nuevoCodigo,
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  Future<void> _onGrupoEliminado(
    DetalleGrupoEliminado event,
    Emitter<DetalleGrupoState> emit,
  ) async {
    try {
      await _grupoRepository.eliminarGrupo(_grupoId);
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.grupoEliminado,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionStatus: DetalleGrupoActionStatus.error,
        actionErrorMessage: e.toString(),
      ));
      emit(state.copyWith(actionStatus: DetalleGrupoActionStatus.idle));
    }
  }

  void _onSolicitudesCountUpdated(
    DetalleGrupoSolicitudesCountUpdated event,
    Emitter<DetalleGrupoState> emit,
  ) {
    emit(state.copyWith(solicitudesPendientes: event.count));
  }
}
