/// Modelo de Paso de Navegación
///
/// Representa un paso individual de navegación turn-by-turn
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - Getters calculados para UI
library;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationStep {
  /// ID único del paso
  final String id;

  /// Ubicación de inicio del paso
  final LatLng startLocation;

  /// Ubicación de fin del paso
  final LatLng endLocation;

  /// Instrucción en texto ("Gira a la derecha en Calle 45")
  final String instruction;

  /// Tipo de maniobra ("turn-right", "turn-left", "straight", etc.)
  final String maneuver;

  /// Distancia del paso en metros
  final double distanceMeters;

  /// Duración estimada del paso en segundos
  final int durationSeconds;

  /// Puntos GPS detallados del paso (polyline)
  final List<LatLng> polylinePoints;

  /// Constructor
  const NavigationStep({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polylinePoints,
  });

  /// Crea una instancia desde JSON
  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    // Parsear polyline points
    final polylineJson = json['polyline_points'] as List?;
    final polylinePoints = polylineJson?.map((point) {
          return LatLng(
            point['lat'] as double,
            point['lng'] as double,
          );
        }).toList() ??
        [];

    return NavigationStep(
      id: json['id'] as String,
      startLocation: LatLng(
        json['start_lat'] as double,
        json['start_lng'] as double,
      ),
      endLocation: LatLng(
        json['end_lat'] as double,
        json['end_lng'] as double,
      ),
      instruction: json['instruction'] as String,
      maneuver: json['maneuver'] as String? ?? 'straight',
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      polylinePoints: polylinePoints,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_lat': startLocation.latitude,
      'start_lng': startLocation.longitude,
      'end_lat': endLocation.latitude,
      'end_lng': endLocation.longitude,
      'instruction': instruction,
      'maneuver': maneuver,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'polyline_points': polylinePoints
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList(),
    };
  }

  /// Crea una copia con campos modificados
  NavigationStep copyWith({
    String? id,
    LatLng? startLocation,
    LatLng? endLocation,
    String? instruction,
    String? maneuver,
    double? distanceMeters,
    int? durationSeconds,
    List<LatLng>? polylinePoints,
  }) {
    return NavigationStep(
      id: id ?? this.id,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      instruction: instruction ?? this.instruction,
      maneuver: maneuver ?? this.maneuver,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polylinePoints: polylinePoints ?? this.polylinePoints,
    );
  }

  // ========================================
  // GETTERS CALCULADOS PARA UI
  // ========================================

  /// Instrucción lista para mostrar en UI: sin HTML y con abreviaciones expandidas.
  ///
  /// Google Directions API puede devolver HTML y abreviaciones colombianas
  /// ("Cra.", "Cll.", etc.) aunque se solicite en español. Este getter
  /// normaliza el texto antes de mostrarlo en pantalla.
  String get displayInstruction => _expandAbbreviations(_removeHtmlTags(instruction));

  String _removeHtmlTags(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', 'y')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  String _expandAbbreviations(String text) => text
      .replaceAll(RegExp(r'\bCra\.?\s*', caseSensitive: false), 'Carrera ')
      .replaceAll(RegExp(r'\bCll\.?\s*', caseSensitive: false), 'Calle ')
      .replaceAll(RegExp(r'\bCl\.?\s*', caseSensitive: false), 'Calle ')
      .replaceAll(RegExp(r'\bKr\.?\s*', caseSensitive: false), 'Carrera ')
      .replaceAll(RegExp(r'\bAv\.?\s*', caseSensitive: false), 'Avenida ')
      .replaceAll(RegExp(r'\bDg\.?\s*', caseSensitive: false), 'Diagonal ')
      .replaceAll(RegExp(r'\bTv\.?\s*', caseSensitive: false), 'Transversal ')
      .replaceAll(RegExp(r'\bKm\.?\s*', caseSensitive: false), 'kilómetro ')
      .replaceAll(RegExp(r'\bNro\.?\s*', caseSensitive: false), 'número ')
      .trim();

  /// Texto formateado de distancia
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Texto formateado de duración
  String get durationText {
    final mins = (durationSeconds / 60).ceil();
    if (mins < 60) {
      return '$mins min';
    }
    final hours = (mins / 60).floor();
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}min';
  }

  /// Icono de maniobra para UI
  IconData get maneuverIcon {
    switch (maneuver.toLowerCase()) {
      case 'turn-right':
      case 'ramp-right':
        return Icons.turn_right;
      case 'turn-left':
      case 'ramp-left':
        return Icons.turn_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_right;
      case 'straight':
        return Icons.arrow_upward;
      case 'merge':
        return Icons.merge;
      case 'fork-left':
      case 'fork-right':
        return Icons.alt_route;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.album_outlined;
      default:
        return Icons.navigation;
    }
  }

  /// Descripción de la maniobra en español
  String get maneuverDescription {
    switch (maneuver.toLowerCase()) {
      case 'turn-right':
        return 'Gira a la derecha';
      case 'turn-left':
        return 'Gira a la izquierda';
      case 'turn-slight-right':
        return 'Gira ligeramente a la derecha';
      case 'turn-slight-left':
        return 'Gira ligeramente a la izquierda';
      case 'turn-sharp-right':
        return 'Gira bruscamente a la derecha';
      case 'turn-sharp-left':
        return 'Gira bruscamente a la izquierda';
      case 'uturn-right':
      case 'uturn-left':
        return 'Da la vuelta';
      case 'straight':
        return 'Continúa recto';
      case 'merge':
        return 'Incorpórate';
      case 'fork-left':
        return 'Toma el desvío izquierdo';
      case 'fork-right':
        return 'Toma el desvío derecho';
      case 'ramp-left':
        return 'Toma la rampa izquierda';
      case 'ramp-right':
        return 'Toma la rampa derecha';
      case 'roundabout-left':
      case 'roundabout-right':
        return 'Entra en la rotonda';
      default:
        return 'Continúa';
    }
  }

  @override
  String toString() {
    return 'NavigationStep(id: $id, instruction: $instruction, '
        'distance: $distanceText, duration: $durationText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationStep && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
