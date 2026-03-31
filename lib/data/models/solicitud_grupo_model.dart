/// Modelo de Solicitud de Grupo
///
/// Representa una solicitud de un usuario para unirse a un grupo
library;

/// Estados de solicitud de grupo
enum EstadoSolicitudGrupo {
  pendiente,
  aprobado,
  rechazado;

  String toStringValue() {
    return name;
  }

  static EstadoSolicitudGrupo fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pendiente':
        return EstadoSolicitudGrupo.pendiente;
      case 'aprobado':
        return EstadoSolicitudGrupo.aprobado;
      case 'rechazado':
        return EstadoSolicitudGrupo.rechazado;
      default:
        return EstadoSolicitudGrupo.pendiente;
    }
  }
}

class SolicitudGrupoModel {
  final String id;
  final String grupoId;
  final String usuarioId;
  final EstadoSolicitudGrupo estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaResolucion;
  final String? resueltoPor;
  final bool fueBloqueadoAntes;
  final DateTime createdAt;

  // Datos del usuario (cuando se hace join)
  final String? nombre;
  final String? apodo;
  final String? fotoPerfilUrl;

  const SolicitudGrupoModel({
    required this.id,
    required this.grupoId,
    required this.usuarioId,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaResolucion,
    this.resueltoPor,
    required this.fueBloqueadoAntes,
    required this.createdAt,
    this.nombre,
    this.apodo,
    this.fotoPerfilUrl,
  });

  /// Nombre a mostrar (prioriza apodo sobre nombre)
  String get nombreMostrar {
    if (apodo != null && apodo!.isNotEmpty) {
      return apodo!;
    }
    return nombre ?? 'Usuario';
  }

  /// Indica si está pendiente
  bool get estaPendiente => estado == EstadoSolicitudGrupo.pendiente;

  /// Indica si fue aprobada
  bool get fueAprobada => estado == EstadoSolicitudGrupo.aprobado;

  /// Indica si fue rechazada
  bool get fueRechazada => estado == EstadoSolicitudGrupo.rechazado;

  /// Factory desde JSON
  factory SolicitudGrupoModel.fromJson(Map<String, dynamic> json) {
    return SolicitudGrupoModel(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      usuarioId: json['usuario_id'] as String,
      estado: EstadoSolicitudGrupo.fromString(
        json['estado'] as String? ?? 'pendiente',
      ),
      fechaSolicitud: DateTime.parse(json['fecha_solicitud'] as String),
      fechaResolucion: json['fecha_resolucion'] != null
          ? DateTime.parse(json['fecha_resolucion'] as String)
          : null,
      resueltoPor: json['resuelto_por'] as String?,
      fueBloqueadoAntes: json['fue_bloqueado_antes'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      nombre: json['nombre'] as String?,
      apodo: json['apodo'] as String?,
      fotoPerfilUrl: json['foto_perfil_url'] as String?,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'usuario_id': usuarioId,
      'estado': estado.toStringValue(),
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fecha_resolucion': fechaResolucion?.toIso8601String(),
      'resuelto_por': resueltoPor,
      'fue_bloqueado_antes': fueBloqueadoAntes,
      'created_at': createdAt.toIso8601String(),
      if (nombre != null) 'nombre': nombre,
      if (apodo != null) 'apodo': apodo,
      if (fotoPerfilUrl != null) 'foto_perfil_url': fotoPerfilUrl,
    };
  }

  /// Copiar con cambios
  SolicitudGrupoModel copyWith({
    String? id,
    String? grupoId,
    String? usuarioId,
    EstadoSolicitudGrupo? estado,
    DateTime? fechaSolicitud,
    DateTime? fechaResolucion,
    String? resueltoPor,
    bool? fueBloqueadoAntes,
    DateTime? createdAt,
    String? nombre,
    String? apodo,
    String? fotoPerfilUrl,
  }) {
    return SolicitudGrupoModel(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      usuarioId: usuarioId ?? this.usuarioId,
      estado: estado ?? this.estado,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      fechaResolucion: fechaResolucion ?? this.fechaResolucion,
      resueltoPor: resueltoPor ?? this.resueltoPor,
      fueBloqueadoAntes: fueBloqueadoAntes ?? this.fueBloqueadoAntes,
      createdAt: createdAt ?? this.createdAt,
      nombre: nombre ?? this.nombre,
      apodo: apodo ?? this.apodo,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
    );
  }

  @override
  String toString() {
    return 'SolicitudGrupoModel('
        'id: $id, '
        'usuario: $nombreMostrar, '
        'estado: ${estado.name}, '
        'fueBloqueadoAntes: $fueBloqueadoAntes'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SolicitudGrupoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
