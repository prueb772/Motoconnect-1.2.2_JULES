/// Servicio de Tracking de Ubicación en Tiempo Real
///
/// Responsabilidades:
/// - Obtener ubicación GPS del dispositivo
/// - Actualizar ubicación en tiempo real durante sesiones activas
/// - Manejar permisos de ubicación
/// - Configurar precisión y frecuencia de actualizaciones
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import '../data/repositories/grupo_repository.dart';
import '../data/repositories/impl/grupo_repository_impl.dart';

/// Configuración de tracking
class TrackingConfig {
  /// Distancia mínima en metros para actualizar ubicación
  final double distanciaMinima;

  /// Intervalo mínimo en segundos entre actualizaciones
  final int intervaloMinimo;

  /// Precisión de ubicación
  final LocationAccuracy precision;

  const TrackingConfig({
    this.distanciaMinima = 10.0, // 10 metros
    this.intervaloMinimo = 5, // 5 segundos
    this.precision = LocationAccuracy.high,
  });

  /// Configuración para tracking de alta precisión
  static const TrackingConfig altaPrecision = TrackingConfig(
    distanciaMinima: 5.0,
    intervaloMinimo: 3,
    precision: LocationAccuracy.best,
  );

  /// Configuración para tracking estándar (balance entre precisión y batería)
  static const TrackingConfig estandar = TrackingConfig(
    distanciaMinima: 10.0,
    intervaloMinimo: 5,
    precision: LocationAccuracy.high,
  );

  /// Configuración para ahorro de batería
  static const TrackingConfig ahorroBateria = TrackingConfig(
    distanciaMinima: 20.0,
    intervaloMinimo: 10,
    precision: LocationAccuracy.medium,
  );
}

class LocationTrackingService {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  final GrupoRepository _grupoRepository;

  static const _notificationChannel =
      MethodChannel('com.example.motoconnect/notifications');

  // ========================================
  // ESTADO
  // ========================================

  /// Stream de posiciones
  StreamSubscription<Position>? _posicionSubscription;

  /// Sesión activa actual
  String? _sesionActiva;

  /// Configuración de tracking
  TrackingConfig _config = TrackingConfig.estandar;

  /// Última posición registrada
  Position? _ultimaPosicion;

  /// Controlador de stream de ubicación
  final StreamController<Position> _ubicacionController =
      StreamController<Position>.broadcast();

  /// Indica si el tracking está activo
  bool _trackingActivo = false;

  // ========================================
  // ESTADO DE CONECTIVIDAD
  // ========================================

  /// Contador de fallos consecutivos al enviar ubicación al servidor
  int _fallosConsecutivos = 0;

  /// Estado actual de conectividad (internet + GPS)
  bool _conectado = true;

  /// Controlador de stream de conectividad
  final StreamController<bool> _conectadoController =
      StreamController<bool>.broadcast();

  /// Suscripción al estado del servicio GPS
  StreamSubscription<ServiceStatus>? _gpsSubscription;

  // ========================================
  // CONSTRUCTOR
  // ========================================

  LocationTrackingService({GrupoRepository? grupoRepository})
      : _grupoRepository = grupoRepository ?? GrupoRepositoryImpl();

  // ========================================
  // GETTERS
  // ========================================

  /// Stream de ubicaciones
  Stream<Position> get ubicacionStream => _ubicacionController.stream;

  /// Indica si el tracking está activo
  bool get estaActivo => _trackingActivo;

  /// Última posición conocida
  Position? get ultimaPosicion => _ultimaPosicion;

  /// Sesión activa actual
  String? get sesionActiva => _sesionActiva;

  /// Stream de estado de conectividad (internet + GPS)
  Stream<bool> get conectadoStream => _conectadoController.stream;

  // ========================================
  // MÉTODOS DE PERMISOS
  // ========================================

