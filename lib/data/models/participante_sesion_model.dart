/// Modelo de Participante de Sesión
///
/// Representa a un usuario que participa o solicita participar en una sesión grupal
library;

/// Estados de aprobación de participante
enum EstadoAprobacion {
  pendiente,   // Esperando aprobación del líder
  aprobado,    // Aprobado, puede ver ubicaciones
  rechazado;   // Rechazado por el líder

  String toStringValue() {
    return name;
  }

  static EstadoAprobacion fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pendiente':
        return EstadoAprobacion.pendiente;
      case 'aprobado':
        return EstadoAprobacion.aprobado;
      case 'rechazado':
        return EstadoAprobacion.rechazado;
      default:
        return EstadoAprobacion.pendiente;
    }
  }
}

class ParticipanteSesionModel {
  final String id;
  final String sesionId;
  final String usuarioId;
  final EstadoAprobacion estadoAprobacion;
  final bool trackingActivo;
  final bool conexionPerdida;
  final DateTime fechaSolicitud;
  final DateTime? fechaAprobacion;
  final String? aprobadoPor;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos del usuario (cuando se hace join)
  final String? nombre;
  final String? apodo;
  final String? fotoPerfilUrl;

  const ParticipanteSesionModel({
    required this.id,
    required this.sesionId,
    required this.usuarioId,
    required this.estadoAprobacion,
    required this.trackingActivo,
    this.conexionPerdida = false,
    required this.fechaSolicitud,
    this.fechaAprobacion,
    this.aprobadoPor,
    required this.createdAt,
    required this.updatedAt,
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

  /// Indica si está aprobado
  bool get estaAprobado => estadoAprobacion == EstadoAprobacion.aprobado;

  /// Indica si está pendiente
  bool get estaPendiente => estadoAprobacion == EstadoAprobacion.pendiente;

  /// Indica si fue rechazado
  bool get estaRechazado => estadoAprobacion == EstadoAprobacion.rechazado;

  /// Indica si puede ver ubicaciones
  bool get puedeVerUbicaciones => estaAprobado;

  /// Indica si está compartiendo ubicación activamente
  bool get estaCompartiendoUbicacion => estaAprobado && trackingActivo;

  /// Indica si perdió conexión (estado diferenciado de pausado manual)
  bool get tieneConexionPerdida => conexionPerdida;

  /// Factory desde JSON
  factory ParticipanteSesionModel.fromJson(Map<String, dynamic> json) {
    return ParticipanteSesionModel(
      id: json['id'] as String,
      sesionId: json['sesion_id'] as String,
      usuarioId: json['usuario_id'] as String,
      estadoAprobacion: EstadoAprobacion.fromString(
        json['estado_aprobacion'] as String? ?? 'pendiente',
      ),
      trackingActivo: json['tracking_activo'] as bool? ?? true,
      conexionPerdida: json['conexion_perdida'] as bool? ?? false,
      fechaSolicitud: DateTime.parse(json['fecha_solicitud'] as String),
      fechaAprobacion: json['fecha_aprobacion'] != null
          ? DateTime.parse(json['fecha_aprobacion'] as String)
          : null,
      aprobadoPor: json['aprobado_por'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      nombre: json['nombre'] as String?,
      apodo: json['apodo'] as String?,
      fotoPerfilUrl: json['foto_perfil_url'] as String?,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_id': sesionId,
      'usuario_id': usuarioId,
      'estado_aprobacion': estadoAprobacion.toStringValue(),
      'tracking_activo': trackingActivo,
      'conexion_perdida': conexionPerdida,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
      'aprobado_por': aprobadoPor,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (nombre != null) 'nombre': nombre,
      if (apodo != null) 'apodo': apodo,
      if (fotoPerfilUrl != null) 'foto_perfil_url': fotoPerfilUrl,
    };
  }

  /// Copiar con cambios
  ParticipanteSesionModel copyWith({
    String? id,
    String? sesionId,
    String? usuarioId,
    EstadoAprobacion? estadoAprobacion,
    bool? trackingActivo,
    bool? conexionPerdida,
    DateTime? fechaSolicitud,
    DateTime? fechaAprobacion,
    String? aprobadoPor,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nombre,
    String? apodo,
    String? fotoPerfilUrl,
  }) {
    return ParticipanteSesionModel(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      usuarioId: usuarioId ?? this.usuarioId,
      estadoAprobacion: estadoAprobacion ?? this.estadoAprobacion,
      trackingActivo: trackingActivo ?? this.trackingActivo,
      conexionPerdida: conexionPerdida ?? this.conexionPerdida,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nombre: nombre ?? this.nombre,
      apodo: apodo ?? this.apodo,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
    );
  }

  @override
  String toString() {
    return 'ParticipanteSesionModel('
        'id: $id, '
        'usuario: $nombreMostrar, '
        'estado: ${estadoAprobacion.name}, '
        'tracking: $trackingActivo'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipanteSesionModel &&
        other.id == id &&
        other.estadoAprobacion == estadoAprobacion &&
        other.trackingActivo == trackingActivo &&
        other.conexionPerdida == conexionPerdida;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      estadoAprobacion.hashCode ^
      trackingActivo.hashCode ^
      conexionPerdida.hashCode;
}
