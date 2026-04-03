/// Modelo de Participante de Evento
///
/// Representa la participación de un usuario en un evento
/// con su estado de asistencia y información del usuario
library;

import 'user_model.dart';

/// Enum para los estados de asistencia
enum EstadoAsistencia {
  confirmado,
  posible,
  noAsiste;

  /// Convierte el enum a string para Supabase
  String toStringValue() {
    switch (this) {
      case EstadoAsistencia.confirmado:
        return 'confirmado';
      case EstadoAsistencia.posible:
        return 'posible';
      case EstadoAsistencia.noAsiste:
        return 'no_asiste';
    }
  }

  /// Crea el enum desde un string de Supabase
  static EstadoAsistencia fromString(String value) {
    switch (value) {
      case 'confirmado':
        return EstadoAsistencia.confirmado;
      case 'posible':
        return EstadoAsistencia.posible;
      case 'no_asiste':
        return EstadoAsistencia.noAsiste;
      default:
        return EstadoAsistencia.posible;
    }
  }

  /// Obtiene el texto para mostrar
  String get displayText {
    switch (this) {
      case EstadoAsistencia.confirmado:
        return 'Confirmado';
      case EstadoAsistencia.posible:
        return 'Posible';
      case EstadoAsistencia.noAsiste:
        return 'No asiste';
    }
  }

  /// Obtiene el color asociado
  String get colorHex {
    switch (this) {
      case EstadoAsistencia.confirmado:
        return '#4CAF50'; // Verde
      case EstadoAsistencia.posible:
        return '#FF9800'; // Naranja
      case EstadoAsistencia.noAsiste:
        return '#F44336'; // Rojo
    }
  }
}

class EventParticipantModel {
  /// ID único del registro
  final String id;

  /// ID del evento
  final String eventoId;

  /// ID del usuario
  final String usuarioId;

  /// Estado de asistencia
  final EstadoAsistencia estado;

  /// Fecha de registro
  final DateTime fechaRegistro;

  /// Información del usuario (opcional, viene del join)
  final UserModel? usuario;

  /// Nombre del grupo del usuario (si pertenece a alguno)
  final String? grupoNombre;

  /// Constructor
  const EventParticipantModel({
    required this.id,
    required this.eventoId,
    required this.usuarioId,
    required this.estado,
    required this.fechaRegistro,
    this.usuario,
    this.grupoNombre,
  });

  /// Crea una instancia desde JSON
  factory EventParticipantModel.fromJson(Map<String, dynamic> json) {
    return EventParticipantModel(
      id: json['id'] as String,
      eventoId: json['evento_id'] as String,
      usuarioId: json['usuario_id'] as String,
      estado: EstadoAsistencia.fromString(
        json['estado'] as String? ?? 'posible',
      ),
      fechaRegistro: json['fecha_registro'] != null
          ? DateTime.parse(json['fecha_registro'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      usuario: json['usuarios'] != null
          ? UserModel.fromJson(json['usuarios'] as Map<String, dynamic>)
          : null,
      grupoNombre: json['grupo_nombre'] as String?,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'evento_id': eventoId,
      'usuario_id': usuarioId,
      'estado': estado.toStringValue(),
      'fecha_registro': fechaRegistro.toIso8601String(),
      if (usuario != null) 'usuarios': usuario!.toJson(),
      if (grupoNombre != null) 'grupo_nombre': grupoNombre,
    };
  }

  /// Crea una copia con campos modificados
  EventParticipantModel copyWith({
    String? id,
    String? eventoId,
    String? usuarioId,
    EstadoAsistencia? estado,
    DateTime? fechaRegistro,
    UserModel? usuario,
    String? grupoNombre,
  }) {
    return EventParticipantModel(
      id: id ?? this.id,
      eventoId: eventoId ?? this.eventoId,
      usuarioId: usuarioId ?? this.usuarioId,
      estado: estado ?? this.estado,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      usuario: usuario ?? this.usuario,
      grupoNombre: grupoNombre ?? this.grupoNombre,
    );
  }

  /// Obtiene el nombre para mostrar (apodo o nombre)
  String get displayName {
    if (usuario == null) return 'Usuario';
    return usuario!.apodo ?? usuario!.nombre;
  }

  /// Obtiene el texto del grupo para mostrar
  String get grupoDisplay {
    return grupoNombre ?? 'Sin grupo';
  }
}
