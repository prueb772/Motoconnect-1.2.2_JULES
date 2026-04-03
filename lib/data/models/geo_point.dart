/// Modelo de punto geográfico tipado
///
/// Reemplaza el uso de Map<String, dynamic> con keys 'lat'/'lng'
/// en los campos puntoInicio, puntoFin y puntos de RutaRealizadaModel.
library;

class GeoPoint {
  /// Latitud
  final double lat;

  /// Longitud
  final double lng;

  const GeoPoint({
    required this.lat,
    required this.lng,
  });

  /// Crea una instancia desde JSON
  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }

  /// Crea una copia con campos modificados
  GeoPoint copyWith({
    double? lat,
    double? lng,
  }) {
    return GeoPoint(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  String toString() => 'GeoPoint(lat: $lat, lng: $lng)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;
}
