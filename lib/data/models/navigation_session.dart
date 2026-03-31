/// Modelo de Sesión de Navegación
///
/// Representa una sesión activa de navegación turn-by-turn
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - Getters calculados para UI
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'navigation_step.dart';

/// Estados de la sesión de navegación
enum NavigationStatus {
  planning, // Calculando ruta inicial
  navigating, // Navegación activa
  paused, // Pausada por el usuario
  completed, // Llegó al destino
  cancelled, // Cancelada por el usuario
  offRoute; // Usuario se desvió de la ruta

  /// Convierte desde string
  static NavigationStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'planning':
        return NavigationStatus.planning;
      case 'navigating':
        return NavigationStatus.navigating;
      case 'paused':
        return NavigationStatus.paused;
      case 'completed':
        return NavigationStatus.completed;
      case 'cancelled':
        return NavigationStatus.cancelled;
      case 'offroute':
      case 'off_route':
        return NavigationStatus.offRoute;
      default:
        return NavigationStatus.planning;
    }
  }

  /// Convierte a string
  String toStringValue() {
    switch (this) {
      case NavigationStatus.planning:
        return 'planning';
      case NavigationStatus.navigating:
        return 'navigating';
      case NavigationStatus.paused:
        return 'paused';
      case NavigationStatus.completed:
        return 'completed';
      case NavigationStatus.cancelled:
        return 'cancelled';
      case NavigationStatus.offRoute:
        return 'off_route';
    }
  }
}

class NavigationSession {
  /// ID único de la sesión (UUID de Supabase)
  final String id;

  /// ID del usuario
  final String? userId;

  /// ID de sesión grupal (null si es navegación individual)
  final String? sesionGrupalId;

  /// Ubicación de origen
  final LatLng origin;

  /// Ubicación de destino
  final LatLng destination;

  /// Nombre del destino (opcional)
  final String? destinationName;

  /// Pasos de navegación (steps)
  final List<NavigationStep> steps;

  /// Polyline completa de toda la ruta
  final List<LatLng> completePolyline;

  /// Estado actual de la navegación
  final NavigationStatus status;

  /// Fecha y hora de inicio
  final DateTime startTime;

  /// Fecha y hora de fin (opcional)
  final DateTime? endTime;

  /// Distancia total de la ruta en metros
  final double totalDistanceMeters;

  /// Duración total estimada en segundos
  final int totalDurationSeconds;

  /// Índice del paso actual (0-based)
  final int currentStepIndex;

  /// Distancia recorrida hasta el momento en metros
  final double distanceTraveledMeters;

  /// Tiempo transcurrido desde el inicio
  final Duration elapsedTime;

  /// Constructor
  const NavigationSession({
    required this.id,
    this.userId,
    this.sesionGrupalId,
    required this.origin,
    required this.destination,
    this.destinationName,
    required this.steps,
    required this.completePolyline,
    this.status = NavigationStatus.planning,
    required this.startTime,
    this.endTime,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    this.currentStepIndex = 0,
    this.distanceTraveledMeters = 0.0,
    this.elapsedTime = Duration.zero,
  });

  /// Crea una instancia desde JSON
  factory NavigationSession.fromJson(Map<String, dynamic> json) {
    // Parsear steps
    final stepsJson = json['steps'] as List?;
    final steps = stepsJson
            ?.map((step) =>
                NavigationStep.fromJson(step as Map<String, dynamic>))
            .toList() ??
        [];

    // Parsear polyline
    final polylineJson = json['polyline'] as List?;
    final polyline = polylineJson
            ?.map((point) => LatLng(
                  point['lat'] as double,
                  point['lng'] as double,
                ))
            .toList() ??
        [];

    return NavigationSession(
      id: json['id'] as String,
      userId: json['usuario_id'] as String?,
      sesionGrupalId: json['sesion_grupal_id'] as String?,
      origin: LatLng(
        json['origen_lat'] as double,
        json['origen_lng'] as double,
      ),
      destination: LatLng(
        json['destino_lat'] as double,
        json['destino_lng'] as double,
      ),
      destinationName: json['destino_nombre'] as String?,
      steps: steps,
      completePolyline: polyline,
      status: NavigationStatus.fromString(
        json['estado'] as String? ?? 'planning',
      ),
      startTime: DateTime.parse(json['fecha_inicio'] as String),
      endTime: json['fecha_fin'] != null
          ? DateTime.parse(json['fecha_fin'] as String)
          : null,
      totalDistanceMeters:
          (json['distancia_total_metros'] as num?)?.toDouble() ?? 0.0,
      totalDurationSeconds: json['duracion_total_segundos'] as int? ?? 0,
      currentStepIndex: json['paso_actual'] as int? ?? 0,
      distanceTraveledMeters:
          (json['distancia_recorrida_metros'] as num?)?.toDouble() ?? 0.0,
      elapsedTime: Duration.zero, // Se calcula dinámicamente
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': userId,
      'sesion_grupal_id': sesionGrupalId,
      'origen_lat': origin.latitude,
      'origen_lng': origin.longitude,
      'destino_lat': destination.latitude,
      'destino_lng': destination.longitude,
      'destino_nombre': destinationName,
      'steps': steps.map((step) => step.toJson()).toList(),
      'polyline': completePolyline
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList(),
      'estado': status.toStringValue(),
      'fecha_inicio': startTime.toIso8601String(),
      'fecha_fin': endTime?.toIso8601String(),
      'distancia_total_metros': totalDistanceMeters,
      'duracion_total_segundos': totalDurationSeconds,
      'paso_actual': currentStepIndex,
      'distancia_recorrida_metros': distanceTraveledMeters,
    };
  }

