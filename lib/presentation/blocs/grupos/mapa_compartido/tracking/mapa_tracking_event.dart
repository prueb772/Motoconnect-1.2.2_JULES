import 'package:equatable/equatable.dart';
import '../../../../../data/models/ubicacion_tiempo_real_model.dart';

abstract class MapaTrackingEvent extends Equatable {
  const MapaTrackingEvent();

  @override
  List<Object?> get props => [];
}

class MapaTrackingIniciar extends MapaTrackingEvent {
  final String sesionId;

  const MapaTrackingIniciar(this.sesionId);

  @override
  List<Object> get props => [sesionId];
}

class MapaTrackingUbicacionesActualizadas extends MapaTrackingEvent {
  final List<UbicacionTiempoRealModel> ubicaciones;

  const MapaTrackingUbicacionesActualizadas(this.ubicaciones);

  @override
  List<Object> get props => [ubicaciones];
}

class MapaTrackingConexionActualizada extends MapaTrackingEvent {
  final bool conectado;

  const MapaTrackingConexionActualizada(this.conectado);

  @override
  List<Object> get props => [conectado];
}

class MapaTrackingDismissMensajeConexion extends MapaTrackingEvent {}
