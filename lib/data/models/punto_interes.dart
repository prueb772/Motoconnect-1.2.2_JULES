/// Modelo de Punto de Interés tipado
///
/// Reemplaza el uso de List<dynamic> para puntosInteres
/// en RutaRealizadaModel. Los campos se basan en el esquema
/// de la tabla rutas_realizadas donde puntosInteres es un JSON array
/// con elementos que contienen nombre, descripción y coordenadas.
library;

import 'geo_point.dart';

class PuntoInteres {
  /// Nombre del punto de interés
  final String? nombre;

  /// Descripción del punto de interés
  final String? descripcion;

  /// Ubicación del punto de interés
  final GeoPoint? ubicacion;

  const PuntoInteres({
    this.nombre,
    this.descripcion,
    this.ubicacion,
  });

  /// Crea una instancia desde JSON
  factory PuntoInteres.fromJson(Map<String, dynamic> json) {
    return PuntoInteres(
      nombre: json['nombre'] as String?,
      descripcion: json['descripcion'] as String?,
      ubicacion: json['lat'] != null && json['lng'] != null
          ? GeoPoint(
              lat: (json['lat'] as num).toDouble(),
              lng: (json['lng'] as num).toDouble(),
            )
          : json['ubicacion'] != null
              ? GeoPoint.fromJson(json['ubicacion'] as Map<String, dynamic>)
              : null,
    );
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (nombre != null) json['nombre'] = nombre;
    if (descripcion != null) json['descripcion'] = descripcion;
    if (ubicacion != null) {
      json['lat'] = ubicacion!.lat;
      json['lng'] = ubicacion!.lng;
    }
    return json;
  }

  /// Crea una copia con campos modificados
  PuntoInteres copyWith({
    String? nombre,
    String? descripcion,
    GeoPoint? ubicacion,
  }) {
    return PuntoInteres(
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      ubicacion: ubicacion ?? this.ubicacion,
    );
  }
}
