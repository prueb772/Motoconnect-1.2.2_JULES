/// Modelo de Ruta Realizada
///
/// Representa una ruta guardada o realizada por un usuario.
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - copyWith para copias modificadas
library;

import 'geo_point.dart';
import 'punto_interes.dart';

class RutaRealizadaModel {
  /// ID único de la ruta (UUID de Supabase)
  final String id;

  /// ID del usuario propietario de la ruta
  final String usuarioId;

  /// Nombre de la ruta
  final String nombreRuta;

  /// Descripción de la ruta (opcional)
  final String? descripcionRuta;

  /// Fecha de la ruta
  final DateTime fecha;

  /// Lista de puntos GPS de la ruta
  final List<GeoPoint> puntos;

  /// Distancia recorrida en kilómetros
  final double distanciaKm;

  /// Duración en minutos
  final int duracionMinutos;

  /// URL de imagen de la ruta (opcional)
  final String? imagenUrl;

  /// Punto de inicio de la ruta (opcional)
  final GeoPoint? puntoInicio;

  /// Punto de fin de la ruta (opcional)
  final GeoPoint? puntoFin;

  /// Tipo de vía (opcional)
  final String? tipoVia;

  /// Valor paisajístico (opcional)
  final int? valorPaisajistico;

  /// Puntos de interés (opcional)
  final List<PuntoInteres>? puntosInteres;

  /// Tipo de ruta: 'planificada' o 'realizada'
  final String tipo;

  /// Estado de la ruta (opcional)
  final String? estado;

  /// Fecha de creación del registro
  final DateTime createdAt;

  /// Fecha de última actualización del registro
  final DateTime updatedAt;

  /// Constructor
  const RutaRealizadaModel({
    required this.id,
    required this.usuarioId,
    required this.nombreRuta,
    this.descripcionRuta,
    required this.fecha,
    this.puntos = const [],
    this.distanciaKm = 0.0,
    this.duracionMinutos = 0,
    this.imagenUrl,
    this.puntoInicio,
    this.puntoFin,
    this.tipoVia,
    this.valorPaisajistico,
    this.puntosInteres,
    this.tipo = 'planificada',
    this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una instancia desde JSON (respuesta de Supabase)
  factory RutaRealizadaModel.fromJson(Map<String, dynamic> json) {
    return RutaRealizadaModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      nombreRuta: json['nombre_ruta'] as String,
      descripcionRuta: json['descripcion_ruta'] as String?,
      fecha: DateTime.parse(json['fecha'] as String),
      puntos: _parsePuntos(json['puntos']),
      distanciaKm: (json['distancia_km'] as num?)?.toDouble() ?? 0.0,
      duracionMinutos: json['duracion_minutos'] as int? ?? 0,
      imagenUrl: json['imagen_url'] as String?,
      puntoInicio: json['punto_inicio'] != null
          ? GeoPoint.fromJson(json['punto_inicio'] as Map<String, dynamic>)
          : null,
      puntoFin: json['punto_fin'] != null
          ? GeoPoint.fromJson(json['punto_fin'] as Map<String, dynamic>)
          : null,
      tipoVia: json['tipo_via'] as String?,
      valorPaisajistico: json['valor_paisajistico'] as int?,
      puntosInteres: _parsePuntosInteres(json['puntos_interes']),
      tipo: json['tipo'] as String? ?? 'planificada',
      estado: json['estado'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Parsea la lista de puntos GPS desde JSON
  static List<GeoPoint> _parsePuntos(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => GeoPoint.fromJson(json))
        .toList();
  }

  /// Parsea la lista de puntos de interés desde JSON
  static List<PuntoInteres>? _parsePuntosInteres(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => PuntoInteres.fromJson(json))
        .toList();
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre_ruta': nombreRuta,
      'descripcion_ruta': descripcionRuta,
      'fecha': fecha.toIso8601String(),
      'puntos': puntos.map((p) => p.toJson()).toList(),
      'distancia_km': distanciaKm,
      'duracion_minutos': duracionMinutos,
      'imagen_url': imagenUrl,
      'punto_inicio': puntoInicio?.toJson(),
      'punto_fin': puntoFin?.toJson(),
      'tipo_via': tipoVia,
      'valor_paisajistico': valorPaisajistico,
      'puntos_interes': puntosInteres?.map((p) => p.toJson()).toList(),
      'tipo': tipo,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  RutaRealizadaModel copyWith({
    String? id,
    String? usuarioId,
    String? nombreRuta,
    String? descripcionRuta,
    DateTime? fecha,
    List<GeoPoint>? puntos,
    double? distanciaKm,
    int? duracionMinutos,
    String? imagenUrl,
    GeoPoint? puntoInicio,
    GeoPoint? puntoFin,
    String? tipoVia,
    int? valorPaisajistico,
    List<PuntoInteres>? puntosInteres,
    String? tipo,
    String? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RutaRealizadaModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombreRuta: nombreRuta ?? this.nombreRuta,
      descripcionRuta: descripcionRuta ?? this.descripcionRuta,
      fecha: fecha ?? this.fecha,
      puntos: puntos ?? this.puntos,
      distanciaKm: distanciaKm ?? this.distanciaKm,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      puntoInicio: puntoInicio ?? this.puntoInicio,
      puntoFin: puntoFin ?? this.puntoFin,
      tipoVia: tipoVia ?? this.tipoVia,
      valorPaisajistico: valorPaisajistico ?? this.valorPaisajistico,
      puntosInteres: puntosInteres ?? this.puntosInteres,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
