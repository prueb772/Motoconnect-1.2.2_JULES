import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/supabase_config.dart';
import 'services/notification_service.dart';

// SCREENS - Archivos en lib/presentation/views/
import 'presentation/views/auth/splash_screen.dart';
import 'presentation/views/auth/login_screen.dart';
import 'presentation/views/auth/register_screen.dart';
import 'presentation/views/home/home_screen.dart';
import 'presentation/views/profile/profile_screen.dart';
import 'presentation/views/auth/reset_password_screen.dart';

// VIEWS - Archivos en lib/presentation/views/
import 'presentation/views/events/events_screen.dart';
import 'presentation/views/routes/rutas_screen.dart';
import 'presentation/views/routes/saved_routes_screen.dart';
import 'presentation/views/talleres/talleres_screen.dart';
import 'presentation/views/community/community_screen.dart';
import 'presentation/views/routes/map_picker_screen.dart';
import 'presentation/views/grupos/grupos_screen.dart';
import 'presentation/views/grupos/detalle_grupo_screen.dart';
import 'presentation/views/events/event_detail_screen.dart';
import 'data/repositories/grupo_repository.dart';
import 'data/repositories/impl/grupo_repository_impl.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/impl/auth_repository_impl.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/impl/profile_repository_impl.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/impl/event_repository_impl.dart';
import 'data/repositories/routes_repository.dart';
import 'data/repositories/impl/routes_repository_impl.dart';
import 'data/repositories/saved_routes_repository.dart';
import 'data/repositories/impl/saved_routes_repository_impl.dart';
import 'data/repositories/navigation_repository.dart';
import 'data/repositories/impl/navigation_repository_impl.dart';
import 'data/repositories/community_repository.dart';
import 'data/repositories/impl/community_repository_impl.dart';
import 'data/repositories/taller_repository.dart';
import 'data/repositories/impl/taller_repository_impl.dart';
import 'data/models/grupo_ruta_model.dart';
import 'data/models/ruta_realizada_model.dart';

import 'presentation/blocs/theme/theme_cubit.dart';
import 'presentation/blocs/auth/auth/auth_bloc.dart';
import 'core/theme/app_theme.dart';

/// Handler de mensajes FCM en background/terminated — debe ser top-level.
/// Para mensajes con payload 'notification', FCM muestra la notificación
/// automáticamente. Este handler cubre mensajes data-only.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Solo actuar si NO hay notification payload (data-only message)
  if (message.notification != null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    'eventos_channel',
    'Eventos MotoConnect',
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final type = message.data['type'] as String? ?? '';
  final refId = message.data['id'] ??
      message.data['event_id'] ??
      message.data['sesion_id'] ??
      '';
  final notifId = (refId as String).isNotEmpty
      ? (type + refId).hashCode.abs()
      : DateTime.now().millisecondsSinceEpoch.remainder(100000);

  final isSession = type == 'session' ||
      type == 'session_started' ||
      type == 'member_joined' ||
      type == 'session_ended' ||
      type == 'member_left';

  await plugin.show(
    notifId,
    message.data['title'] ?? (isSession ? 'Sesión grupal' : 'Nuevo Evento'),
    message.data['body'] ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        isSession ? 'sesiones_channel' : 'eventos_channel',
        isSession ? 'Sesiones Grupales' : 'Eventos MotoConnect',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    // Payload necesario para que _onNotificationTap pueda navegar al tocar
    payload: jsonEncode(message.data),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase (requerido por firebase_messaging)
  await Firebase.initializeApp();

  // Registra handler de mensajes FCM en background/terminated
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

  // Inicializa el formato de fechas para español
  await initializeDateFormatting('es_ES', null);

  // Inicializa Supabase usando SupabaseConfig
  await SupabaseConfig.initialize(
    url: 'https://otxzwutudsruildrtuzy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90eHp3dXR1ZHNydWlsZHJ0dXp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4NDk2OTIsImV4cCI6MjA3ODQyNTY5Mn0.cAfcpSPDGdfDDNbk6bq6KiGdzuQhsOLUAcGz7dNwE5w',
  );

  // Cargar preferencia de tema ANTES de runApp para evitar flash de tema incorrecto
  final savedThemeMode = await ThemeCubit.loadSavedTheme();

  // MultiRepositoryProvider + MultiBlocProvider para gestión de estado global
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (context) => ProfileRepositoryImpl(),
        ),
        RepositoryProvider<GrupoRepository>(
          create: (context) => GrupoRepositoryImpl(),
        ),
        RepositoryProvider<EventRepository>(
          create: (context) => EventRepositoryImpl(),
        ),
        RepositoryProvider<RoutesRepository>(
          create: (context) => RoutesRepositoryImpl(),
        ),
        RepositoryProvider<SavedRoutesRepository>(
          create: (context) => SavedRoutesRepositoryImpl(),
        ),
        RepositoryProvider<NavigationRepository>(
          create: (context) => NavigationRepositoryImpl(),
        ),
        RepositoryProvider<CommunityRepository>(
          create: (context) => CommunityRepositoryImpl(),
        ),
        RepositoryProvider<TallerRepository>(
          create: (context) => TallerRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(const AuthStarted()),
          ),
          BlocProvider<ThemeCubit>(
            create: (_) => ThemeCubit(initialMode: savedThemeMode),
          ),
        ],
        child: const MotoConnectApp(),
      ),
    ),
  );

  // Inicializa notificaciones DESPUÉS de runApp para que el Activity
  // de Android esté activo cuando se soliciten permisos y el token FCM
  await NotificationService.instance.initialize();
}

