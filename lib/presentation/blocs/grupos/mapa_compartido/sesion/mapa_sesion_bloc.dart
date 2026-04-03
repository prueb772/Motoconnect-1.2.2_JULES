import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../data/repositories/grupo_repository.dart';
import '../../../../../data/models/sesion_ruta_activa_model.dart';
import 'mapa_sesion_event.dart';
import 'mapa_sesion_state.dart';

class MapaSesionBloc extends Bloc<MapaSesionEvent, MapaSesionState> {
  final GrupoRepository _grupoRepository;
  final AuthRepository _authRepository;
  
  StreamSubscription? _participantesSubscription;
  StreamSubscription? _estadoSesionSubscription;
  
  late String _sesionId;
  late String _grupoId;

  MapaSesionBloc({
    required GrupoRepository grupoRepository,
    required AuthRepository authRepository,
  })  : _grupoRepository = grupoRepository,
        _authRepository = authRepository,
        super(const MapaSesionState()) {
    on<MapaSesionInicializar>(_onInicializar);
    on<MapaSesionParticipantesActualizados>(_onParticipantesActualizados);
    on<MapaSesionEstadoActualizado>(_onEstadoActualizado);
    on<MapaSesionTogglePausarUbicacion>(_onTogglePausarUbicacion);
    on<MapaSesionEnviarSOS>(_onEnviarSOS);
    on<MapaSesionFinalizar>(_onFinalizar);
    on<MapaSesionSalir>(_onSalir);
    on<MapaSesionRutaCompartidaActualizada>(_onRutaCompartidaActualizada);
  }

  Future<void> _onInicializar(
    MapaSesionInicializar event,
    Emitter<MapaSesionState> emit,
  ) async {
    _sesionId = event.sesion.id;
    _grupoId = event.grupo.id;
    
    emit(state.copyWith(
      status: MapaSesionStatus.loading,
      message: 'Verificando permisos...',
      progress: 0.2,
    ));

    try {
      final currentUser = await _authRepository.getCurrentUser();
      final miUsuarioId = currentUser?.id ?? '';
      
      final esAdminGrupo = await _grupoRepository.esAdminDeGrupo(_grupoId);
      final esLider = event.sesion.iniciadaPor == miUsuarioId;
      
      bool estaAprobado = true;
      if (!esLider && !esAdminGrupo) {
        estaAprobado = await _grupoRepository.estaAprobadoEnSesion(
          sesionId: _sesionId,
          usuarioId: miUsuarioId,
        );
      }

      emit(state.copyWith(
        esLider: esLider,
        esAdminGrupo: esAdminGrupo,
        estaAprobado: estaAprobado,
        miUsuarioId: miUsuarioId,
        message: 'Cargando datos...',
        progress: 0.6,
      ));

      if (!estaAprobado && !esLider && !esAdminGrupo) {
        emit(state.copyWith(
          status: MapaSesionStatus.permissionsError,
          message: 'No tienes permisos para ver esta sesión.',
        ));
        return;
      }
      
      emit(state.copyWith(
        message: 'Conectando con la sesión...',
        progress: 0.8,
      ));

      _iniciarStreams();
      
      emit(state.copyWith(
        status: MapaSesionStatus.ready,
        message: '¡Listo!',
        progress: 1.0,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapaSesionStatus.error,
        message: 'Error al inicializar la sesión: $e',
      ));
    }
  }

  StreamSubscription? _rutaCompartidaSubscription;

  void _iniciarStreams() {
    _participantesSubscription?.cancel();
    _participantesSubscription = _grupoRepository
        .streamParticipantes(_sesionId)
        .listen((participantes) {
      add(MapaSesionParticipantesActualizados(participantes));
    });

    _estadoSesionSubscription?.cancel();
    _estadoSesionSubscription = _grupoRepository
        .streamEstadoSesion(_sesionId)
        .listen((sesion) {
      add(MapaSesionEstadoActualizado(sesion));
    });

    _rutaCompartidaSubscription?.cancel();
    _rutaCompartidaSubscription = _grupoRepository
        .streamRutaCompartida(_sesionId)
        .listen((ruta) {
      add(MapaSesionRutaCompartidaActualizada(ruta));
    });
  }

  void _onParticipantesActualizados(
    MapaSesionParticipantesActualizados event,
    Emitter<MapaSesionState> emit,
  ) {
    if (state.status != MapaSesionStatus.ready && state.status != MapaSesionStatus.loading) return;
    
    final map = {for (final p in event.participantes) p.usuarioId: p};
    
    // Check if the current user was unapproved/rejected while observing
    if (!state.esLider && !state.esAdminGrupo) {
      final miParticipante = map[state.miUsuarioId];
      if (miParticipante != null && !miParticipante.estaAprobado) {
        emit(state.copyWith(
          status: MapaSesionStatus.permissionsError,
          message: 'Tu participación fue revocada.',
          estaAprobado: false,
        ));
        return;
      }
    }
    
    emit(state.copyWith(
      participantes: event.participantes,
      participantesMap: map,
    ));
  }

  void _onEstadoActualizado(
    MapaSesionEstadoActualizado event,
    Emitter<MapaSesionState> emit,
  ) {
    if (event.sesion == null || event.sesion!.estado == EstadoSesion.finalizada) {
      emit(state.copyWith(status: MapaSesionStatus.finalizada));
    }
  }

  Future<void> _onTogglePausarUbicacion(
    MapaSesionTogglePausarUbicacion event,
    Emitter<MapaSesionState> emit,
  ) async {
    try {
      final nuevoEstadoPausado = !state.trackingPausadoPorUsuario;
      await _grupoRepository.cambiarEstadoTracking(
        sesionId: _sesionId,
        activo: !nuevoEstadoPausado,
        conexionPerdida: false,
      );
      emit(state.copyWith(trackingPausadoPorUsuario: nuevoEstadoPausado));
    } catch (e) {
      // Manejar error si es necesario
    }
  }

  Future<void> _onEnviarSOS(
    MapaSesionEnviarSOS event,
    Emitter<MapaSesionState> emit,
  ) async {
    try {
      await _grupoRepository.enviarSOS(
        sesionId: _sesionId,
        grupoId: _grupoId,
        usuarioId: state.miUsuarioId,
      );
    } catch (e) {
      // Manejar error de SOS
    }
  }

  Future<void> _onFinalizar(
    MapaSesionFinalizar event,
    Emitter<MapaSesionState> emit,
  ) async {
    try {
      await _grupoRepository.finalizarSesion(_sesionId);
    } catch (e) {
      // Manejar error
    }
  }

  void _onRutaCompartidaActualizada(
    MapaSesionRutaCompartidaActualizada event,
    Emitter<MapaSesionState> emit,
  ) {
    emit(state.copyWith(rutaCompartida: event.rutaCompartida));
  }

  Future<void> _onSalir(
    MapaSesionSalir event,
    Emitter<MapaSesionState> emit,
  ) async {
    try {
      await _grupoRepository.salirDeSesion(_sesionId);
      emit(state.copyWith(status: MapaSesionStatus.salir));
    } catch (e) {
      // Manejar error
    }
  }

  @override
  Future<void> close() {
    _participantesSubscription?.cancel();
    _estadoSesionSubscription?.cancel();
    _rutaCompartidaSubscription?.cancel();
    return super.close();
  }
}
