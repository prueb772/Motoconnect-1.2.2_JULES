/// Servicio de Notificaciones Push (FCM)
///
/// Responsabilidades:
/// - Inicializar Firebase Messaging
/// - Solicitar permisos de notificación
/// - Registrar y actualizar el token FCM en Supabase
/// - Mostrar notificaciones locales cuando la app está en primer plano
/// - Manejar taps en notificaciones para navegar al evento correspondiente

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/api/notification_api_service.dart';
import '../data/models/notification_payload_model.dart';

/// Canal Android para notificaciones de eventos.
const _eventosChannel = AndroidNotificationChannel(
  'eventos_channel',
  'Eventos MotoConnect',
  description: 'Notificaciones de nuevos eventos y recordatorios',
  importance: Importance.high,
  playSound: true,
  showBadge: true,
);

/// Canal Android para notificaciones de sesiones grupales.
const _sesionesChannel = AndroidNotificationChannel(
  'sesiones_channel',
  'Sesiones Grupales',
  description: 'Notificaciones de sesiones de ruta en grupo',
  importance: Importance.high,
  playSound: true,
  showBadge: true,
);

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationApiService _apiService = NotificationApiService();

  String? _currentToken;

  // ========================================
  // INICIALIZACIÓN
  // ========================================

  /// Inicializa el servicio completo de notificaciones.
  ///
  /// Debe llamarse en main.dart después de inicializar Supabase.
  Future<void> initialize() async {
    await _configurarLocalNotifications();
    await _solicitarPermisos();
    _configurarHandlers();
    await _registrarToken();
  }

  Future<void> _configurarLocalNotifications() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_eventosChannel);
    await androidPlugin?.createNotificationChannel(_sesionesChannel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );
  }

  Future<void> _solicitarPermisos() async {
    // Permiso FCM (Android 13+ muestra el diálogo del sistema)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // flutter_local_notifications también necesita el permiso explícito en Android 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _configurarHandlers() {
    // Mensaje recibido con app en PRIMER PLANO → mostrar notificación local
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Tap en notificación con app en SEGUNDO PLANO (ya abierta)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Token actualizado por FCM → sincronizar con Supabase
    _fcm.onTokenRefresh.listen(_onTokenRefresh);
  }

  // ========================================
  // GESTIÓN DE TOKEN
  // ========================================

  /// Obtiene el token FCM actual y lo guarda en Supabase.
  Future<void> _registrarToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      _currentToken = token;
      await _saveTokenToSupabase(token);
    }
  }

  /// Llamar cuando el usuario se autentica para asegurar que el token esté registrado.
  Future<void> refreshToken() async {
    await _registrarToken();
  }

  /// Elimina el token FCM de Supabase al cerrar sesión.
  Future<void> deleteToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && _currentToken != null) {
      await _apiService.deleteToken(userId: userId, token: _currentToken!);
    }
    _currentToken = null;
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _apiService.saveToken(userId: userId, token: token);
  }

  Future<void> _onTokenRefresh(String newToken) async {
    _currentToken = newToken;
    await _saveTokenToSupabase(newToken);
  }

  // ========================================
  // MANEJO DE MENSAJES
  // ========================================

  /// Muestra notificación local cuando la app está en primer plano.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final payload = NotificationPayloadModel.fromJson(message.data);
    final type = payload.type ?? '';
    final isSessionNotif = type == 'session' ||
        type == 'session_started' ||
        type == 'member_joined' ||
        type == 'session_ended' ||
        type == 'member_left';

    // ID estable basado en el identificador relevante para evitar duplicados
    final refId = payload.id ??
        payload.sesionId ??
        payload.eventId ??
        '';
    final notifId = refId.isNotEmpty
        ? (type + refId).hashCode.abs()
        : DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final channelId = isSessionNotif ? 'sesiones_channel' : 'eventos_channel';
    final channelName = isSessionNotif ? 'Sesiones Grupales' : 'Eventos MotoConnect';
    final channelDesc = isSessionNotif
        ? 'Notificaciones de sesiones de ruta en grupo'
        : 'Notificaciones de nuevos eventos y recordatorios';

    await _localNotifications.show(
      notifId,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(payload.toJson()),
    );
  }

  /// Navega al evento cuando el usuario toca la notificación.
  void _handleNotificationTap(RemoteMessage message) {
    _navigateToEvent(NotificationPayloadModel.fromJson(message.data));
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateToEvent(NotificationPayloadModel.fromJson(data));
    } catch (_) {}
  }

  void _navigateToEvent(NotificationPayloadModel payload) {
    if (navigatorKey.currentState == null) return;

    final type = payload.type ?? '';

    // Soporta ambos formatos de payload:
    //   Nuevo:   { "type": "event"|"session", "id": "<uuid>", "grupo_id": "<uuid>" }
    //   Legacy:  { "type": "session_started"|..., "event_id": "...", "sesion_id": "..." }
    final id = payload.id;
    final eventId =
        (id != null && id.isNotEmpty) ? id : payload.eventId;
    final grupoId = payload.grupoId;

    final isSession = type == 'session' ||
        type == 'session_started' ||
        type == 'member_joined' ||
        type == 'session_ended' ||
        type == 'member_left';

    if (isSession) {
      if (grupoId != null && grupoId.isNotEmpty) {
        navigatorKey.currentState!.pushNamed('/grupo-detalle', arguments: grupoId);
      } else {
        navigatorKey.currentState!.pushNamed('/grupos');
      }
    } else if (eventId != null && eventId.isNotEmpty) {
      navigatorKey.currentState!.pushNamed(
        '/evento-detalle',
        arguments: eventId,
      );
    } else {
      navigatorKey.currentState!.pushNamed('/eventos');
    }
  }

  /// Llama esto una vez que el navigator está listo para manejar el caso
  /// en que la app estaba terminada y el usuario tocó la notificación.
  Future<void> checkInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      _navigateToEvent(NotificationPayloadModel.fromJson(message.data));
    }
  }

  /// Muestra una notificación local inmediata en el canal de sesiones.
  ///
  /// Usado para eventos detectados en el cliente (ej: participante abandonó).
  Future<void> showLocalSesionNotification({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sesiones_channel',
          'Sesiones Grupales',
          channelDescription: 'Notificaciones de sesiones de ruta en grupo',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

/// Key global del Navigator para navegar desde fuera del árbol de widgets.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Callback top-level requerido por flutter_local_notifications para taps
/// recibidos cuando la app estaba en segundo plano.
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // El navigator no está disponible en este contexto; la navegación
  // se maneja al abrir la app vía getInitialMessage.
}
