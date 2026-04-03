/// Servicio de Tracking de Navegación
///
/// Responsabilidades:
/// - Determinar en qué paso está el usuario basado en GPS
/// - Calcular ETA dinámico
/// - Detectar desvíos de ruta
/// - Calcular distancia restante
/// - Alertas de proximidad a giros
library;

import 'dart:math' show min, max, pow;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/navigation_step.dart';

class NavigationTrackingService {
  // ========================================
  // CONSTANTES
  // ========================================

  /// Umbral de proximidad para considerar que completó un paso (en metros)
  static const double PROXIMITY_THRESHOLD_METERS = 30.0;

  /// Umbral de distancia para considerar que se desvió de la ruta (en metros)
  static const double OFF_ROUTE_THRESHOLD_METERS = 50.0;

  /// Distancia de alerta para el próximo giro (en metros)
  static const double NEXT_TURN_ALERT_METERS = 200.0;

  /// Factor de corrección para ETA (considera tráfico, semáforos, etc.)
  static const double ETA_CORRECTION_FACTOR = 1.15; // 15% más tiempo

  /// Velocidad mínima para calcular ETA basado en velocidad actual (km/h)
  static const double MIN_SPEED_FOR_ETA_KMH = 5.0;

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  /// Determina en qué paso está el usuario basado en su ubicación GPS.
  ///
  /// Estrategia "closest-step con lookahead":
  /// Evalúa hasta 5 pasos adelante del paso actual y retorna el más
  /// avanzado cuya polyline sea la más cercana al usuario.
  /// Esto evita que el sistema se quede "pegado" en un paso ya superado
  /// cuando el usuario (en moto) avanza rápido entre actualizaciones GPS.
  ///
  /// [currentLocation] - Ubicación actual del usuario
  /// [steps] - Lista de pasos de la ruta
  /// [lastStepIndex] - Último paso conocido
  ///
  /// Retorna:
  /// - Índice del paso actual (0-based), nunca inferior a [lastStepIndex]
  int determineCurrentStep({
    required LatLng currentLocation,
    required List<NavigationStep> steps,
    required int lastStepIndex,
  }) {
    if (steps.isEmpty) return 0;
    if (lastStepIndex >= steps.length) return steps.length - 1;
    if (lastStepIndex < 0) return 0;

    // Revisar hasta 5 pasos hacia adelante para compensar velocidad en moto
    const int lookahead = 5;
    final int maxCheck = min(lastStepIndex + lookahead, steps.length - 1);

    double minDist = double.maxFinite;
    int bestIndex = lastStepIndex;

    for (int i = lastStepIndex; i <= maxCheck; i++) {
      final step = steps[i];

      // Distancia mínima del usuario a la polyline completa del paso
      final distToPolyline = _minDistanceToPolyline(
        currentLocation,
        step.polylinePoints,
      );

      // Si la polyline de este paso es la más cercana, es el candidato
      if (distToPolyline < minDist) {
        minDist = distToPolyline;
        bestIndex = i;
      }
    }

    // Si el usuario está muy cerca del inicio del paso siguiente, avanzar
    if (bestIndex + 1 < steps.length) {
      final distToCurrentEnd = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        steps[bestIndex].endLocation.latitude,
        steps[bestIndex].endLocation.longitude,
      );
      final distToNextStart = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        steps[bestIndex + 1].startLocation.latitude,
        steps[bestIndex + 1].startLocation.longitude,
      );
      if (distToCurrentEnd < PROXIMITY_THRESHOLD_METERS &&
          distToNextStart < distToCurrentEnd) {
        bestIndex = bestIndex + 1;
      }
    }

    // Nunca retroceder pasos
    return max(lastStepIndex, bestIndex);
  }

  /// Calcula la distancia al final del paso actual
  ///
  /// [currentLocation] - Ubicación actual
  /// [currentStep] - Paso actual
  ///
  /// Retorna:
  /// - Distancia en metros
  double calculateDistanceToStepEnd({
    required LatLng currentLocation,
    required NavigationStep currentStep,
  }) {
    return Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      currentStep.endLocation.latitude,
      currentStep.endLocation.longitude,
    );
  }

  /// Verifica si el usuario está cerca del siguiente giro
  ///
  /// [currentLocation] - Ubicación actual
  /// [nextStep] - Siguiente paso
  /// [threshold] - Umbral de distancia (default: NEXT_TURN_ALERT_METERS)
  ///
  /// Retorna:
  /// - true si está cerca del siguiente giro
  bool isNearNextTurn({
    required LatLng currentLocation,
    required NavigationStep nextStep,
    double threshold = NEXT_TURN_ALERT_METERS,
  }) {
    final distance = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      nextStep.startLocation.latitude,
      nextStep.startLocation.longitude,
    );

    return distance <= threshold;
  }

  /// Detecta si el usuario se desvió de la ruta
  ///
  /// [currentLocation] - Ubicación actual
  /// [currentStep] - Paso actual
  ///
  /// Retorna:
  /// - true si se desvió de la ruta
  bool isOffRoute({
    required LatLng currentLocation,
    required NavigationStep currentStep,
  }) {
    return !_isOnPolyline(
      currentLocation,
      currentStep.polylinePoints,
      threshold: OFF_ROUTE_THRESHOLD_METERS,
    );
  }

  /// Calcula ETA dinámico basado en velocidad actual
  ///
  /// [remainingDistanceMeters] - Distancia restante
  /// [currentSpeedKmh] - Velocidad actual en km/h
  /// [remainingDurationSeconds] - Duración estimada original
  ///
  /// Retorna:
  /// - DateTime con la hora estimada de llegada
  DateTime calculateETA({
    required double remainingDistanceMeters,
    required double currentSpeedKmh,
    required int remainingDurationSeconds,
  }) {
    // Si la velocidad es muy baja o cero, usar duración estimada original
    if (currentSpeedKmh < MIN_SPEED_FOR_ETA_KMH) {
      return DateTime.now().add(Duration(seconds: remainingDurationSeconds));
    }

    // Calcular tiempo basado en velocidad actual
    final speedMps = currentSpeedKmh / 3.6; // km/h a m/s
    final timeSeconds = remainingDistanceMeters / speedMps;

    // Aplicar factor de corrección (tráfico, semáforos, etc.)
    final adjustedTimeSeconds = (timeSeconds * ETA_CORRECTION_FACTOR).toInt();

    // Promediar con duración estimada para suavizar
    final finalTimeSeconds = (adjustedTimeSeconds + remainingDurationSeconds) ~/ 2;

    return DateTime.now().add(Duration(seconds: finalTimeSeconds));
  }

  /// Calcula la distancia restante total
  ///
  /// [currentLocation] - Ubicación actual
  /// [steps] - Lista de pasos
  /// [currentStepIndex] - Índice del paso actual
  ///
  /// Retorna:
  /// - Distancia restante en metros
  double calculateRemainingDistance({
    required LatLng currentLocation,
    required List<NavigationStep> steps,
    required int currentStepIndex,
  }) {
    double total = 0.0;

    // Validar entrada
    if (steps.isEmpty || currentStepIndex >= steps.length) {
      return 0.0;
    }

    // Distancia al final del paso actual
    final currentStep = steps[currentStepIndex];
    total += calculateDistanceToStepEnd(
      currentLocation: currentLocation,
      currentStep: currentStep,
    );

    // Sumar distancias de pasos restantes
    for (int i = currentStepIndex + 1; i < steps.length; i++) {
      total += steps[i].distanceMeters;
    }

    return total;
  }

  /// Calcula la duración restante total
  ///
  /// [steps] - Lista de pasos
  /// [currentStepIndex] - Índice del paso actual
  ///
  /// Retorna:
  /// - Duración restante en segundos
  int calculateRemainingDuration({
    required List<NavigationStep> steps,
    required int currentStepIndex,
  }) {
    int total = 0;

    // Validar entrada
    if (steps.isEmpty || currentStepIndex >= steps.length) {
      return 0;
    }

    // Sumar duraciones desde el paso actual
    for (int i = currentStepIndex; i < steps.length; i++) {
      total += steps[i].durationSeconds;
    }

    return total;
  }

  // ========================================
  // MÉTODOS PRIVADOS
  // ========================================

  /// Proyecta [position] al punto más cercano sobre [routePolyline].
  ///
  /// Itera cada segmento de la polyline, calcula la proyección perpendicular
  /// y retorna el punto proyectado del segmento más cercano.
  /// Si la polyline está vacía retorna [position] sin cambios.
  /// Solo debe llamarse cuando hay ruta activa (polyline no vacía).
  LatLng snapToPolyline(LatLng position, List<LatLng> routePolyline) {
    if (routePolyline.length < 2) return position;

    double minDist = double.maxFinite;
    LatLng snapped = position;

    for (int i = 0; i < routePolyline.length - 1; i++) {
      final projected = _projectOntoSegment(
        position,
        routePolyline[i],
        routePolyline[i + 1],
      );
      final d = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        projected.latitude,
        projected.longitude,
      );
      if (d < minDist) {
        minDist = d;
        snapped = projected;
      }
    }

    return snapped;
  }

  /// Calcula la distancia mínima de un punto a cualquier segmento de una polyline.
  ///
  /// Retorna [double.maxFinite] si la polyline está vacía.
  double _minDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.maxFinite;
    if (polyline.length == 1) {
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        polyline[0].latitude,
        polyline[0].longitude,
      );
    }

    double minDist = double.maxFinite;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToLineSegment(point, polyline[i], polyline[i + 1]);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Verifica si un punto está en una polyline
  ///
  /// [point] - Punto a verificar
  /// [polyline] - Lista de puntos de la polyline
  /// [threshold] - Umbral de distancia (default: OFF_ROUTE_THRESHOLD_METERS)
  ///
  /// Retorna:
  /// - true si el punto está en la polyline
  bool _isOnPolyline(
    LatLng point,
    List<LatLng> polyline, {
    double threshold = OFF_ROUTE_THRESHOLD_METERS,
  }) {
    if (polyline.length < 2) return false;

    // Verificar cada segmento de la polyline
    for (int i = 0; i < polyline.length - 1; i++) {
      final distance = _distanceToLineSegment(
        point,
        polyline[i],
        polyline[i + 1],
      );

      if (distance < threshold) {
        return true;
      }
    }

    return false;
  }

  /// Retorna el punto proyectado perpendicularmente desde [point] sobre el
  /// segmento [lineStart]→[lineEnd], clampeado a los extremos del segmento.
  LatLng _projectOntoSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final px = point.latitude;
    final py = point.longitude;
    final x1 = lineStart.latitude;
    final y1 = lineStart.longitude;
    final x2 = lineEnd.latitude;
    final y2 = lineEnd.longitude;

    final segmentLengthSq = pow(x2 - x1, 2) + pow(y2 - y1, 2);
    if (segmentLengthSq == 0) return lineStart;

    var t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segmentLengthSq;
    t = max(0, min(1, t));

    return LatLng(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
  }

  /// Calcula la distancia de un punto a un segmento de línea
  ///
  /// Implementación del algoritmo de proyección perpendicular
  ///
  /// [point] - Punto a medir
  /// [lineStart] - Inicio del segmento
  /// [lineEnd] - Fin del segmento
  ///
  /// Retorna:
  /// - Distancia mínima en metros
  double _distanceToLineSegment(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    // Convertir LatLng a coordenadas cartesianas (simplificado)
    final px = point.latitude;
    final py = point.longitude;
    final x1 = lineStart.latitude;
    final y1 = lineStart.longitude;
    final x2 = lineEnd.latitude;
    final y2 = lineEnd.longitude;

    // Calcular longitud del segmento al cuadrado
    final segmentLengthSq = pow(x2 - x1, 2) + pow(y2 - y1, 2);

    // Si el segmento es un punto, retornar distancia al punto
    if (segmentLengthSq == 0) {
      return Geolocator.distanceBetween(px, py, x1, y1);
    }

    // Calcular parámetro t de la proyección
    var t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / segmentLengthSq;
    t = max(0, min(1, t)); // Clamp to [0, 1]

    // Punto proyectado en el segmento
    final projectedLat = x1 + t * (x2 - x1);
    final projectedLng = y1 + t * (y2 - y1);

    // Distancia desde el punto al punto proyectado
    return Geolocator.distanceBetween(px, py, projectedLat, projectedLng);
  }

  // ========================================
  // SIMPLIFICACIÓN DE TRACK GPS
  // ========================================

  /// Simplifica un track GPS usando el algoritmo Ramer-Douglas-Peucker.
  ///
  /// Elimina puntos redundantes que no aportan información sobre la forma
  /// del trayecto, reduciendo el volumen de datos sin perder fidelidad.
  ///
  /// [points] - Lista de puntos GPS acumulados durante la navegación
  /// [epsilonMeters] - Tolerancia máxima en metros. 15m es el valor recomendado
  ///   para motos: suficiente para capturar curvas cerradas sin guardar ruido.
  ///
  /// Retorna la lista simplificada. Si [points] tiene 2 o menos puntos,
  /// los retorna sin cambios.
  List<LatLng> simplifyTrack(List<LatLng> points, double epsilonMeters) {
    if (points.length <= 2) return List.from(points);
    return _rdpSimplify(points, epsilonMeters);
  }

  List<LatLng> _rdpSimplify(List<LatLng> points, double epsilon) {
    if (points.length <= 2) return List.from(points);

    // Encontrar el punto con mayor desviación perpendicular
    // respecto a la línea recta entre el primer y último punto
    double maxDist = 0.0;
    int maxIdx = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _distanceToLineSegment(points[i], points.first, points.last);
      if (d > maxDist) {
        maxDist = d;
        maxIdx = i;
      }
    }

    // Si la desviación máxima supera epsilon, subdividir y simplificar
    if (maxDist > epsilon) {
      final left = _rdpSimplify(points.sublist(0, maxIdx + 1), epsilon);
      final right = _rdpSimplify(points.sublist(maxIdx), epsilon);
      // Combinar evitando duplicar el punto en maxIdx
      return [...left.sublist(0, left.length - 1), ...right];
    }

    // Todos los puntos intermedios están dentro de epsilon: conservar solo extremos
    return [points.first, points.last];
  }

  // ========================================
  // UTILIDADES
  // ========================================

  /// Calcula la distancia entre dos puntos
  ///
  /// [lat1] - Latitud del punto 1
  /// [lng1] - Longitud del punto 1
  /// [lat2] - Latitud del punto 2
  /// [lng2] - Longitud del punto 2
  ///
  /// Retorna:
  /// - Distancia en metros
  double calcularDistancia({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calcula el bearing (dirección) entre dos puntos
  ///
  /// [from] - Punto de origen
  /// [to] - Punto de destino
  ///
  /// Retorna:
  /// - Bearing en grados (0-360)
  double calculateBearing({
    required LatLng from,
    required LatLng to,
  }) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
