import 'package:equatable/equatable.dart';
import '../../../../../data/models/ubicacion_tiempo_real_model.dart';

class MapaTrackingState extends Equatable {
  final List<UbicacionTiempoRealModel> ubicaciones;
  final Map<String, DateTime> ultimaUbicacionPorUsuario;
  final bool conexionPerdida;
  final bool mostrarMensajeRestablecida;
  final bool trackingActivo;

  const MapaTrackingState({
    this.ubicaciones = const [],
    this.ultimaUbicacionPorUsuario = const {},
    this.conexionPerdida = false,
    this.mostrarMensajeRestablecida = false,
    this.trackingActivo = false,
  });

  MapaTrackingState copyWith({
    List<UbicacionTiempoRealModel>? ubicaciones,
    Map<String, DateTime>? ultimaUbicacionPorUsuario,
    bool? conexionPerdida,
    bool? mostrarMensajeRestablecida,
    bool? trackingActivo,
  }) {
    return MapaTrackingState(
      ubicaciones: ubicaciones ?? this.ubicaciones,
      ultimaUbicacionPorUsuario: ultimaUbicacionPorUsuario ?? this.ultimaUbicacionPorUsuario,
      conexionPerdida: conexionPerdida ?? this.conexionPerdida,
      mostrarMensajeRestablecida: mostrarMensajeRestablecida ?? this.mostrarMensajeRestablecida,
      trackingActivo: trackingActivo ?? this.trackingActivo,
    );
  }

  @override
  List<Object> get props => [
        ubicaciones,
        ultimaUbicacionPorUsuario,
        conexionPerdida,
        mostrarMensajeRestablecida,
        trackingActivo,
      ];
}
