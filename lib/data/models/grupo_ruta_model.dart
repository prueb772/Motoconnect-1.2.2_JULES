/// Modelo de Grupo de Ruta
///
/// Representa un grupo para compartir rutas y ubicaciones en tiempo real
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
library;

class GrupoRutaModel {
  /// ID único del grupo (UUID de Supabase)
  final String id;

  /// Nombre del grupo
  final String nombre;

  /// Descripción del grupo (opcional)
  final String? descripcion;

  /// Código único para unirse al grupo (6 caracteres alfanuméricos)
  final String codigoInvitacion;

  /// ID del usuario que creó el grupo
  final String creadoPor;

  /// Indica si el grupo está activo
  final bool activo;

  /// URL de la foto del grupo (opcional)
  final String? fotoUrl;

  /// Fecha de creación
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime updatedAt;

  /// Constructor
  const GrupoRutaModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.codigoInvitacion,
    required this.creadoPor,
    this.activo = true,
    this.fotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una instancia desde JSON
  factory GrupoRutaModel.fromJson(Map<String, dynamic> json) {
    return GrupoRutaModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      codigoInvitacion: json['codigo_invitacion'] as String,
      creadoPor: json['creado_por'] as String,
      activo: json['activo'] as bool? ?? true,
      fotoUrl: json['foto_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'codigo_invitacion': codigoInvitacion,
      'creado_por': creadoPor,
      'activo': activo,
      'foto_url': fotoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  GrupoRutaModel copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? codigoInvitacion,
    String? creadoPor,
    bool? activo,
    String? fotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GrupoRutaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      codigoInvitacion: codigoInvitacion ?? this.codigoInvitacion,
      creadoPor: creadoPor ?? this.creadoPor,
      activo: activo ?? this.activo,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
