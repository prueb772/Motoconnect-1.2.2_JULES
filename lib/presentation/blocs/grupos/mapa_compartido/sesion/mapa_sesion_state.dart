import 'package:equatable/equatable.dart';
import '../../../../../data/models/participante_sesion_model.dart';

enum MapaSesionStatus {
  initial,
  loading,
  permissionsError,
  ready,
  error,
  finalizada,
  salir
}

class MapaSesionState extends Equatable {
  final MapaSesionStatus status;
  final String message;
  final double progress;
  final List<ParticipanteSesionModel> participantes;
  final Map<String, ParticipanteSesionModel> participantesMap;
  final bool esLider;
  final bool esAdminGrupo;
  final bool estaAprobado;
  final bool trackingPausadoPorUsuario;
  final String miUsuarioId;

  const MapaSesionState({
    this.status = MapaSesionStatus.initial,
    this.message = '',
    this.progress = 0.0,
    this.participantes = const [],
    this.participantesMap = const {},
    this.esLider = false,
    this.esAdminGrupo = false,
    this.estaAprobado = false,
    this.trackingPausadoPorUsuario = false,
    this.miUsuarioId = '',
  });

  MapaSesionState copyWith({
    MapaSesionStatus? status,
    String? message,
    double? progress,
    List<ParticipanteSesionModel>? participantes,
    Map<String, ParticipanteSesionModel>? participantesMap,
    bool? esLider,
    bool? esAdminGrupo,
    bool? estaAprobado,
    bool? trackingPausadoPorUsuario,
    String? miUsuarioId,
  }) {
    return MapaSesionState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      participantes: participantes ?? this.participantes,
      participantesMap: participantesMap ?? this.participantesMap,
      esLider: esLider ?? this.esLider,
      esAdminGrupo: esAdminGrupo ?? this.esAdminGrupo,
      estaAprobado: estaAprobado ?? this.estaAprobado,
      trackingPausadoPorUsuario: trackingPausadoPorUsuario ?? this.trackingPausadoPorUsuario,
      miUsuarioId: miUsuarioId ?? this.miUsuarioId,
    );
  }

  @override
  List<Object> get props => [
        status,
        message,
        progress,
        participantes,
        participantesMap,
        esLider,
        esAdminGrupo,
        estaAprobado,
        trackingPausadoPorUsuario,
        miUsuarioId,
      ];
}
