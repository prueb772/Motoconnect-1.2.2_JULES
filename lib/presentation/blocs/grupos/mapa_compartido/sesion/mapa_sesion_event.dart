import 'package:equatable/equatable.dart';
import '../../../../../data/models/participante_sesion_model.dart';
import '../../../../../data/models/sesion_ruta_activa_model.dart';
import '../../../../../data/models/ruta_compartida_model.dart';
import '../../../../../data/models/grupo_ruta_model.dart';

abstract class MapaSesionEvent extends Equatable {
  const MapaSesionEvent();

  @override
  List<Object?> get props => [];
}

class MapaSesionInicializar extends MapaSesionEvent {
  final SesionRutaActivaModel sesion;
  final GrupoRutaModel grupo;

  const MapaSesionInicializar({
    required this.sesion,
    required this.grupo,
  });

  @override
  List<Object> get props => [sesion, grupo];
}

class MapaSesionParticipantesActualizados extends MapaSesionEvent {
  final List<ParticipanteSesionModel> participantes;

  const MapaSesionParticipantesActualizados(this.participantes);

  @override
  List<Object> get props => [participantes];
}

class MapaSesionEstadoActualizado extends MapaSesionEvent {
  final SesionRutaActivaModel? sesion;

  const MapaSesionEstadoActualizado(this.sesion);

  @override
  List<Object?> get props => [sesion];
}

class MapaSesionTogglePausarUbicacion extends MapaSesionEvent {}

class MapaSesionEnviarSOS extends MapaSesionEvent {}

class MapaSesionFinalizar extends MapaSesionEvent {}

class MapaSesionSalir extends MapaSesionEvent {}

final class MapaSesionRutaCompartidaActualizada extends MapaSesionEvent {
  final RutaCompartidaModel? rutaCompartida;
  const MapaSesionRutaCompartidaActualizada(this.rutaCompartida);
}
