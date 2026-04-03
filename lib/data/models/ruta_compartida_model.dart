/// Modelo de Ruta Compartida
///
/// Representa una ruta compartida en el mapa.
/// Contiene las coordenadas del destino y metadata asociada.
library;

class RutaCompartidaModel {
  /// ID único de la ruta compartida (UUID de Supabase)
  final String id;

  /// ID de la sesión a la que pertenece
  final String sesionId;

  /// Latitud del destino
  final double destinoLat;

  /// Longitud del destino
  final double destinoLng;

  /// Nombre del destino (opcional)
  final String? destinoNombre;

  final String creadorId;
  final List<dynamic>? waypoints;
  final String? polyline;
  final double? distanciaTotal;
  final int? tiempoEstimado;

  /// ID del usuario que compartió la ruta
  final String? compartidaPor;

  /// Fecha de creación
  final DateTime? createdAt;

  /// Constructor
  const RutaCompartidaModel({
    required this.id,
    required this.sesionId,
    required this.destinoLat,
    required this.destinoLng,
    required this.creadorId,
    this.waypoints,
    this.polyline,
    this.distanciaTotal,
    this.tiempoEstimado,
    this.destinoNombre,
    this.compartidaPor,
    this.createdAt,
  });

  /// Crea una instancia desde JSON
  factory RutaCompartidaModel.fromJson(Map<String, dynamic> json) {
    return RutaCompartidaModel(
      id: json['id'] as String,
      sesionId: json['sesion_id'] as String,
      creadorId: json['creador_id'] as String? ?? '',
      destinoLat: (json['destino_lat'] as num).toDouble(),
      destinoLng: (json['destino_lng'] as num).toDouble(),
      destinoNombre: json['destino_nombre'] as String?,
      waypoints: json['waypoints'] as List<dynamic>?,
      polyline: json['polyline'] as String?,
      distanciaTotal: json['distancia_total'] != null ? (json['distancia_total'] as num).toDouble() : null,
      tiempoEstimado: json['tiempo_estimado'] as int?,
      compartidaPor: json['compartida_por'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_id': sesionId,
      'creador_id': creadorId,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'destino_nombre': destinoNombre,
      'waypoints': waypoints,
      'polyline': polyline,
      'distancia_total': distanciaTotal,
      'tiempo_estimado': tiempoEstimado,
      'compartida_por': compartidaPor,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  RutaCompartidaModel copyWith({
    String? id,
    String? sesionId,
    String? creadorId,
    double? destinoLat,
    double? destinoLng,
    String? destinoNombre,
    List<dynamic>? waypoints,
    String? polyline,
    double? distanciaTotal,
    int? tiempoEstimado,
    String? compartidaPor,
    DateTime? createdAt,
  }) {
    return RutaCompartidaModel(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      creadorId: creadorId ?? this.creadorId,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      destinoNombre: destinoNombre ?? this.destinoNombre,
      waypoints: waypoints ?? this.waypoints,
      polyline: polyline ?? this.polyline,
      distanciaTotal: distanciaTotal ?? this.distanciaTotal,
      tiempoEstimado: tiempoEstimado ?? this.tiempoEstimado,
      compartidaPor: compartidaPor ?? this.compartidaPor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}