  /// Crea una copia con campos modificados
  NavigationSession copyWith({
    String? id,
    String? userId,
    String? sesionGrupalId,
    LatLng? origin,
    LatLng? destination,
    String? destinationName,
    List<NavigationStep>? steps,
    List<LatLng>? completePolyline,
    NavigationStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistanceMeters,
    int? totalDurationSeconds,
    int? currentStepIndex,
    double? distanceTraveledMeters,
    Duration? elapsedTime,
  }) {
    return NavigationSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sesionGrupalId: sesionGrupalId ?? this.sesionGrupalId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
      steps: steps ?? this.steps,
      completePolyline: completePolyline ?? this.completePolyline,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      distanceTraveledMeters:
          distanceTraveledMeters ?? this.distanceTraveledMeters,
      elapsedTime: elapsedTime ?? this.elapsedTime,
    );
  }

  // ========================================
  // GETTERS DE CONVENIENCIA
  // ========================================

  /// Verifica si la navegación está activa
  bool get isNavigating => status == NavigationStatus.navigating;

  /// Verifica si la navegación está pausada
  bool get isPaused => status == NavigationStatus.paused;

  /// Verifica si la navegación está completada
  bool get isCompleted => status == NavigationStatus.completed;

  /// Verifica si la navegación fue cancelada
  bool get isCancelled => status == NavigationStatus.cancelled;

  /// Verifica si el usuario está fuera de ruta
  bool get isOffRoute => status == NavigationStatus.offRoute;

  /// Verifica si es navegación grupal
  bool get isGroupNavigation => sesionGrupalId != null;

  /// Verifica si es navegación individual
  bool get isIndividualNavigation => sesionGrupalId == null;

  /// Obtiene el paso actual
  NavigationStep? get currentStep {
    if (currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return null;
  }

  /// Obtiene el siguiente paso
  NavigationStep? get nextStep {
    final nextIndex = currentStepIndex + 1;
    if (nextIndex < steps.length) {
      return steps[nextIndex];
    }
    return null;
  }

  /// Calcula la distancia restante en metros
  double get remainingDistanceMeters {
    double remaining = 0.0;

    // Sumar distancias de pasos restantes
    for (int i = currentStepIndex; i < steps.length; i++) {
      remaining += steps[i].distanceMeters;
    }

    return remaining;
  }

  /// Calcula la duración restante en segundos
  int get remainingDurationSeconds {
    int remaining = 0;

    // Sumar duraciones de pasos restantes
    for (int i = currentStepIndex; i < steps.length; i++) {
      remaining += steps[i].durationSeconds;
    }

    return remaining;
  }

  /// Calcula el tiempo estimado de llegada (ETA)
  DateTime get estimatedArrivalTime {
    return DateTime.now().add(Duration(seconds: remainingDurationSeconds));
  }

  /// Calcula el porcentaje de progreso (0-100)
  double get progressPercentage {
    if (totalDistanceMeters == 0) return 0;
    return (distanceTraveledMeters / totalDistanceMeters) * 100;
  }

  /// Calcula el número total de pasos
  int get totalSteps => steps.length;

  /// Verifica si es el último paso
  bool get isLastStep => currentStepIndex == steps.length - 1;

  /// Verifica si es el primer paso
  bool get isFirstStep => currentStepIndex == 0;

  /// Texto formateado de distancia restante
  String get remainingDistanceText {
    if (remainingDistanceMeters < 1000) {
      return '${remainingDistanceMeters.toInt()} m';
    }
    return '${(remainingDistanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Texto formateado de duración restante
  String get remainingDurationText {
    final mins = (remainingDurationSeconds / 60).ceil();
    if (mins < 60) {
      return '$mins min';
    }
    final hours = (mins / 60).floor();
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}min';
  }

  /// Texto formateado de distancia total
  String get totalDistanceText {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.toInt()} m';
    }
    return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Texto formateado de duración total
  String get totalDurationText {
    final mins = (totalDurationSeconds / 60).ceil();
    if (mins < 60) {
      return '$mins min';
    }
    final hours = (mins / 60).floor();
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}min';
  }

  @override
  String toString() {
    return 'NavigationSession('
        'id: $id, '
        'status: ${status.toStringValue()}, '
        'currentStep: $currentStepIndex/$totalSteps, '
        'progress: ${progressPercentage.toStringAsFixed(1)}%'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
