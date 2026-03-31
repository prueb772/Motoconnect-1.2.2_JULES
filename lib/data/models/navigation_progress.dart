/// Modelo de Progreso de Navegación en Tiempo Real
///
/// Representa el progreso de navegación de un usuario para compartir en grupos
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - Getters calculados para UI
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationProgress {
  /// ID único del progreso
  final String id;

  /// ID de la sesión de navegación
  final String sessionId;

  /// ID del usuario
  final String userId;

  /// Índice del paso actual
  final int currentStepIndex;

  /// Ubicación actual del usuario
  final LatLng currentLocation;

  /// Distancia al final del paso actual en metros
  final double? distanceToNextStep;

  /// ETA en segundos
  final int? etaSeconds;

  /// Distancia restante total en metros
  final double? remainingDistanceMeters;

  /// Timestamp de la última actualización
  final DateTime timestamp;

  // Información del usuario (para mostrar en UI de grupos)
  final String? nombreUsuario;
  final String? apodoUsuario;
  final String? fotoPerfilUsuario;

  /// Constructor
  const NavigationProgress({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.currentStepIndex,
    required this.currentLocation,
    this.distanceToNextStep,
    this.etaSeconds,
    this.remainingDistanceMeters,
    required this.timestamp,
    this.nombreUsuario,
    this.apodoUsuario,
    this.fotoPerfilUsuario,
  });

  /// Crea una instancia desde JSON
  factory NavigationProgress.fromJson(Map<String, dynamic> json) {
    return NavigationProgress(
      id: json['id'] as String,
      sessionId: json['sesion_navegacion_id'] as String,
      userId: json['usuario_id'] as String,
      currentStepIndex: json['paso_actual'] as int,
      currentLocation: LatLng(
        json['ubicacion_lat'] as double,
        json['ubicacion_lng'] as double,
      ),
      distanceToNextStep:
          (json['distancia_siguiente_paso'] as num?)?.toDouble(),
      etaSeconds: json['eta_segundos'] as int?,
      remainingDistanceMeters:
          (json['distancia_restante_metros'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['ultima_actualizacion'] as String),
      nombreUsuario: json['nombre_usuario'] as String?,
      apodoUsuario: json['apodo_usuario'] as String?,
      fotoPerfilUsuario: json['foto_perfil_usuario'] as String?,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_navegacion_id': sessionId,
      'usuario_id': userId,
      'paso_actual': currentStepIndex,
      'ubicacion_lat': currentLocation.latitude,
      'ubicacion_lng': currentLocation.longitude,
      'distancia_siguiente_paso': distanceToNextStep,
      'eta_segundos': etaSeconds,
      'distancia_restante_metros': remainingDistanceMeters,
      'ultima_actualizacion': timestamp.toIso8601String(),
      if (nombreUsuario != null) 'nombre_usuario': nombreUsuario,
      if (apodoUsuario != null) 'apodo_usuario': apodoUsuario,
      if (fotoPerfilUsuario != null) 'foto_perfil_usuario': fotoPerfilUsuario,
    };
  }

  /// Crea una copia con campos modificados
  NavigationProgress copyWith({
    String? id,
    String? sessionId,
    String? userId,
    int? currentStepIndex,
    LatLng? currentLocation,
    double? distanceToNextStep,
    int? etaSeconds,
    double? remainingDistanceMeters,
    DateTime? timestamp,
    String? nombreUsuario,
    String? apodoUsuario,
    String? fotoPerfilUsuario,
  }) {
    return NavigationProgress(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentLocation: currentLocation ?? this.currentLocation,
      distanceToNextStep: distanceToNextStep ?? this.distanceToNextStep,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      timestamp: timestamp ?? this.timestamp,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      apodoUsuario: apodoUsuario ?? this.apodoUsuario,
      fotoPerfilUsuario: fotoPerfilUsuario ?? this.fotoPerfilUsuario,
    );
  }

  // ========================================
  // GETTERS DE CONVENIENCIA
  // ========================================

  /// Texto formateado de ETA
  String get etaText {
    if (etaSeconds == null) return 'Calculando...';

    final mins = (etaSeconds! / 60).ceil();
    if (mins < 60) {
      return '$mins min';
    }
    final hours = (mins / 60).floor();
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}min';
  }

  /// Texto formateado de distancia restante
  String get remainingDistanceText {
    if (remainingDistanceMeters == null) return 'Calculando...';

    if (remainingDistanceMeters! < 1000) {
      return '${remainingDistanceMeters!.toInt()} m';
    }
    return '${(remainingDistanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  /// Texto formateado de distancia al siguiente paso
  String get distanceToNextStepText {
    if (distanceToNextStep == null) return '';

    if (distanceToNextStep! < 1000) {
      return '${distanceToNextStep!.toInt()} m';
    }
    return '${(distanceToNextStep! / 1000).toStringAsFixed(1)} km';
  }

  /// Nombre para mostrar (apodo o nombre completo)
  String get nombreMostrar {
    if (apodoUsuario != null && apodoUsuario!.isNotEmpty) {
      return apodoUsuario!;
    }
    return nombreUsuario ?? 'Usuario';
  }

  /// Verifica si la actualización es reciente (menos de 1 minuto)
  bool get esReciente {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inSeconds < 60;
  }

  /// Verifica si la actualización está obsoleta (más de 5 minutos)
  bool get esObsoleta {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inMinutes > 5;
  }

  /// Tiempo transcurrido desde la última actualización
  String get tiempoTranscurrido {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else {
      return 'Hace ${diff.inHours}h';
    }
  }

  @override
  String toString() {
    return 'NavigationProgress('
        'userId: $userId, '
        'step: $currentStepIndex, '
        'eta: $etaText, '
        'remaining: $remainingDistanceText'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationProgress &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
