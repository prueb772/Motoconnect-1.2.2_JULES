/// Modelo de Usuario Bloqueado de Grupo
///
/// Representa un registro de bloqueo de usuario en un grupo
library;

/// Motivos de bloqueo
enum MotivoBloqueo {
  expulsado,  // Expulsado por admin
  abandono;   // Abandonó voluntariamente

  String toStringValue() {
    return name;
  }

  static MotivoBloqueo fromString(String value) {
    switch (value.toLowerCase()) {
      case 'expulsado':
        return MotivoBloqueo.expulsado;
      case 'abandono':
        return MotivoBloqueo.abandono;
      default:
        return MotivoBloqueo.abandono;
    }
  }

  /// Etiqueta legible para mostrar en UI
  String get etiqueta {
    switch (this) {
      case MotivoBloqueo.expulsado:
        return 'Expulsado';
      case MotivoBloqueo.abandono:
        return 'Abandonó';
    }
  }
}

class UsuarioBloqueadoGrupoModel {
  final String id;
  final String grupoId;
  final String usuarioId;
  final String? bloqueadoPor;
  final MotivoBloqueo motivo;
  final DateTime fechaBloqueo;
  final DateTime createdAt;

  const UsuarioBloqueadoGrupoModel({
    required this.id,
    required this.grupoId,
    required this.usuarioId,
    this.bloqueadoPor,
    required this.motivo,
    required this.fechaBloqueo,
    required this.createdAt,
  });

  /// Indica si fue expulsado por admin
  bool get fueExpulsado => motivo == MotivoBloqueo.expulsado;

  /// Indica si abandonó voluntariamente
  bool get abandono => motivo == MotivoBloqueo.abandono;

  /// Factory desde JSON
  factory UsuarioBloqueadoGrupoModel.fromJson(Map<String, dynamic> json) {
    return UsuarioBloqueadoGrupoModel(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      usuarioId: json['usuario_id'] as String,
      bloqueadoPor: json['bloqueado_por'] as String?,
      motivo: MotivoBloqueo.fromString(
        json['motivo'] as String? ?? 'abandono',
      ),
      fechaBloqueo: DateTime.parse(json['fecha_bloqueo'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'usuario_id': usuarioId,
      'bloqueado_por': bloqueadoPor,
      'motivo': motivo.toStringValue(),
      'fecha_bloqueo': fechaBloqueo.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UsuarioBloqueadoGrupoModel('
        'id: $id, '
        'grupoId: $grupoId, '
        'usuarioId: $usuarioId, '
        'motivo: ${motivo.name}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioBloqueadoGrupoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