  /// Verifica si los permisos de ubicación están habilitados
  Future<bool> tienePermisos() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Solicita permisos de ubicación
  Future<bool> solicitarPermisos() async {
    // Verificar si el servicio de ubicación está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'El servicio de ubicación está deshabilitado. '
        'Por favor habilítalo en la configuración del dispositivo.',
      );
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permisos de ubicación denegados');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación están permanentemente denegados. '
        'Por favor habilítalos en la configuración de la aplicación.',
      );
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Abre la configuración de la aplicación
  Future<bool> abrirConfiguracion() async {
    return await Geolocator.openAppSettings();
  }

  // ========================================
  // MÉTODOS DE UBICACIÓN
  // ========================================

  /// Obtiene la ubicación actual del dispositivo
  Future<Position> obtenerUbicacionActual() async {
    try {
      // Verificar permisos
      if (!await tienePermisos()) {
        await solicitarPermisos();
      }

      // Obtener posición actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _config.precision,
      );

      _ultimaPosicion = position;
      return position;
    } catch (e) {
      throw Exception('Error al obtener ubicación: ${e.toString()}');
    }
  }

  /// Obtiene la ubicación como LatLng
  Future<LatLng> obtenerUbicacionActualLatLng() async {
    final position = await obtenerUbicacionActual();
    return LatLng(position.latitude, position.longitude);
  }

  /// Obtiene la última ubicación conocida (más rápido pero puede ser obsoleta)
  Future<Position?> obtenerUltimaUbicacionConocida() async {
    try {
      if (!await tienePermisos()) {
        return null;
      }
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  // ========================================
  // MÉTODOS DE TRACKING EN TIEMPO REAL
  // ========================================

  /// Inicia el tracking de ubicación en tiempo real
  ///
  /// [sesionId] - ID de la sesión de ruta activa
  /// [config] - Configuración de tracking (opcional)
  Future<void> iniciarTracking({
    required String sesionId,
    TrackingConfig? config,
  }) async {
    try {
      // Verificar permisos
      if (!await tienePermisos()) {
        await solicitarPermisos();
      }

      // Detener tracking anterior si existe
      if (_trackingActivo) {
        await detenerTracking();
      }

      // Actualizar configuración
      if (config != null) {
        _config = config;
      }

      _sesionActiva = sesionId;
      _trackingActivo = true;

      // Solicitar permiso de notificaciones (Android 13+)
      // Necesario para que la notificación del foreground service sea visible
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          await Permission.notification.request();
        }
      }

      // Configurar stream de posición con Foreground Service en Android
      late final LocationSettings locationSettings;

      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: _config.precision,
          distanceFilter: _config.distanciaMinima.toInt(),
          intervalDuration: Duration(seconds: _config.intervaloMinimo),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'MotoConnect - Ubicación activa',
            notificationText: 'Compartiendo ubicación en tiempo real',
            notificationIcon: AndroidResource(
              name: 'ic_launcher',
              defType: 'mipmap',
            ),
            enableWakeLock: true,
            setOngoing: true,
            color: Colors.orangeAccent,
          ),
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: _config.precision,
          distanceFilter: _config.distanciaMinima.toInt(),
        );
      }

      // Suscribirse a cambios de posición
      _posicionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          _ultimaPosicion = position;

          // Emitir al stream local
          if (!_ubicacionController.isClosed) {
            _ubicacionController.add(position);
          }

          // Actualizar en Supabase
          await _actualizarUbicacionEnServidor(position);
        },
        onError: (error) {
          debugPrint('Error en tracking: $error');
          // Error en stream de posición → marcar como desconectado
          if (_conectado) {
            _conectado = false;
            if (!_conectadoController.isClosed) {
              _conectadoController.add(false);
            }
            debugPrint('🔴 Conexión perdida (error en stream de posición)');
          }
        },
      );

      // Suscribirse al estado del servicio GPS
      _gpsSubscription = Geolocator.getServiceStatusStream().listen(
        (ServiceStatus status) {
          if (status == ServiceStatus.disabled && _conectado) {
            _conectado = false;
            if (!_conectadoController.isClosed) {
              _conectadoController.add(false);
            }
            debugPrint('🔴 GPS desactivado');
          } else if (status == ServiceStatus.enabled && !_conectado) {
            _conectado = true;
            if (!_conectadoController.isClosed) {
              _conectadoController.add(true);
            }
            debugPrint('🟢 GPS reactivado');
          }
        },
      );

      // OPTIMIZACIÓN: Intentar obtener última ubicación conocida primero (instantáneo)
      // En lugar de esperar 10-30s por GPS frío con getCurrentPosition()
      final ultimaUbicacion = await obtenerUltimaUbicacionConocida();
      if (ultimaUbicacion != null) {
        // Usar última conocida inmediatamente
        _ultimaPosicion = ultimaUbicacion;
        await _actualizarUbicacionEnServidor(ultimaUbicacion);
      }
      // No esperar por getCurrentPosition() - el stream lo hará en background

      // Reemplazar notificación de geolocator con una no-deslizable
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _notificationChannel.invokeMethod('showTrackingNotification');
        } catch (e) {
          debugPrint('Error al mostrar notificación persistente: $e');
        }
      }
    } catch (e) {
      _trackingActivo = false;
      throw Exception('Error al iniciar tracking: ${e.toString()}');
    }
  }

  /// Detiene el tracking de ubicación
  Future<void> detenerTracking() async {
    _trackingActivo = false;
    _sesionActiva = null;
    await _posicionSubscription?.cancel();
    _posicionSubscription = null;
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _fallosConsecutivos = 0;
    _conectado = true;

    // Cancelar notificación persistente (red de seguridad)
    if (Platform.isAndroid) {
      try {
        await _notificationChannel.invokeMethod('hideTrackingNotification');
      } catch (e) {
        debugPrint('Error al ocultar notificación persistente: $e');
      }
    }
  }

  /// Pausa el tracking temporalmente
  void pausarTracking() {
    _posicionSubscription?.pause();
  }

  /// Reanuda el tracking
  void reanudarTracking() {
    _posicionSubscription?.resume();
  }

  /// Cambia la configuración de tracking
  Future<void> cambiarConfiguracion(TrackingConfig nuevaConfig) async {
    _config = nuevaConfig;

    // Si el tracking está activo, reiniciarlo con la nueva configuración
    if (_trackingActivo && _sesionActiva != null) {
      final sesionId = _sesionActiva!;
      await detenerTracking();
      await iniciarTracking(sesionId: sesionId, config: nuevaConfig);
    }
  }

  // ========================================
  // MÉTODOS AUXILIARES
  // ========================================

  /// Actualiza la ubicación en el servidor
  Future<void> _actualizarUbicacionEnServidor(Position position) async {
    if (_sesionActiva == null) return;

    try {
      await _grupoRepository.actualizarUbicacion(
        sesionId: _sesionActiva!,
        latitud: position.latitude,
        longitud: position.longitude,
        velocidad: position.speed * 3.6, // m/s a km/h
        direccion: position.heading,
        altitud: position.altitude,
        precisionMetros: position.accuracy,
      );

      // Éxito: resetear contador de fallos
      _fallosConsecutivos = 0;
      if (!_conectado) {
        _conectado = true;
        if (!_conectadoController.isClosed) {
          _conectadoController.add(true);
        }
        debugPrint('🟢 Conexión restaurada (envío exitoso)');
      }
    } catch (e) {
      debugPrint('Error al actualizar ubicación en servidor: $e');
      // No lanzar excepción para no interrumpir el tracking

      // Incrementar fallos consecutivos
      _fallosConsecutivos++;
      if (_fallosConsecutivos >= 3 && _conectado) {
        _conectado = false;
        if (!_conectadoController.isClosed) {
          _conectadoController.add(false);
        }
        debugPrint('🔴 Conexión perdida ($_fallosConsecutivos fallos consecutivos)');
      }
    }
  }

  /// Calcula la distancia entre dos posiciones en metros
  double calcularDistancia({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calcula la distancia desde la posición actual a un punto
  Future<double> calcularDistanciaDesdeUbicacionActual({
    required double lat,
    required double lng,
  }) async {
    final position = await obtenerUbicacionActual();
    return calcularDistancia(
      lat1: position.latitude,
      lng1: position.longitude,
      lat2: lat,
      lng2: lng,
    );
  }

  // ========================================
  // CLEANUP
  // ========================================

  /// Libera recursos
  void dispose() {
    detenerTracking();
    _ubicacionController.close();
    _conectadoController.close();
  }
}
