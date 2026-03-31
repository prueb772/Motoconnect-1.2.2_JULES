/// Modelos para parsear la respuesta de Google Directions API
///
/// Estructura de la API:
/// DirectionsResponse
///   └─ routes: List<DirectionsRoute>
///       └─ legs: List<DirectionsLeg>
///           └─ steps: List<DirectionsStep>
///
/// Documentación: https://developers.google.com/maps/documentation/directions/get-directions
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'navigation_step.dart';
import 'package:uuid/uuid.dart';

// ========================================
// RESPONSE PRINCIPAL
// ========================================

/// Respuesta completa de Google Directions API
class DirectionsResponse {
  /// Lista de rutas posibles
  final List<DirectionsRoute> routes;

  /// Estado de la respuesta ("OK", "NOT_FOUND", "ZERO_RESULTS", etc.)
  final String status;

  /// Mensaje de error (si hay)
  final String? errorMessage;

  const DirectionsResponse({
    required this.routes,
    required this.status,
    this.errorMessage,
  });

  factory DirectionsResponse.fromJson(Map<String, dynamic> json) {
    final routesJson = json['routes'] as List?;
    final routes = routesJson
            ?.map((route) =>
                DirectionsRoute.fromJson(route as Map<String, dynamic>))
            .toList() ??
        [];

    return DirectionsResponse(
      routes: routes,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Verifica si la respuesta es exitosa
  bool get isSuccess => status == 'OK' && routes.isNotEmpty;

  /// Obtiene la primera ruta (principal)
  DirectionsRoute? get primaryRoute =>
      routes.isNotEmpty ? routes.first : null;
}

// ========================================
// ROUTE
// ========================================

/// Ruta individual de Directions API
class DirectionsRoute {
  /// Legs de la ruta (segmentos entre waypoints)
  final List<DirectionsLeg> legs;

  /// Polyline codificada de toda la ruta
  final String polylineEncoded;

  /// Bounds de la ruta (para ajustar cámara)
  final DirectionsBounds bounds;

  /// Resumen de la ruta (ej: "Autopista Norte")
  final String? summary;

  const DirectionsRoute({
    required this.legs,
    required this.polylineEncoded,
    required this.bounds,
    this.summary,
  });

  factory DirectionsRoute.fromJson(Map<String, dynamic> json) {
    final legsJson = json['legs'] as List?;
    final legs = legsJson
            ?.map(
                (leg) => DirectionsLeg.fromJson(leg as Map<String, dynamic>))
            .toList() ??
        [];

    final polylineJson = json['overview_polyline'] as Map<String, dynamic>?;
    final polylineEncoded = polylineJson?['points'] as String? ?? '';

    final boundsJson = json['bounds'] as Map<String, dynamic>?;
    final bounds = boundsJson != null
        ? DirectionsBounds.fromJson(boundsJson)
        : DirectionsBounds(
            northeast: const LatLng(0, 0),
            southwest: const LatLng(0, 0),
          );

    return DirectionsRoute(
      legs: legs,
      polylineEncoded: polylineEncoded,
      bounds: bounds,
      summary: json['summary'] as String?,
    );
  }

  /// Obtiene el primer leg (principal)
  DirectionsLeg? get primaryLeg => legs.isNotEmpty ? legs.first : null;

  /// Distancia total de la ruta
  int get totalDistanceMeters {
    return legs.fold<int>(
      0,
      (sum, leg) => sum + leg.distance.value,
    );
  }

  /// Duración total de la ruta
  int get totalDurationSeconds {
    return legs.fold<int>(
      0,
      (sum, leg) => sum + leg.duration.value,
    );
  }
}

// ========================================
// LEG
// ========================================

/// Segmento de ruta (entre dos waypoints)
class DirectionsLeg {
  /// Distancia del leg
  final DirectionsValue distance;

  /// Duración del leg
  final DirectionsValue duration;

  /// Ubicación de inicio
  final LatLng startLocation;

  /// Ubicación de fin
  final LatLng endLocation;

  /// Dirección de inicio
  final String startAddress;

  /// Dirección de fin
  final String endAddress;

  /// Steps individuales del leg
  final List<DirectionsStep> steps;

  const DirectionsLeg({
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
  });

  factory DirectionsLeg.fromJson(Map<String, dynamic> json) {
    final distanceJson = json['distance'] as Map<String, dynamic>?;
    final distance = distanceJson != null
        ? DirectionsValue.fromJson(distanceJson)
        : const DirectionsValue(value: 0, text: '0 m');

    final durationJson = json['duration'] as Map<String, dynamic>?;
    final duration = durationJson != null
        ? DirectionsValue.fromJson(durationJson)
        : const DirectionsValue(value: 0, text: '0 min');

    final startLocJson = json['start_location'] as Map<String, dynamic>?;
    final startLocation = startLocJson != null
        ? LatLng(
            startLocJson['lat'] as double,
            startLocJson['lng'] as double,
          )
        : const LatLng(0, 0);

    final endLocJson = json['end_location'] as Map<String, dynamic>?;
    final endLocation = endLocJson != null
        ? LatLng(
            endLocJson['lat'] as double,
            endLocJson['lng'] as double,
          )
        : const LatLng(0, 0);

    final stepsJson = json['steps'] as List?;
    final steps = stepsJson
            ?.map(
                (step) => DirectionsStep.fromJson(step as Map<String, dynamic>))
            .toList() ??
        [];

    return DirectionsLeg(
      distance: distance,
      duration: duration,
      startLocation: startLocation,
      endLocation: endLocation,
      startAddress: json['start_address'] as String? ?? '',
      endAddress: json['end_address'] as String? ?? '',
      steps: steps,
    );
  }
}

// ========================================
// STEP
// ========================================

/// Paso individual de navegación de la API
class DirectionsStep {
  /// Distancia del paso
  final DirectionsValue distance;

  /// Duración del paso
  final DirectionsValue duration;

  /// Ubicación de inicio
  final LatLng startLocation;

  /// Ubicación de fin
  final LatLng endLocation;

  /// Instrucciones en HTML (ej: "Gira a la <b>derecha</b>...")
  final String htmlInstructions;

  /// Tipo de maniobra (ej: "turn-right", "turn-left")
  final String? maneuver;

  /// Polyline codificada del paso
  final String polylineEncoded;

  /// Modo de viaje (driving, walking, bicycling, transit)
  final String travelMode;

  const DirectionsStep({
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.htmlInstructions,
    this.maneuver,
    required this.polylineEncoded,
    this.travelMode = 'DRIVING',
  });

  factory DirectionsStep.fromJson(Map<String, dynamic> json) {
    final distanceJson = json['distance'] as Map<String, dynamic>?;
    final distance = distanceJson != null
        ? DirectionsValue.fromJson(distanceJson)
        : const DirectionsValue(value: 0, text: '0 m');

    final durationJson = json['duration'] as Map<String, dynamic>?;
    final duration = durationJson != null
        ? DirectionsValue.fromJson(durationJson)
        : const DirectionsValue(value: 0, text: '0 min');

    final startLocJson = json['start_location'] as Map<String, dynamic>?;
    final startLocation = startLocJson != null
        ? LatLng(
            startLocJson['lat'] as double,
            startLocJson['lng'] as double,
          )
        : const LatLng(0, 0);

    final endLocJson = json['end_location'] as Map<String, dynamic>?;
    final endLocation = endLocJson != null
        ? LatLng(
            endLocJson['lat'] as double,
            endLocJson['lng'] as double,
          )
        : const LatLng(0, 0);

    final polylineJson = json['polyline'] as Map<String, dynamic>?;
    final polylineEncoded = polylineJson?['points'] as String? ?? '';

    return DirectionsStep(
      distance: distance,
      duration: duration,
      startLocation: startLocation,
      endLocation: endLocation,
      htmlInstructions: json['html_instructions'] as String? ?? '',
      maneuver: json['maneuver'] as String?,
      polylineEncoded: polylineEncoded,
      travelMode: json['travel_mode'] as String? ?? 'DRIVING',
    );
  }

  /// Convierte DirectionsStep a NavigationStep
  NavigationStep toNavigationStep(List<LatLng> decodedPolyline) {
    const uuid = Uuid();
    return NavigationStep(
      id: uuid.v4(),
      startLocation: startLocation,
      endLocation: endLocation,
      instruction: _stripHtml(htmlInstructions),
      maneuver: maneuver ?? 'straight',
      distanceMeters: distance.value.toDouble(),
      durationSeconds: duration.value,
      polylinePoints: decodedPolyline,
    );
  }

  /// Elimina tags HTML de las instrucciones
  String _stripHtml(String html) {
    final regex = RegExp(r'<[^>]*>');
    return html.replaceAll(regex, '').trim();
  }
}

// ========================================
// VALUE (Distance/Duration)
// ========================================

/// Valor con unidad (distancia o duración)
class DirectionsValue {
  /// Valor numérico (metros para distancia, segundos para duración)
  final int value;

  /// Texto formateado (ej: "1.5 km", "5 mins")
  final String text;

  const DirectionsValue({
    required this.value,
    required this.text,
  });

  factory DirectionsValue.fromJson(Map<String, dynamic> json) {
    return DirectionsValue(
      value: json['value'] as int,
      text: json['text'] as String,
    );
  }
}

// ========================================
// BOUNDS
// ========================================

/// Límites geográficos de la ruta
class DirectionsBounds {
  /// Esquina noreste
  final LatLng northeast;

  /// Esquina suroeste
  final LatLng southwest;

  const DirectionsBounds({
    required this.northeast,
    required this.southwest,
  });

  factory DirectionsBounds.fromJson(Map<String, dynamic> json) {
    final neJson = json['northeast'] as Map<String, dynamic>?;
    final northeast = neJson != null
        ? LatLng(
            neJson['lat'] as double,
            neJson['lng'] as double,
          )
        : const LatLng(0, 0);

    final swJson = json['southwest'] as Map<String, dynamic>?;
    final southwest = swJson != null
        ? LatLng(
            swJson['lat'] as double,
            swJson['lng'] as double,
          )
        : const LatLng(0, 0);

    return DirectionsBounds(
      northeast: northeast,
      southwest: southwest,
    );
  }

  /// Convierte a LatLngBounds de Google Maps
  LatLngBounds toLatLngBounds() {
    return LatLngBounds(
      southwest: southwest,
      northeast: northeast,
    );
  }
}
