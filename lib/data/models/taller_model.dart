/// Modelo de Taller
///
/// Representa un taller mecánico registrado en la plataforma.
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - copyWith para copias modificadas
library;

class TallerModel {
  /// ID único del taller (UUID de Supabase)
  final String id;

  /// Nombre del taller
  final String nombre;

  /// Dirección textual del taller (opcional)
  final String? direccion;

  /// Teléfono de contacto (opcional)
  final String? telefono;

  /// Horario de atención (opcional)
  final String? horario;

  /// Latitud de la ubicación GPS (opcional)
  final double? latitud;

  /// Longitud de la ubicación GPS (opcional)
  final double? longitud;

  /// ID del usuario que creó el taller
  final String creadoPor;

  /// Fecha de creación del registro
  final DateTime createdAt;

  /// Constructor
  const TallerModel({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.horario,
    this.latitud,
    this.longitud,
    required this.creadoPor,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON (respuesta de Supabase)
  factory TallerModel.fromJson(Map<String, dynamic> json) {
    return TallerModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      horario: json['horario'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      creadoPor: json['creado_por'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'horario': horario,
      'latitud': latitud,
      'longitud': longitud,
      'creado_por': creadoPor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  TallerModel copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? telefono,
    String? horario,
    double? latitud,
    double? longitud,
    String? creadoPor,
    DateTime? createdAt,
  }) {
    return TallerModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      horario: horario ?? this.horario,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      creadoPor: creadoPor ?? this.creadoPor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
