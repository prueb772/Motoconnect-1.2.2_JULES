/// Modelo de Ruta de Sesión Compartida
///
/// Representa una ruta compartida en una sesión grupal activa.
/// Contiene las coordenadas del destino y metadata asociada.
///
/// Reemplaza el uso de Map<String, dynamic> en:
/// - GrupoRepository.obtenerRutaCompartida
/// - GrupoRepository.streamRutaCompartida
library;

class RutaSesionModel {
  /// ID único de la ruta de sesión (UUID de Supabase)
  final String id;

  /// ID de la sesión a la que pertenece
  final String sesionId;

  /// Latitud del destino
  final double destinoLat;

  /// Longitud del destino
  final double destinoLng;

  /// Nombre del destino (opcional)
  final String? destinoNombre;

  /// ID del usuario que compartió la ruta
  final String compartidaPor;

  /// Fecha de creación
  final DateTime createdAt;

  /// Constructor
  const RutaSesionModel({
    required this.id,
    required this.sesionId,
    required this.destinoLat,
    required this.destinoLng,
    this.destinoNombre,
    required this.compartidaPor,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON
  factory RutaSesionModel.fromJson(Map<String, dynamic> json) {
    return RutaSesionModel(
      id: json['id'] as String,
      sesionId: json['sesion_id'] as String,
      destinoLat: (json['destino_lat'] as num).toDouble(),
      destinoLng: (json['destino_lng'] as num).toDouble(),
      destinoNombre: json['destino_nombre'] as String?,
      compartidaPor: json['compartida_por'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_id': sesionId,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'destino_nombre': destinoNombre,
      'compartida_por': compartidaPor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  RutaSesionModel copyWith({
    String? id,
    String? sesionId,
    double? destinoLat,
    double? destinoLng,
    String? destinoNombre,
    String? compartidaPor,
    DateTime? createdAt,
  }) {
    return RutaSesionModel(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      destinoNombre: destinoNombre ?? this.destinoNombre,
      compartidaPor: compartidaPor ?? this.compartidaPor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
