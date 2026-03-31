/// Modelo de Miembro de Grupo
///
/// Representa la relación entre un usuario y un grupo de rutas
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
library;

import 'user_model.dart';

class MiembroGrupoModel {
  /// ID único de la membresía (UUID de Supabase)
  final String id;

  /// ID del grupo
  final String grupoId;

  /// ID del usuario
  final String usuarioId;

  /// Indica si el usuario es administrador del grupo
  final bool esAdmin;

  /// Fecha de unión al grupo
  final DateTime fechaUnion;

  /// Fecha de creación del registro
  final DateTime createdAt;

  /// Información extendida del usuario (opcional, cuando se hace join)
  final UserModel? usuario;

  /// Constructor
  const MiembroGrupoModel({
    required this.id,
    required this.grupoId,
    required this.usuarioId,
    this.esAdmin = false,
    required this.fechaUnion,
    required this.createdAt,
    this.usuario,
  });

  /// Crea una instancia desde JSON
  factory MiembroGrupoModel.fromJson(Map<String, dynamic> json) {
    return MiembroGrupoModel(
      id: json['id'] as String,
      grupoId: json['grupo_id'] as String,
      usuarioId: json['usuario_id'] as String,
      esAdmin: json['es_admin'] as bool? ?? false,
      fechaUnion: DateTime.parse(json['fecha_union'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      usuario: json['usuarios'] != null
          ? UserModel.fromJson(json['usuarios'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'usuario_id': usuarioId,
      'es_admin': esAdmin,
      'fecha_union': fechaUnion.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (usuario != null) 'usuarios': usuario!.toJson(),
    };
  }

  /// Crea una copia con campos modificados
  MiembroGrupoModel copyWith({
    String? id,
    String? grupoId,
    String? usuarioId,
    bool? esAdmin,
    DateTime? fechaUnion,
    DateTime? createdAt,
    UserModel? usuario,
  }) {
    return MiembroGrupoModel(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      usuarioId: usuarioId ?? this.usuarioId,
      esAdmin: esAdmin ?? this.esAdmin,
      fechaUnion: fechaUnion ?? this.fechaUnion,
      createdAt: createdAt ?? this.createdAt,
      usuario: usuario ?? this.usuario,
    );
  }

  /// Getters de conveniencia
  String? get nombreUsuario => usuario?.nombre;
  String? get apodoUsuario => usuario?.apodo;
  String? get fotoPerfilUsuario => usuario?.fotoPerfil;
}
