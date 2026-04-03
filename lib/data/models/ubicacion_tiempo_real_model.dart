/// Modelo de Ubicación en Tiempo Real
///
/// Representa la ubicación de un usuario durante una sesión de ruta activa
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class UbicacionTiempoRealModel {
  /// ID único de la ubicación (UUID de Supabase)
  final String id;

  /// ID de la sesión activa
  final String sesionId;

  /// ID del usuario
  final String usuarioId;

  /// Latitud
  final double latitud;

  /// Longitud
  final double longitud;

  /// Velocidad en km/h (opcional)
  final double? velocidad;

  /// Dirección en grados (0-360) (opcional)
  final double? direccion;

  /// Altitud en metros (opcional)
  final double? altitud;

  /// Precisión de la ubicación en metros (opcional)
  final double? precisionMetros;

  /// Fecha y hora de la última actualización
  final DateTime ultimaActualizacion;

  /// Fecha de creación
  final DateTime createdAt;

  /// Nombre del usuario (cuando se hace join con usuarios)
  final String? nombreUsuario;

  /// Apodo del usuario (cuando se hace join con usuarios)
  final String? apodoUsuario;

  /// URL de foto de perfil del usuario (cuando se hace join con usuarios)
  final String? fotoPerfilUsuario;

  /// Constructor
  const UbicacionTiempoRealModel({
    required this.id,
    required this.sesionId,
    required this.usuarioId,
    required this.latitud,
    required this.longitud,
    this.velocidad,
    this.direccion,
    this.altitud,
    this.precisionMetros,
    required this.ultimaActualizacion,
    required this.createdAt,
    this.nombreUsuario,
    this.apodoUsuario,
    this.fotoPerfilUsuario,
  });

  /// Crea una instancia desde JSON
  factory UbicacionTiempoRealModel.fromJson(Map<String, dynamic> json) {
    return UbicacionTiempoRealModel(
      id: json['id'] as String,
      sesionId: json['sesion_id'] as String,
      usuarioId: json['usuario_id'] as String,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      velocidad: json['velocidad'] != null
          ? (json['velocidad'] as num).toDouble()
          : null,
      direccion: json['direccion'] != null
          ? (json['direccion'] as num).toDouble()
          : null,
      altitud:
          json['altitud'] != null ? (json['altitud'] as num).toDouble() : null,
      precisionMetros: json['precision_metros'] != null
          ? (json['precision_metros'] as num).toDouble()
          : null,
      ultimaActualizacion:
          DateTime.parse(json['ultima_actualizacion'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      nombreUsuario: json['nombre'] as String?,
      apodoUsuario: json['apodo'] as String?,
      fotoPerfilUsuario: json['foto_perfil_url'] as String?,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_id': sesionId,
      'usuario_id': usuarioId,
      'latitud': latitud,
      'longitud': longitud,
      'velocidad': velocidad,
      'direccion': direccion,
      'altitud': altitud,
      'precision_metros': precisionMetros,
      'ultima_actualizacion': ultimaActualizacion.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (nombreUsuario != null) 'nombre': nombreUsuario,
      if (apodoUsuario != null) 'apodo': apodoUsuario,
      if (fotoPerfilUsuario != null) 'foto_perfil_url': fotoPerfilUsuario,
    };
  }

  /// Crea una copia con campos modificados
  UbicacionTiempoRealModel copyWith({
    String? id,
    String? sesionId,
    String? usuarioId,
    double? latitud,
    double? longitud,
    double? velocidad,
    double? direccion,
    double? altitud,
    double? precisionMetros,
    DateTime? ultimaActualizacion,
    DateTime? createdAt,
    String? nombreUsuario,
    String? apodoUsuario,
    String? fotoPerfilUsuario,
  }) {
    return UbicacionTiempoRealModel(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      usuarioId: usuarioId ?? this.usuarioId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      velocidad: velocidad ?? this.velocidad,
      direccion: direccion ?? this.direccion,
      altitud: altitud ?? this.altitud,
      precisionMetros: precisionMetros ?? this.precisionMetros,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      createdAt: createdAt ?? this.createdAt,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      apodoUsuario: apodoUsuario ?? this.apodoUsuario,
      fotoPerfilUsuario: fotoPerfilUsuario ?? this.fotoPerfilUsuario,
    );
  }

  /// Convierte a LatLng de Google Maps
  LatLng get posicion => LatLng(latitud, longitud);

  /// Obtiene el nombre a mostrar (prioriza apodo sobre nombre)
  String get nombreMostrar => apodoUsuario ?? nombreUsuario ?? 'Usuario';

  /// Verifica si la ubicación es reciente (menos de 1 minuto)
  bool get esReciente {
    final diferencia = DateTime.now().difference(ultimaActualizacion);
    return diferencia.inMinutes < 1;
  }

  /// Verifica si la ubicación está obsoleta (más de 5 minutos)
  bool get esObsoleta {
    final diferencia = DateTime.now().difference(ultimaActualizacion);
    return diferencia.inMinutes > 5;
  }

  /// Obtiene el tiempo transcurrido desde la última actualización
  String get tiempoTranscurrido {
    final diferencia = DateTime.now().difference(ultimaActualizacion);

    if (diferencia.inSeconds < 60) {
      return 'Hace ${diferencia.inSeconds}s';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes}m';
    } else {
      return 'Hace ${diferencia.inHours}h';
    }
  }
}
