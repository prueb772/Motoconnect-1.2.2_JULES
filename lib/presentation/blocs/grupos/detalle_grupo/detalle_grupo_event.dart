part of 'detalle_grupo_bloc.dart';

sealed class DetalleGrupoEvent extends Equatable {
  const DetalleGrupoEvent();
  @override
  List<Object?> get props => [];
}

/// Solicita cargar/recargar datos del grupo
class DetalleGrupoLoadRequested extends DetalleGrupoEvent {
  const DetalleGrupoLoadRequested();
}

/// Solicita iniciar una sesión
class DetalleGrupoSesionInitRequested extends DetalleGrupoEvent {
  const DetalleGrupoSesionInitRequested({
    required this.nombreSesion,
    this.descripcion,
  });

  final String nombreSesion;
  final String? descripcion;

  @override
  List<Object?> get props => [nombreSesion, descripcion];
}

/// Solicita expulsar un miembro
class DetalleGrupoMiembroExpulsadoRequested extends DetalleGrupoEvent {
  const DetalleGrupoMiembroExpulsadoRequested({
    required this.usuarioId,
    this.nombreUsuario,
  });

  final String usuarioId;
  final String? nombreUsuario;

  @override
  List<Object?> get props => [usuarioId, nombreUsuario];
}

/// Solicitud de grupo aprobada
class DetalleGrupoSolicitudAprobada extends DetalleGrupoEvent {
  const DetalleGrupoSolicitudAprobada(this.solicitudId);
  final String solicitudId;

  @override
  List<Object?> get props => [solicitudId];
}

/// Solicitud de grupo rechazada
class DetalleGrupoSolicitudRechazada extends DetalleGrupoEvent {
  const DetalleGrupoSolicitudRechazada(this.solicitudId);
  final String solicitudId;

  @override
  List<Object?> get props => [solicitudId];
}

/// Solicita salir del grupo
class DetalleGrupoSalidaRequested extends DetalleGrupoEvent {
  const DetalleGrupoSalidaRequested();
}

/// Finaliza una sesión
class DetalleGrupoSesionFinalizada extends DetalleGrupoEvent {
  const DetalleGrupoSesionFinalizada(this.sesionId);
  final String sesionId;

  @override
  List<Object?> get props => [sesionId];
}

/// Regenera código de invitación
class DetalleGrupoCodigoRegenerado extends DetalleGrupoEvent {
  const DetalleGrupoCodigoRegenerado();
}

/// Elimina el grupo
class DetalleGrupoEliminado extends DetalleGrupoEvent {
  const DetalleGrupoEliminado();
}

/// Actualización interna del conteo de solicitudes (desde stream)
class DetalleGrupoSolicitudesCountUpdated extends DetalleGrupoEvent {
  const DetalleGrupoSolicitudesCountUpdated(this.count);
  final int count;

  @override
  List<Object?> get props => [count];
}