class MotoConnectApp extends StatefulWidget {
  const MotoConnectApp({super.key});

  @override
  State<MotoConnectApp> createState() => _MotoConnectAppState();
}

class _MotoConnectAppState extends State<MotoConnectApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Manejar notificación que abrió la app desde estado terminado.
    // Se ejecuta tras el primer frame para que el navigator esté listo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.checkInitialMessage();
    });

    // Inicializar deep links para reset de contraseña
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Verificar si la app fue abierta por un deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error al obtener deep link inicial: $e');
    }

    // Escuchar deep links mientras la app está abierta
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (err) {
        debugPrint('Error en deep link stream: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    // Verificar si es un callback de reset de contraseña
    // El URI será: io.supabase.motoconnect://reset-callback#access_token=...
    if (uri.host == 'reset-callback') {
      // Supabase ya maneja la sesión automáticamente con el token del fragment
      // Navegar a la pantalla de nueva contraseña
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/reset-password',
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MotoConnect',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,

          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/registro': (context) => const RegistroScreen(),
            '/home': (context) => const HomeScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/eventos': (context) => const EventosScreen(),
            '/rutas': (context) {
              final arguments = ModalRoute.of(context)?.settings.arguments;
              RutaRealizadaModel? rutaInicialArgs;
              if (arguments != null && arguments is RutaRealizadaModel) {
                rutaInicialArgs = arguments;
              }
              return RutasScreen(rutaInicial: rutaInicialArgs);
            },
            '/rutas-recomendadas': (context) => const RutasRecomendadasScreen(),
            '/talleres': (context) => const TalleresScreen(),
            '/comunidad': (context) => const ComunidadScreen(),
            '/grupos': (context) => const GruposScreen(),
            '/grupo-detalle': (context) {
              final grupoId =
                  ModalRoute.of(context)!.settings.arguments as String;
              return _GrupoDetalleLoader(grupoId: grupoId);
            },
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/evento-detalle': (context) {
              final eventId =
                  ModalRoute.of(context)!.settings.arguments as String;
              return EventDetailScreen(eventId: eventId);
            },
            '/map-picker': (context) => const MapPickerScreen(),
          },
        );
      },
    );
  }
}

/// Widget puente para navegación por notificación hacia un grupo específico.
///
/// Carga el [GrupoRutaModel] por ID y muestra [DetalleGrupoScreen].
/// Si el grupo no existe, redirige a la lista de grupos.
class _GrupoDetalleLoader extends StatelessWidget {
  final String grupoId;

  const _GrupoDetalleLoader({required this.grupoId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GrupoRutaModel?>(
      future: context.read<GrupoRepository>().obtenerGrupo(grupoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final grupo = snapshot.data;
        if (grupo == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/grupos');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DetalleGrupoScreen(grupo: grupo);
      },
    );
  }
}
