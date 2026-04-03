/// Modelo de Sesión de Ruta Activa
///
/// Representa una sesión de ruta en vivo donde se comparten ubicaciones en tiempo real
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
library;

/// Estado de la sesión
enum EstadoSesion {
  activa,
  pausada,
  finalizada;

  /// Convierte desde string
  static EstadoSesion fromString(String value) {
    switch (value.toLowerCase()) {
      case 'activa':
        return EstadoSesion.activa;
      case 'pausada':
        return EstadoSesion.pausada;
      case 'finalizada':
        return EstadoSesion.finalizada;
      default:
        return EstadoSesion.activa;
    }
  }

  /// Convierte a string
  String toStringValue() {
    switch (this) {
      case EstadoSesion.activa:
        return 'activa';
      case EstadoSesion.pausada:
        return 'pausada';
      case EstadoSesion.finalizada:
        return 'finalizada';
    }
  }
}

class SesionRutaActivaModel {
  /// ID único de la sesión (UUID de Supabase)
  final String id;

  /// ID del grupo
  final String grupoId;

  /// ID de ruta planificada (opcional, puede ser null si es ruta en vivo)
  final String? rutaId;

  /// Nombre de la sesión
  final String nombreSesion;

  /// Descripción de la sesión (opcional)
  final String? descripcion;

  /// Estado de la sesión
  final EstadoSesion estado;

  /// ID del usuario que inició la sesión
  final String iniciadaPor;

  /// Fecha y hora de inicio
  final DateTime fechaInicio;

  /// Fecha y hora de fin (opcional)
  final DateTime? fechaFin;

  /// Fecha de creación
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime updatedAt;

  /// Constructor
  const SesionRutaActivaModel({
    required this.id,
    required this.grupoId,
    this.rutaId,
    required this.nombreSesion,
    this.descripcion,
    this.estado = EstadoSesion.activa,
    required this.iniciadaPor,
    required this.fechaInicio,
    this.fechaFin,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una instancia desde JSON
  factory SesionRutaActivaModel.fromJson(Map<String, dynamic> json) {
    return SesionRutaActivaModel(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      rutaId: json['ruta_id'] as String?,
      nombreSesion: json['nombre_sesion'] as String,
      descripcion: json['descripcion'] as String?,
      estado: EstadoSesion.fromString(
        json['estado'] as String? ?? 'activa',
      ),
      iniciadaPor: json['iniciada_por'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: json['fecha_fin'] != null
          ? DateTime.parse(json['fecha_fin'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'ruta_id': rutaId,
      'nombre_sesion': nombreSesion,
      'descripcion': descripcion,
      'estado': estado.toStringValue(),
      'iniciada_por': iniciadaPor,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  SesionRutaActivaModel copyWith({
    String? id,
    String? grupoId,
    String? rutaId,
    String? nombreSesion,
    String? descripcion,
    EstadoSesion? estado,
    String? iniciadaPor,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SesionRutaActivaModel(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      rutaId: rutaId ?? this.rutaId,
      nombreSesion: nombreSesion ?? this.nombreSesion,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      iniciadaPor: iniciadaPor ?? this.iniciadaPor,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Getters de conveniencia
  bool get estaActiva => estado == EstadoSesion.activa;
  bool get estaPausada => estado == EstadoSesion.pausada;
  bool get estaFinalizada => estado == EstadoSesion.finalizada;
  bool get esRutaPlanificada => rutaId != null;
  bool get esRutaEnVivo => rutaId == null;

  /// Calcula la duración de la sesión
  Duration? get duracion {
    if (fechaFin != null) {
      return fechaFin!.difference(fechaInicio);
    } else if (estaActiva) {
      return DateTime.now().difference(fechaInicio);
    }
    return null;
  }
}
