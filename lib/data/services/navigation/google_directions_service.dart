/// Servicio de Google Directions API
///
/// Responsabilidades:
/// - Llamadas directas HTTP a Google Directions API REST
/// - Reemplaza flutter_polyline_points para obtener steps completos
/// - Decodifica polylines
/// - Manejo de errores de API
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/directions_response.dart';
import '../../models/navigation_step.dart';

class GoogleDirectionsService {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  /// API Key de Google Maps
  final String apiKey;

  /// Cliente HTTP (inyectable para testing)
  final http.Client _httpClient;

  // ========================================
  // CONSTANTES
  // ========================================

  /// URL base de Google Directions API
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  // ========================================
  // CONSTRUCTOR
  // ========================================

  GoogleDirectionsService({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  /// Obtiene direcciones completas desde la API de Google
  ///
  /// [origin] - Ubicación de origen
  /// [destination] - Ubicación de destino
  /// [waypoints] - Puntos intermedios opcionales
  /// [mode] - Modo de transporte: 'driving', 'walking', 'bicycling', 'transit'
  /// [alternatives] - Si debe retornar rutas alternativas
  /// [avoidTolls] - Evitar peajes
  /// [avoidHighways] - Evitar autopistas
  /// [avoidFerries] - Evitar ferries
  ///
  /// Retorna:
  /// - DirectionsResponse con rutas, legs y steps completos
  ///
  /// Lanza:
  /// - Exception si hay error de red o API
  Future<DirectionsResponse> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    String mode = 'driving',
    bool alternatives = false,
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = false,
  }) async {
    try {
      // Construir parámetros de la petición
      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode,
        'alternatives': alternatives.toString(),
        'key': apiKey,
        'language': 'es', // Instrucciones en español
      };

      // Agregar waypoints si existen
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointsStr = waypoints
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');
        params['waypoints'] = waypointsStr;
      }

      // Agregar opciones de evitar
      final avoid = <String>[];
      if (avoidTolls) avoid.add('tolls');
      if (avoidHighways) avoid.add('highways');
      if (avoidFerries) avoid.add('ferries');
      if (avoid.isNotEmpty) {
        params['avoid'] = avoid.join('|');
      }

      // Construir URI
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

      // Realizar petición HTTP con timeout para evitar bloqueos indefinidos
      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Parsear JSON
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final directionsResponse = DirectionsResponse.fromJson(json);

        // Verificar estado de la respuesta
        if (!directionsResponse.isSuccess) {
          throw Exception(
            'Error de Google Directions API: ${directionsResponse.status}. '
            '${directionsResponse.errorMessage ?? ""}',
          );
        }

        return directionsResponse;
      } else {
        throw Exception(
          'Error HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error al obtener direcciones: ${e.toString()}');
    }
  }

  /// Recalcula ruta desde ubicación actual hasta destino
  ///
  /// [currentLocation] - Ubicación actual del usuario
  /// [destination] - Destino final
  /// [mode] - Modo de transporte
  ///
  /// Retorna:
  /// - DirectionsResponse con nueva ruta
  Future<DirectionsResponse> recalculateRoute({
    required LatLng currentLocation,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    return getDirections(
      origin: currentLocation,
      destination: destination,
      mode: mode,
    );
  }

  /// Convierte DirectionsResponse a lista de NavigationSteps
  ///
  /// [directionsResponse] - Respuesta de la API
  ///
  /// Retorna:
  /// - Lista de NavigationStep listos para navegación
  List<NavigationStep> extractNavigationSteps(
    DirectionsResponse directionsResponse,
  ) {
    final steps = <NavigationStep>[];

    // Obtener la primera ruta
    final route = directionsResponse.primaryRoute;
    if (route == null) return steps;

    // Obtener el primer leg
    final leg = route.primaryLeg;
    if (leg == null) return steps;

    // Convertir cada DirectionsStep a NavigationStep
    for (final directionStep in leg.steps) {
      // Decodificar polyline del paso
      final polylinePoints = decodePolyline(directionStep.polylineEncoded);

      // Convertir a NavigationStep
      final navStep = directionStep.toNavigationStep(polylinePoints);
      steps.add(navStep);
    }

    return steps;
  }

  /// Obtiene polyline completa de la ruta concatenando las polylines de cada step.
  ///
  /// Se usa la polyline por step (alta densidad de puntos) en lugar de la
  /// overview_polyline de la ruta (simplificada, pocos puntos). Esto garantiza
  /// que snapToPolyline proyecte la posición del usuario con precisión suficiente
  /// para que las distancias al siguiente giro sean correctas.
  ///
  /// [directionsResponse] - Respuesta de la API
  ///
  /// Retorna:
  /// - Lista de LatLng de la polyline completa (alta precisión)
  List<LatLng> extractCompletePolyline(
    DirectionsResponse directionsResponse,
  ) {
    final route = directionsResponse.primaryRoute;
    if (route == null) return [];
    final leg = route.primaryLeg;
    if (leg == null) return [];

    final result = <LatLng>[];
    for (final step in leg.steps) {
      final stepPoints = decodePolyline(step.polylineEncoded);
      if (result.isNotEmpty && stepPoints.isNotEmpty) {
        // Omitir el primer punto del step para no duplicar el punto de unión
        result.addAll(stepPoints.skip(1));
      } else {
        result.addAll(stepPoints);
      }
    }
    return result;
  }

  // ========================================
  // DECODIFICACIÓN DE POLYLINE
  // ========================================

  /// Decodifica una polyline codificada de Google
  ///
  /// Implementación del algoritmo de decodificación de Google:
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  ///
  /// [encoded] - String de polyline codificada
  ///
  /// Retorna:
  /// - Lista de LatLng decodificados
  List<LatLng> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];

    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      // Decodificar latitud
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decodificar longitud
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // Convertir a coordenadas decimales
      final latitude = lat / 1E5;
      final longitude = lng / 1E5;

      points.add(LatLng(latitude, longitude));
    }

    return points;
  }


  // ========================================
  // UTILIDADES
  // ========================================

  /// Calcula distancia total de la respuesta en metros
  double getTotalDistance(DirectionsResponse response) {
    final route = response.primaryRoute;
    if (route == null) return 0;

    return route.totalDistanceMeters.toDouble();
  }

  /// Calcula duración total de la respuesta en segundos
  int getTotalDuration(DirectionsResponse response) {
    final route = response.primaryRoute;
    if (route == null) return 0;

    return route.totalDurationSeconds;
  }

  /// Calcula bounds de la respuesta para ajustar cámara
  LatLngBounds? getBounds(DirectionsResponse response) {
    final route = response.primaryRoute;
    if (route == null) return null;

    return route.bounds.toLatLngBounds();
  }

  /// Cierra el cliente HTTP (importante para evitar memory leaks)
  void dispose() {
    _httpClient.close();
  }
}
