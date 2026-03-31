import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../data/repositories/grupo_repository.dart';
import '../../../../../services/location_tracking_service.dart';
import 'mapa_tracking_event.dart';
import 'mapa_tracking_state.dart';

class MapaTrackingBloc extends Bloc<MapaTrackingEvent, MapaTrackingState> {
  final GrupoRepository _grupoRepository;
  final LocationTrackingService _trackingService;

  StreamSubscription? _ubicacionesSubscription;
  StreamSubscription? _conectadoSubscription;

  late String _sesionId;

  MapaTrackingBloc({
    required GrupoRepository grupoRepository,
    required LocationTrackingService trackingService,
  })  : _grupoRepository = grupoRepository,
        _trackingService = trackingService,
        super(const MapaTrackingState()) {
    on<MapaTrackingIniciar>(_onIniciar);
    on<MapaTrackingUbicacionesActualizadas>(_onUbicacionesActualizadas);
    on<MapaTrackingConexionActualizada>(_onConexionActualizada);
    on<MapaTrackingDismissMensajeConexion>(_onDismissMensajeConexion);
  }

  void _onIniciar(
    MapaTrackingIniciar event,
    Emitter<MapaTrackingState> emit,
  ) {
    _sesionId = event.sesionId;

    _ubicacionesSubscription?.cancel();
    _ubicacionesSubscription = _grupoRepository
        .suscribirseAUbicaciones(_sesionId)
        .listen((ubicaciones) {
      add(MapaTrackingUbicacionesActualizadas(ubicaciones));
    });

    _conectadoSubscription?.cancel();
    _conectadoSubscription = _trackingService.conectadoStream.listen((conectado) {
      add(MapaTrackingConexionActualizada(conectado));
    });

    emit(state.copyWith(trackingActivo: true));
  }

  void _onUbicacionesActualizadas(
    MapaTrackingUbicacionesActualizadas event,
    Emitter<MapaTrackingState> emit,
  ) {
    final Map<String, DateTime> nuevasUltimas = Map.from(state.ultimaUbicacionPorUsuario);
    final now = DateTime.now();
    for (var u in event.ubicaciones) {
      nuevasUltimas[u.usuarioId] = now;
    }

    emit(state.copyWith(
      ubicaciones: event.ubicaciones,
      ultimaUbicacionPorUsuario: nuevasUltimas,
    ));
  }

  void _onConexionActualizada(
    MapaTrackingConexionActualizada event,
    Emitter<MapaTrackingState> emit,
  ) {
    emit(state.copyWith(
      conexionPerdida: !event.conectado,
      mostrarMensajeRestablecida: event.conectado ? true : state.mostrarMensajeRestablecida,
    ));
  }

  void _onDismissMensajeConexion(
    MapaTrackingDismissMensajeConexion event,
    Emitter<MapaTrackingState> emit,
  ) {
    emit(state.copyWith(mostrarMensajeRestablecida: false));
  }

  @override
  Future<void> close() {
    _ubicacionesSubscription?.cancel();
    _conectadoSubscription?.cancel();
    return super.close();
  }
}
