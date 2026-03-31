import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/sesion_ruta_activa_model.dart';
import '../../../data/models/grupo_ruta_model.dart';
import '../../../data/models/ubicacion_tiempo_real_model.dart';
import '../../../data/models/navigation_progress.dart';
import '../../../data/models/participante_sesion_model.dart';
import '../../../data/models/navigation_step.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../../data/repositories/navigation_repository.dart';
import '../../blocs/auth/auth/auth_bloc.dart';
import '../../../data/services/navigation/google_directions_service.dart';
import '../../../data/services/navigation/navigation_tracking_service.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/marker_state_manager.dart';
import '../../../services/navigation_voice_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../widgets/grupos/solicitudes_pendientes_dialog.dart';
import '../../widgets/location_search_field.dart';
import '../navigation/navigation_screen.dart';
import '../../../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

/// Estados de conexión local por participante (solo para UI, no persiste en BD).
///
/// Se calcula en el cliente basándose en el tiempo transcurrido desde la
/// última ubicación recibida.
enum _EstadoConexion {
  /// Ubicación recibida hace menos de 60 s → verde
  activo,

  /// Sin ubicación entre 60 s y 180 s → amarillo (retraso normal)
  sinActualizacion,

  /// Sin ubicación más de 180 s → gris/rojo (probable corte de red)
  sinConexion,

  /// El usuario pausó manualmente el tracking → naranja
  pausado,
}

/// Pantalla de mapa compartido con ubicaciones en tiempo real
///
/// Muestra la ubicación de todos los miembros del grupo en un mapa
class MapaCompartidoScreen extends StatefulWidget {
  final SesionRutaActivaModel sesion;
  final GrupoRutaModel grupo;

  const MapaCompartidoScreen({
    super.key,
    required this.sesion,
    required this.grupo,
  });

  @override
  State<MapaCompartidoScreen> createState() => _MapaCompartidoScreenState();
}

class _MapaCompartidoScreenState extends State<MapaCompartidoScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  late final GrupoRepository _grupoRepository;
  late final NavigationRepository _navigationRepository;
  final LocationTrackingService _trackingService = LocationTrackingService();
  late final GoogleDirectionsService _directionsService;

  Map<String, Marker> _markers = {};
  Map<String, NavigationProgress> _navigationProgress = {};

  // Gestor de estados de marcadores con retry y cache TTL
  late final MarkerStateManager _markerManager;

  // Map de participantes para lookup O(1) eficiente
  Map<String, ParticipanteSesionModel> _participantesMap = {};

  StreamSubscription? _ubicacionesSubscription;
  StreamSubscription? _navigationProgressSubscription;
  StreamSubscription? _participantesSubscription;
  StreamSubscription? _rutaCompartidaSubscription;
  StreamSubscription? _estadoSesionSubscription;
  StreamSubscription<bool>? _conectadoSubscription;
  bool _trackingActivo = false;
  String? _miUsuarioId;

  // Ruta compartida
  Map<String, dynamic>? _rutaCompartida;
  Polyline? _polylineCompartida;
  List<NavigationStep>? _navigationSteps; // Steps de navegación por voz
  int? _currentStepIndex; // Índice del paso actual
  StreamSubscription<Position>?
  _navigationLocationSubscription; // Para tracking durante navegación
  late final NavigationVoiceService _voiceService; // Servicio de voz

  // ── Mejoras de navegación ─────────────────────────────────────────────
  late final NavigationTrackingService _navTrackingService;

  /// Puntos de la polyline completa (referencia inmutable para recorte)
  List<LatLng> _completePolylinePoints = [];

  /// Distancia en metros al final del step actual (actualiza en tiempo real)
  double? _distanceToNextStepMeters;

  /// Distancia en metros al destino final (solo en último paso, para auto-llegada y botón "Ya llegué")
  double? _distanceToDestinationMeters;

  /// Distancia total restante hasta el destino (metros)
  double _remainingDistanceMeters = 0;

  /// Duración restante estimada (segundos)
  int _remainingDurationSeconds = 0;

  /// Timestamp en que se detectó salida de ruta (para auto-recalcular)
  DateTime? _offRouteSince;

  /// Segundos fuera de ruta antes de recalcular automáticamente
  /// Alineado con NavigationBloc (Rutas) = 3 segundos
  static const int _offRouteTriggerSeconds = 3;

  /// Evita recalculaciones concurrentes: true mientras una está en progreso
  bool _isRecalculating = false;

  // ── Voice announcement state ──────────────────────────────────────────
  bool _voiceProximity200Fired = false;
  bool _voiceProximity50Fired = false;

  // Nuevos campos para sistema de aprobación
  List<ParticipanteSesionModel> _participantes = [];
  bool _esLider = false;
  bool _estaAprobado = false;
  bool _trackingPausadoPorUsuario = false;
  bool _esAdminGrupo = false;
  bool _isInitializing = true;

  // Panel de participantes embebido (visible/oculto)
  bool _panelParticipantesVisible = false;

  // Staleness: última actualización de ubicación por usuario (para detectar
  // conexión perdida cuando el dispositivo no puede escribir en la BD)
  final Map<String, DateTime> _ultimaUbicacionPorUsuario = {};
  Timer? _timerRefreshPanel;

  // Ajuste manual del destino compartido (drag del marcador, solo local)
  LatLng? _destinoAjustado;

  // Estado de conexión
  bool _conexionPerdida = false;
  bool _mostrarMensajeRestablecida = false;
  Timer? _timerMensajeRestablecida;
  String _initializingMessage = 'Inicializando sesión...';
  double _initializingProgress = 0.0;

  // ── Flecha del usuario principal + seguimiento de cámara ──────────────
  BitmapDescriptor? _arrowIcon;
  bool _isCameraFollowing = true;
  bool _isProgrammaticMove = false;
  LatLng? _miPosicion;
  double _miHeading = 0.0;
  StreamSubscription<Position>? _miPosicionSubscription;

  // Cache para resolver race conditions
  List<ParticipanteSesionModel> _participantesCache = [];
  bool _participantesReady = false;
  List<UbicacionTiempoRealModel> _ubicacionesCache = [];
  bool _ubicacionesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inicializar gestor de marcadores
    _markerManager = MarkerStateManager();

    // OPTIMIZACIÓN: Setear _esLider y _estaAprobado INMEDIATAMENTE
    // usando datos locales para evitar flash de pantalla de espera
    _grupoRepository = context.read<GrupoRepository>();
    _navigationRepository = context.read<NavigationRepository>();
    
    final authState = context.read<AuthBloc>().state;
    _miUsuarioId = authState is AuthAuthenticated ? authState.user.id : null;
    _esLider = widget.sesion.iniciadaPor == _miUsuarioId;

    // Si es líder, está auto-aprobado
    if (_esLider) {
      _estaAprobado = true;
    }

    _directionsService = GoogleDirectionsService(
      apiKey: ApiConstants.googleMapsApiKey,
    );
    _navTrackingService = NavigationTrackingService();

    // Inicializar servicio de voz para navegación
    _voiceService = NavigationVoiceService();

    // Pre-generar icono de flecha para el usuario principal
    _createArrowIcon();

    // Esperar a que el primer frame se renderice antes de inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ubicacionesSubscription?.cancel();
    _navigationProgressSubscription?.cancel();
    _participantesSubscription?.cancel();
    _rutaCompartidaSubscription?.cancel();
    _estadoSesionSubscription?.cancel();
    _conectadoSubscription?.cancel();
    _timerMensajeRestablecida?.cancel();
    _timerRefreshPanel?.cancel();
    _navigationLocationSubscription?.cancel();
    _miPosicionSubscription?.cancel();
    if (_trackingActivo) {
      _trackingService.detenerTracking();
    }
    _trackingService.dispose();
    _mapController?.dispose();
    _markerManager.dispose();
    _voiceService.dispose(); // Limpiar servicio de voz
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _trackingActivo) {
      // Re-centrar mapa en última posición conocida al volver del segundo plano
      final ultimaPosicion = _trackingService.ultimaPosicion;
      if (ultimaPosicion != null) {
        _centrarMapa(LatLng(ultimaPosicion.latitude, ultimaPosicion.longitude));
        debugPrint('📍 App resumed: re-centrando mapa en última posición');
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint(
        '⏸️ App en segundo plano: foreground service mantiene ubicación activa',
      );
    }
  }

  /// Inicialización SECUENCIAL para evitar race conditions
  ///
  /// Orden crítico:
  /// 1. Verificar permisos
  /// 2. Cargar participantes (con await)
  /// 3. Pre-generar marcadores (con await)
  /// 4. Suscribirse a streams
  /// 5. Iniciar tracking si está aprobado
  Future<void> _inicializar() async {
    try {
      // 1. Verificar permisos (20%)
      if (mounted) {
        setState(() {
          _initializingMessage = 'Verificando permisos...';
          _initializingProgress = 0.2;
        });
      }
      await _verificarPermisos();

      // 2. CRÍTICO: Cargar participantes PRIMERO (40%)
      if (mounted) {
        setState(() {
          _initializingMessage = 'Cargando participantes...';
          _initializingProgress = 0.4;
        });
      }
      await _cargarParticipantesInicial();

      // 3. Pre-generar marcadores con AWAIT (70%)
      // OPTIMIZACIÓN: Solo en modo release para evitar bloqueo del hilo principal
      if (!kDebugMode) {
        if (mounted) {
          setState(() {
            _initializingMessage =
                'Preparando marcadores (${_participantesCache.length} participantes)...';
            _initializingProgress = 0.7;
          });
        }
        await _preGenerarMarcadores(_participantesCache);
        debugPrint('✅ Pre-generación de marcadores completa (modo release)');
      } else {
        debugPrint(
          '⚡ Pre-generación omitida en modo debug para mejor performance',
        );
        debugPrint(
          '   Los marcadores se generarán bajo demanda cuando se actualicen ubicaciones',
        );
      }

      // 4. Suscribirse a streams (90%)
      if (mounted) {
        setState(() {
          _initializingMessage = 'Conectando en tiempo real...';
          _initializingProgress = 0.9;
        });
      }
      _suscribirseAParticipantes();
      _suscribirseAUbicaciones();
      _suscribirseAProgresoNavegacion();
      _suscribirseARutaCompartida();
      _suscribirseAEstadoSesion();

      // 5. Timer para limpieza periódica de cache y diagnóstico
      Timer.periodic(const Duration(hours: 1), (_) {
        if (mounted) {
          final removed = _markerManager.evictStale();
          if (removed > 0) {
            debugPrint('🧹 Limpieza periódica: $removed marcadores removidos');
          }

          // Diagnóstico detallado cada hora
          _markerManager.printDiagnostics();
        }
      });

      // 6. Marcar como inicializado
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      // 7. Iniciar tracking si está aprobado
      if (_estaAprobado) {
        _iniciarTracking().catchError((e) {
          debugPrint('Error al iniciar tracking: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al iniciar ubicación: ${e.toString()}'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Reintentar',
                  onPressed: () => _iniciarTracking(),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error en inicialización: $e');

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dibuja una flecha de navegación en canvas y la convierte a BitmapDescriptor.
  Future<void> _createArrowIcon() async {
    const double size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final path =
        Path()
          ..moveTo(size / 2, 2)
          ..lineTo(size - 4, size - 4)
          ..lineTo(size / 2, size * 0.62)
          ..lineTo(4, size - 4)
          ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00BCD4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    if (mounted && data != null) {
      setState(() {
        _arrowIcon = BitmapDescriptor.bytes(data.buffer.asUint8List());
      });
    }
  }

  void _suscribirseAProgresoNavegacion() {
    _navigationProgressSubscription = _navigationRepository
        .streamGroupNavigationProgress(widget.sesion.id)
        .listen((progresos) {
          final progressMap = <String, NavigationProgress>{};
          for (final progreso in progresos) {
            progressMap[progreso.userId] = progreso;
          }

          setState(() {
            _navigationProgress = progressMap;
          });
        });
  }

  void _suscribirseAUbicaciones() {
    _ubicacionesSubscription = _grupoRepository
        .suscribirseAUbicaciones(widget.sesion.id)
        .listen((ubicaciones) async {
          // Registrar timestamp de última ubicación por usuario para staleness
          for (final u in ubicaciones) {
            _ultimaUbicacionPorUsuario[u.usuarioId] = u.ultimaActualizacion;
          }

          // Cachear ubicaciones
          _ubicacionesCache = ubicaciones;
          _ubicacionesReady = true;

          // Solo actualizar si participantes están listos
          // Esto evita la race condition donde ubicaciones llegan primero
          if (_participantesReady) {
            try {
              await _actualizarMarcadores(ubicaciones);
            } catch (e) {
              debugPrint('❌ Error al actualizar marcadores: $e');
            }
          } else {
            debugPrint(
              '⏳ Ubicaciones recibidas pero participantes no listos, esperando...',
            );
          }
        });
  }

  void _suscribirseARutaCompartida() {
    debugPrint(
      '📡 Suscribiendo a stream de ruta compartida para sesión: ${widget.sesion.id}',
    );

    _rutaCompartidaSubscription = _grupoRepository
        .streamRutaCompartida(widget.sesion.id)
        .listen(
          (ruta) async {
            debugPrint(
              '📡 Stream de ruta compartida emitió: ${ruta != null ? "nueva ruta" : "null (cancelada)"}',
            );

            if (ruta != null) {
              debugPrint(
                '   📍 Destino: ${ruta['destino_nombre'] ?? 'Sin nombre'}',
              );
              debugPrint(
                '   📍 Lat: ${ruta['destino_lat']}, Lng: ${ruta['destino_lng']}',
              );
            }

            setState(() {
              _rutaCompartida = ruta;
              _destinoAjustado =
                  null; // Resetear ajuste local cuando el líder cambia el destino
            });

            // Si hay ruta compartida, calcular polyline desde mi ubicación (con retry)
            if (ruta != null && _estaAprobado) {
              debugPrint('🗺️ Calculando polyline hacia destino con retry...');
              await _calcularPolylineHaciaDestinoConRetry(
                ruta['destino_lat'] as double,
                ruta['destino_lng'] as double,
              );
            } else {
              // Limpiar ruta cuando se cancela
              debugPrint('🧹 Limpiando polyline (stream emitió null)');

              // Detener navegación por voz si estaba activa
              if (_navigationSteps != null) {
                _detenerNavegacionPorVoz();
              }

              if (mounted) {
                setState(() {
                  _polylineCompartida = null;
                  if (_markers.containsKey('destino_compartido')) {
                    _markers.remove('destino_compartido');
                    debugPrint('✅ Marcador de destino removido');
                  }
                });
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Error en stream de ruta compartida: $error');
          },
          onDone: () {
            debugPrint('✅ Stream de ruta compartida completado');
          },
        );
  }

  void _suscribirseAEstadoSesion() {
    // Optimización: Solo el líder de la sesión no necesita escucharse a sí mismo
    // El admin del grupo SÍ necesita ver el dialog cuando él finaliza la sesión de otro
    if (_esLider) {
      debugPrint(
        '👑 Líder de sesión: No suscribirse a estado de sesión (es quien finaliza)',
      );
      return;
    }

    debugPrint(
      '📡 Suscribiendo a stream de estado de sesión: ${widget.sesion.id}',
    );

    _estadoSesionSubscription = _grupoRepository
        .streamEstadoSesion(widget.sesion.id)
        .listen(
          (sesion) async {
            if (sesion == null) {
              debugPrint('⚠️ Sesión eliminada de la base de datos');
              return;
            }

            debugPrint('🔔 Estado de sesión: ${sesion.estado}');

            if (sesion.estado == EstadoSesion.finalizada) {
              debugPrint('🛑 Sesión finalizada por el líder');

              // Detener tracking local (await para asegurar que la notificación se cancela)
              if (_trackingActivo) {
                _trackingActivo = false;
                await _trackingService.detenerTracking();
              }

              // Mostrar dialog
              if (mounted) {
                _mostrarDialogSesionFinalizada();
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Error en stream de estado de sesión: $error');
          },
        );
  }

  Future<void> _verificarPermisos() async {
    // Nota: _esLider ya fue seteado en initState() usando datos locales
    // Esto es más rápido y evita timing issues con la base de datos

    // Ejecutar las 2 queries restantes EN PARALELO
    final results = await Future.wait([
      _grupoRepository.esAdminDeGrupo(widget.grupo.id),
      // Si es líder, ya está auto-aprobado. Si no, verificar en BD
      _esLider
          ? Future.value(true)
          : _grupoRepository.estaAprobadoEnSesion(sesionId: widget.sesion.id),
    ]);

    _esAdminGrupo = results[0];
    _estaAprobado = results[1];

    setState(() {});

    // Si no está aprobado y no es líder, solicitar unirse
    if (!_estaAprobado && !_esLider) {
      // Ejecutar en segundo plano sin bloquear
      _solicitarUnirse().catchError((e) {
        debugPrint('Error al solicitar unirse: $e');
      });
    }
  }

  Future<void> _solicitarUnirse() async {
    try {
      await _grupoRepository.solicitarUnirseASesion(sesionId: widget.sesion.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Esperando aprobación del líder...',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al solicitar unirse: $e');
    }
  }

  /// Carga participantes iniciales de forma síncrona
  ///
  /// CRÍTICO: Este método se ejecuta ANTES de suscribirse a streams
  /// para evitar race condition donde ubicaciones llegan antes que participantes.
  Future<void> _cargarParticipantesInicial() async {
    debugPrint('📥 Cargando participantes iniciales...');

    try {
      final participantes = await _grupoRepository.obtenerParticipantes(
        widget.sesion.id,
      );

      if (mounted) {
        setState(() {
          _participantesCache = participantes;
          _participantes = participantes;
          _participantesMap = {for (final p in participantes) p.usuarioId: p};
          _participantesReady = true;
        });
      }

      debugPrint('✅ ${participantes.length} participantes cargados');
    } catch (e) {
      debugPrint('❌ Error al cargar participantes iniciales: $e');
      // No lanzar error, continuar con lista vacía
      // El stream actualizará cuando se conecte
      if (mounted) {
        setState(() {
          _participantesReady = true; // Marcar como listo aunque esté vacío
        });
      }
    }
  }

  void _suscribirseAParticipantes() {
    debugPrint(
      '📡 Suscribiendo a stream de participantes para sesión: ${widget.sesion.id}',
    );

    _participantesSubscription = _grupoRepository
        .streamParticipantes(widget.sesion.id)
        .listen(
          (participantes) async {
            debugPrint(
              '🔔 Stream de participantes emitió: ${participantes.length} participantes',
            );

            // Contar solicitudes pendientes
            final pendientes =
                participantes.where((p) => p.estaPendiente).length;
            final aprobados = participantes.where((p) => p.estaAprobado).length;
            debugPrint('   📋 Pendientes: $pendientes, Aprobados: $aprobados');

            // Detectar cambios de foto y invalidar cache
            for (final participante in participantes) {
              final cached = _participantesMap[participante.usuarioId];

              // Si URL de foto cambió, invalidar cache de ese usuario
              if (cached != null &&
                  cached.fotoPerfilUrl != participante.fotoPerfilUrl) {
                debugPrint(
                  '🔄 Foto cambiada para ${participante.nombreMostrar}: ${cached.fotoPerfilUrl} → ${participante.fotoPerfilUrl}',
                );
                _markerManager.invalidateUser(participante.usuarioId);
              }

              // Detectar cambios de tracking
              if (cached != null &&
                  cached.trackingActivo != participante.trackingActivo) {
                debugPrint(
                  '⏸️ Tracking cambiado para ${participante.nombreMostrar}: ${cached.trackingActivo} → ${participante.trackingActivo}',
                );
              }
            }

            // Detectar participantes que abandonaron la sesión y notificar localmente.
            // Solo si ya teníamos datos previos (evita falsos positivos al cargar).
            if (_participantesReady && _participantesMap.isNotEmpty) {
              final prevIds = _participantesMap.keys.toSet();
              final newIds = {for (final p in participantes) p.usuarioId};
              final departed = prevIds.difference(newIds);
              for (final userId in departed) {
                if (userId == _miUsuarioId)
                  continue; // El propio usuario salió a propósito
                final name =
                    _participantesMap[userId]?.nombreMostrar ??
                    'Un participante';
                NotificationService.instance.showLocalSesionNotification(
                  title: 'Un participante abandonó la sesión',
                  body: '$name ha abandonado la sesión',
                );
              }
            }

            setState(() {
              _participantes = participantes;
              _participantesCache = participantes;
              // OPTIMIZACIÓN: Crear map para lookup O(1) en _actualizarMarcadores
              _participantesMap = {
                for (final p in participantes) p.usuarioId: p,
              };
            });

            // PRE-GENERAR MARCADORES: Cargar fotos y crear marcadores inmediatamente
            // Esto asegura que las fotos estén en cache antes de que lleguen ubicaciones
            // Nota: No usar await aquí para no bloquear el stream
            _preGenerarMarcadores(participantes);

            // Buscar mi participante en esta sesión específica
            // IMPORTANTE: No usar orElse que retorna otro participante
            // Si el usuario no está en la lista, significa que no ha solicitado unirse
            ParticipanteSesionModel? miParticipante;
            try {
              miParticipante = participantes.firstWhere(
                (p) => p.usuarioId == _miUsuarioId,
              );
            } catch (e) {
              // Usuario no está en lista de participantes de esta sesión
              miParticipante = null;
            }

            // Solo procesar si el usuario ESTÁ en la lista de participantes
            if (miParticipante != null) {
              // Capturar en variable local para evitar problema de null-safety en async
              final participante = miParticipante;

              // Actualizar estado de pausa
              if (_trackingPausadoPorUsuario != !participante.trackingActivo) {
                setState(() {
                  _trackingPausadoPorUsuario = !participante.trackingActivo;
                });
              }

              // Si era no aprobado y ahora está aprobado, iniciar tracking
              if (!_estaAprobado && participante.estaAprobado) {
                _estaAprobado = true;
                _iniciarTracking();

                // Solo mostrar mensaje de aprobación si NO es el líder
                // El líder no necesita "ser aprobado", él crea la sesión
                if (mounted && !_esLider) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '¡Has sido aprobado! Compartiendo ubicación...',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            }

            // Si hay ubicaciones en cache esperando, actualizarlas ahora
            // Esto maneja el caso donde ubicaciones llegaron mientras participantes cargaban
            if (_ubicacionesCache.isNotEmpty && _ubicacionesReady) {
              debugPrint(
                '🔄 Actualizando marcadores con ubicaciones en cache...',
              );
              await _actualizarMarcadores(_ubicacionesCache);
            }
          },
          onError: (error) {
            debugPrint('❌ Error en stream de participantes: $error');
          },
          onDone: () {
            debugPrint('✅ Stream de participantes completado');
          },
        );
  }

  Future<void> _iniciarTracking() async {
    try {
      // Verificar y solicitar permisos (sin obtener ubicación)
      if (!await _trackingService.tienePermisos()) {
        // Mostrar mensaje de que se están solicitando permisos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor acepta los permisos de ubicación'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        await _trackingService.solicitarPermisos();
      }

      // Iniciar tracking (esto obtendrá ubicación en background)
      await _trackingService.iniciarTracking(
        sesionId: widget.sesion.id,
        config: TrackingConfig.estandar,
      );

      if (mounted) {
        setState(() {
          _trackingActivo = true;
        });

        // Suscribirse al stream de posición para flecha y cámara aérea
        _miPosicionSubscription?.cancel();
        _miPosicionSubscription = _trackingService.ubicacionStream.listen((
          position,
        ) {
          if (!mounted) return;
          final latLng = LatLng(position.latitude, position.longitude);
          final heading = position.heading < 0 ? 0.0 : position.heading;

          final arrowMarker = Marker(
            markerId: const MarkerId('mi_ubicacion'),
            position: latLng,
            rotation: heading,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            icon:
                _arrowIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            zIndex: 10,
            infoWindow: const InfoWindow(title: 'Tu ubicación'),
          );

          setState(() {
            _miPosicion = latLng;
            _miHeading = heading;
            _markers['mi_ubicacion'] = arrowMarker;
          });

          // Vista aérea sin ruta activa; con ruta activa _actualizarCamaraNavegacion lo maneja
          if (_isCameraFollowing && _navigationSteps == null) {
            _isProgrammaticMove = true;
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: latLng,
                  zoom: 16.0,
                  bearing: 0.0,
                  tilt: 0.0,
                ),
              ),
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _isProgrammaticMove = false;
            });
          }
        });

        // Suscribirse a cambios de conectividad (internet + GPS)
        _conectadoSubscription?.cancel();
        _conectadoSubscription = _trackingService.conectadoStream.listen((
          conectado,
        ) async {
          if (!mounted) return;

          if (!conectado) {
            // Conexión perdida → inactivar tracking en BD + mostrar banner fijo
            try {
              await _grupoRepository.cambiarEstadoTracking(
                sesionId: widget.sesion.id,
                activo: false,
                conexionPerdida: true,
              );
            } catch (e) {
              debugPrint('Error al desactivar tracking por conexión: $e');
            }

            if (mounted) {
              setState(() {
                _conexionPerdida = true;
                _mostrarMensajeRestablecida = false;
              });
              _timerMensajeRestablecida?.cancel();
            }
          } else {
            // Conexión restaurada → reactivar solo si no fue pausa manual
            if (!_trackingPausadoPorUsuario) {
              try {
                await _grupoRepository.cambiarEstadoTracking(
                  sesionId: widget.sesion.id,
                  activo: true,
                  conexionPerdida: false,
                );
              } catch (e) {
                debugPrint('Error al reactivar tracking por conexión: $e');
              }

              if (mounted) {
                setState(() {
                  _conexionPerdida = false;
                  _mostrarMensajeRestablecida = true;
                });
                _timerMensajeRestablecida?.cancel();
                _timerMensajeRestablecida = Timer(
                  const Duration(seconds: 4),
                  () {
                    if (mounted) {
                      setState(() => _mostrarMensajeRestablecida = false);
                    }
                  },
                );
              }
            }
          }
        });

        // OPTIMIZACIÓN: Usar última ubicación conocida para centrar INMEDIATAMENTE
        // En lugar de esperar 10-30s por GPS frío
        final ultimaUbicacion =
            await _trackingService.obtenerUltimaUbicacionConocida();
        if (ultimaUbicacion != null) {
          _centrarMapa(
            LatLng(ultimaUbicacion.latitude, ultimaUbicacion.longitude),
          );
        }
        // Si no hay última ubicación, el stream actualizará cuando haya nueva posición
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar tracking: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Actualiza los marcadores en el mapa con fotos de perfil personalizadas
  ///
  /// OPTIMIZACIÓN: Usa cache para evitar regenerar marcadores en cada update.
  /// Usa _participantesMap para lookup O(1) en lugar de firstWhere O(n).
  /// MERGE PATTERN: Preserva marcadores adicionales (destino, etc.)
  Future<void> _actualizarMarcadores(
    List<UbicacionTiempoRealModel> ubicaciones,
  ) async {
    debugPrint('🗺️ Actualizando ${ubicaciones.length} marcadores...');

    // SAFEGUARD: Si participantes no están listos, esperar
    if (!_participantesReady && ubicaciones.isNotEmpty) {
      debugPrint('⚠️ Participantes aún no listos, esperando...');
      return;
    }

    final nuevosMarkers = <String, Marker>{};

    for (final ubicacion in ubicaciones) {
      final markerId = MarkerId(ubicacion.usuarioId);

      // OPTIMIZACIÓN: Lookup O(1) en lugar de firstWhere O(n)
      final participante = _participantesMap[ubicacion.usuarioId];

      // Si no hay participante, saltar (no debería pasar normalmente)
      if (participante == null) {
        debugPrint('⚠️ Participante no encontrado para ${ubicacion.usuarioId}');
        continue;
      }

      // El usuario principal tiene su propia flecha gestionada por el stream de posición
      if (ubicacion.usuarioId == _miUsuarioId) continue;

      final estaPausado = !participante.trackingActivo;
      final estaDesconectado = participante.conexionPerdida;

      // Obtener o crear marcador con retry automático
      // Tanto pausado como sin conexión usan el estilo grisado
      final icon = await _markerManager.getOrCreateMarker(
        userId: ubicacion.usuarioId,
        photoUrl: participante.fotoPerfilUrl,
        displayName: participante.nombreMostrar,
        isPaused: estaPausado || estaDesconectado,
      );

      // Etiqueta de estado para el infoWindow
      final String estadoLabel;
      if (estaDesconectado) {
        estadoLabel = ' (Sin conexión)';
      } else if (estaPausado) {
        estadoLabel = ' (Pausado)';
      } else {
        estadoLabel = '';
      }

      // Obtener progreso de navegación si existe
      final progreso = _navigationProgress[ubicacion.usuarioId];

      final marker = Marker(
        markerId: markerId,
        position: ubicacion.posicion,
        icon: icon,
        infoWindow: InfoWindow(
          title: participante.nombreMostrar + estadoLabel,
          snippet: _buildSnippet(ubicacion, progreso),
        ),
        rotation: ubicacion.direccion ?? 0,
      );

      nuevosMarkers[ubicacion.usuarioId] = marker;
      debugPrint(
        '📍 Marcador agregado al mapa: ${participante.nombreMostrar} en ${ubicacion.posicion}',
      );
    }

    debugPrint(
      '✅ ${nuevosMarkers.length} marcadores creados, actualizando mapa...',
    );

    // MERGE PATTERN: Preservar marcadores adicionales (destino, etc.)
    if (mounted) {
      setState(() {
        // Optimización: Crear set de IDs de ubicación para lookup O(1)
        final ubicacionIds = ubicaciones.map((u) => u.usuarioId).toSet();

        // Preservar solo marcadores que NO son de ubicaciones de participantes
        // (como destino_compartido, waypoints, etc.)
        final marcadoresNoUbicacion = <String, Marker>{};
        for (final entry in _markers.entries) {
          if (!ubicacionIds.contains(entry.key)) {
            marcadoresNoUbicacion[entry.key] = entry.value;
          }
        }

        _markers = {
          // 1. Marcadores existentes que NO son de ubicación
          ...marcadoresNoUbicacion,

          // 2. Nuevos marcadores de ubicación (sobrescriben si existen)
          ...nuevosMarkers,
        };
      });
    }
  }

  /// Pre-genera marcadores para todos los participantes
  ///
  /// Esto carga las fotos de perfil y crea los marcadores inmediatamente
  /// cuando se cargan los participantes, asegurando que estén en cache
  /// antes de que lleguen las ubicaciones.
  ///
  /// Usa límite de concurrencia para no saturar la red.
  Future<void> _preGenerarMarcadores(
    List<ParticipanteSesionModel> participantes,
  ) async {
    debugPrint(
      '🎨 Pre-generando marcadores para ${participantes.length} participantes...',
    );

    // Paralelizar generación con límite de concurrencia
    const maxConcurrent = 5;

    for (var i = 0; i < participantes.length; i += maxConcurrent) {
      final batch = participantes.skip(i).take(maxConcurrent);
      final futures = <Future>[];

      for (final participante in batch) {
        // Generar versión activa y pausada
        for (final estaPausado in [false, true]) {
          futures.add(
            _markerManager
                .getOrCreateMarker(
                  userId: participante.usuarioId,
                  photoUrl: participante.fotoPerfilUrl,
                  displayName: participante.nombreMostrar,
                  isPaused: estaPausado,
                )
                .catchError((e) {
                  debugPrint(
                    '❌ Error pre-generando marcador: ${participante.nombreMostrar} - $e',
                  );
                  return BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueCyan,
                  );
                }),
          );
        }
      }

      // AWAIT batch antes de continuar
      await Future.wait(futures);
    }

    final stats = _markerManager.getStats();
    debugPrint('✅ Pre-generación completa. Stats: $stats');
  }

  String _buildSnippet(
    UbicacionTiempoRealModel ubicacion,
    NavigationProgress? progreso,
  ) {
    final parts = <String>[];

    if (ubicacion.velocidad != null && ubicacion.velocidad! > 0) {
      parts.add('${ubicacion.velocidad!.toStringAsFixed(1)} km/h');
    }

    // Agregar info de navegación si está navegando
    if (progreso != null) {
      parts.add('Paso ${progreso.currentStepIndex + 1}');
      if (progreso.etaSeconds != null) {
        parts.add('ETA: ${progreso.etaText}');
      }
    }

    parts.add(ubicacion.tiempoTranscurrido);

    return parts.join(' • ');
  }

  void _centrarMapa(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sesion.nombreSesion),
            Text(widget.grupo.nombre, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_trackingActivo)
            const Icon(Icons.circle, color: Colors.green, size: 12),
          // Botón de solicitudes pendientes (solo líder)
          if (_esLider) _buildBotonSolicitudes(),
          // Botón de iniciar ruta (solo líder, solo si no hay ruta activa)
          if (_esLider && _rutaCompartida == null)
            TextButton.icon(
              onPressed: _mostrarIniciarRuta,
              icon: const Icon(Icons.route, size: 18),
              label: const Text('Iniciar ruta'),
            ),
          // Botón de cancelar ruta (solo líder, solo si hay ruta activa)
          if (_esLider && _rutaCompartida != null)
            TextButton.icon(
              onPressed: _confirmarCancelarRuta,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancelar ruta'),
            ),
        ],
      ),
      body: Stack(
        children: [
          // OPTIMIZACIÓN: Siempre mostrar GoogleMap (no ternario que causa flash)
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 15,
            ),
            markers: Set<Marker>.of(_markers.values),
            polylines:
                _polylineCompartida != null ? {_polylineCompartida!} : {},
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMoveStarted: () {
              if (!_isProgrammaticMove && _isCameraFollowing) {
                setState(() => _isCameraFollowing = false);
              }
            },
          ),
          // Banner de estado de conexión
          if (_conexionPerdida || _mostrarMensajeRestablecida)
            _buildBannerConexion(),
          // Tarjeta de instrucciones de navegación
          _buildTarjetaNavegacion(),
          // Panel inferior de progreso (tiempo/distancia restantes)
          _buildNavInfoBottomBar(),
          // Panel de participantes embebido (se reconstruye con setState)
          _buildPanelParticipantesOverlay(),
          // Overlay de carga durante inicialización
          if (_isInitializing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _initializingProgress,
                        strokeWidth: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.teal,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _initializingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_initializingProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Overlay de espera de aprobación (solo para participantes NO aprobados)
          if (!_estaAprobado && !_esLider && !_isInitializing)
            _buildPantallaEspera(),
        ],
      ),
    );
  }


  Future<void> _togglePausarUbicacion() async {
    try {
      final nuevoEstado = !_trackingPausadoPorUsuario;

      // Actualizar en base de datos
      await _grupoRepository.cambiarEstadoTracking(
        sesionId: widget.sesion.id,
        activo: !nuevoEstado,
      );

      // Pausar o reanudar tracking local
      if (nuevoEstado) {
        _trackingService.pausarTracking();
      } else {
        _trackingService.reanudarTracking();
      }

      setState(() {
        _trackingPausadoPorUsuario = nuevoEstado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado
                  ? 'Ubicación pausada. Otros no verán tu posición.'
                  : 'Ubicación reanudada. Compartiendo posición...',
            ),
            backgroundColor: nuevoEstado ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _salirDeSesion() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Salir de la sesión'),
            content: const Text(
              '¿Deseas salir de la sesión? Dejarás de compartir tu ubicación '
              'y serás eliminado de la sesión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('SALIR'),
              ),
            ],
          ),
    );

    if (confirmacion == true && mounted) {
      try {
        await _trackingService.detenerTracking();
        await _grupoRepository.salirDeSesion(widget.sesion.id);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al salir de la sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _finalizarSesion() async {
    // Validar permisos: solo líder o admin del grupo pueden finalizar
    if (!_esLider && !_esAdminGrupo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solo el líder de la sesión o administradores del grupo pueden finalizar la sesión.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Finalizar Sesión'),
            content: const Text(
              '¿Estás seguro de que deseas finalizar esta sesión? '
              'Esto detendrá el tracking para todos los participantes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('FINALIZAR'),
              ),
            ],
          ),
    );

    if (confirmacion == true && mounted) {
      try {
        await _grupoRepository.finalizarSesion(widget.sesion.id);
        await _trackingService.detenerTracking();

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al finalizar sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildBotonSolicitudes() {
    final pendientes = _participantes.where((p) => p.estaPendiente).length;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: _mostrarSolicitudesPendientes,
        ),
        if (pendientes > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$pendientes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _mostrarSolicitudesPendientes() {
    // Validar que solo el líder puede aprobar/rechazar
    if (!_esLider) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solo el líder de la sesión puede aprobar participantes.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final pendientes = _participantes.where((p) => p.estaPendiente).toList();

    showDialog(
      context: context,
      builder:
          (context) => SolicitudesPendientesDialog(
            solicitudes: pendientes,
            onAprobar: (participanteId) async {
              // Doble validación por seguridad
              if (!_esLider) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Solo el líder puede aprobar participantes.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              try {
                await _grupoRepository.aprobarParticipante(
                  participanteId: participanteId,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al aprobar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            onRechazar: (participanteId) async {
              // Doble validación por seguridad
              if (!_esLider) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Solo el líder puede rechazar participantes.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              try {
                await _grupoRepository.rechazarParticipante(
                  participanteId: participanteId,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al rechazar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  Widget _buildPantallaEspera() {
    // Obtener todos los participantes pendientes (incluyendo el usuario actual)
    final participantesPendientes =
        _participantes.where((p) => p.estaPendiente).toList();

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(Icons.hourglass_empty, size: 32, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sala de Espera',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Esperando aprobación del líder',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mensaje informativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu solicitud ha sido enviada. El líder recibirá una notificación para aprobarte.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Título de lista
              Row(
                children: [
                  Text(
                    'Personas en espera',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${participantesPendientes.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de participantes pendientes
              Expanded(
                child:
                    participantesPendientes.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando participantes...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          itemCount: participantesPendientes.length,
                          itemBuilder: (context, index) {
                            final participante = participantesPendientes[index];
                            final esTu = participante.usuarioId == _miUsuarioId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side:
                                    esTu
                                        ? BorderSide(
                                          color: Colors.teal,
                                          width: 2,
                                        )
                                        : BorderSide.none,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.teal,
                                      backgroundImage:
                                          participante.fotoPerfilUrl != null
                                              ? NetworkImage(
                                                participante.fotoPerfilUrl!,
                                              )
                                              : null,
                                      child:
                                          participante.fotoPerfilUrl == null
                                              ? Text(
                                                participante.nombreMostrar[0]
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              )
                                              : null,
                                    ),
                                    // Indicador de "tú"
                                    if (esTu)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        participante.nombreMostrar,
                                        style: TextStyle(
                                          fontWeight:
                                              esTu
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (esTu)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'Tú',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _formatFechaSolicitud(
                                    participante.fechaSolicitud,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      esTu ? Colors.teal : Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),

              // Botón de salir
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Salir de la sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFechaSolicitud(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else {
      return 'Hace ${diferencia.inDays} días';
    }
  }

  // ========================================
  // BOTÓN Y PANEL DE PARTICIPANTES
  // ========================================

  void _mostrarPanelParticipantes() {
    setState(() => _panelParticipantesVisible = true);
    // Timer para refrescar staleness mientras el panel está abierto
    _timerRefreshPanel?.cancel();
    _timerRefreshPanel = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _panelParticipantesVisible) setState(() {});
    });
  }

  void _cerrarPanelParticipantes() {
    _timerRefreshPanel?.cancel();
    _timerRefreshPanel = null;
    setState(() => _panelParticipantesVisible = false);
  }

  /// Calcula el estado de conexión local de un participante.
  ///
  /// La prioridad de evaluación es:
  ///   1. Pausado: el usuario decidió pausar explícitamente.
  ///   2. Sin conexión (BD): el flag fue escrito por el propio dispositivo del
  ///      participante antes de perder red.
  ///   3. Staleness local: evaluado con los timestamps recibidos por ESTE
  ///      dispositivo. Solo válido cuando nuestra propia conexión está activa;
  ///      si _conexionPerdida == true el stream también está congelado y los
  ///      timestamps serían stale aunque los otros sigan activos.
  ///
  /// Umbrales:
  ///   < 60 s   → activo
  ///   60–180 s → sinActualizacion  (retraso normal en ciudad/túnel)
  ///   > 180 s  → sinConexion
  _EstadoConexion _estadoConexionLocal(ParticipanteSesionModel p) {
    if (!p.trackingActivo) return _EstadoConexion.pausado;
    if (p.conexionPerdida) return _EstadoConexion.sinConexion;
    if (_conexionPerdida) return _EstadoConexion.activo;

    final ultima = _ultimaUbicacionPorUsuario[p.usuarioId];
    if (ultima == null)
      return _EstadoConexion.activo; // nunca recibida → no asumir problema

    final elapsed = DateTime.now().difference(ultima).inSeconds;
    if (elapsed < 60) return _EstadoConexion.activo;
    if (elapsed < 180) return _EstadoConexion.sinActualizacion;
    return _EstadoConexion.sinConexion;
  }

  Widget _buildPanelParticipantesOverlay() {
    if (!_panelParticipantesVisible) return const SizedBox.shrink();

    final participantesAprobados =
        _participantes.where((p) => p.estaAprobado).toList();

    return GestureDetector(
      onTap: _cerrarPanelParticipantes,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            // Absorber taps para no propagar al barrier de cierre
            onTap: () {},
            onVerticalDragEnd: (details) {
              // Swipe hacia abajo → cerrar panel
              if (details.velocity.pixelsPerSecond.dy > 200) {
                _cerrarPanelParticipantes();
              }
            },
            child: Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle de drag
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Encabezado
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Participantes (${participantesAprobados.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _cerrarPanelParticipantes,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Lista — vive en el árbol principal → se reconstruye con setState
                  Expanded(
                    child:
                        participantesAprobados.isEmpty
                            ? const Center(
                              child: Text('No hay participantes aprobados'),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: participantesAprobados.length,
                              itemBuilder:
                                  (_, index) => _buildParticipanteItem(
                                    participantesAprobados[index],
                                  ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _irAParticipante(ParticipanteSesionModel participante) {
    final ubicacion =
        _ubicacionesCache
            .where((u) => u.usuarioId == participante.usuarioId)
            .firstOrNull;

    if (ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sin ubicación disponible para ${participante.nombreMostrar}',
          ),
        ),
      );
      return;
    }

    _cerrarPanelParticipantes();
    setState(() => _isCameraFollowing = false);
    _centrarMapa(ubicacion.posicion);
  }

  Widget _buildParticipanteItem(ParticipanteSesionModel participante) {
    final esMiUsuario = participante.usuarioId == _miUsuarioId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _irAParticipante(participante),
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          backgroundImage:
              participante.fotoPerfilUrl != null
                  ? NetworkImage(participante.fotoPerfilUrl!)
                  : null,
          child:
              participante.fotoPerfilUrl == null
                  ? Text(
                    participante.nombreMostrar[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: _MarqueeText(
                text: participante.nombreMostrar,
                style: TextStyle(
                  fontWeight: esMiUsuario ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (esMiUsuario) ...[
              const SizedBox(width: 4),
              const Text(
                '(Tú)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
        subtitle: Builder(
          builder: (_) {
            switch (_estadoConexionLocal(participante)) {
              case _EstadoConexion.sinConexion:
                return const Row(
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Sin conexión',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              case _EstadoConexion.sinActualizacion:
                return const Row(
                  children: [
                    Icon(Icons.wifi_find, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Sin actualización',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              case _EstadoConexion.pausado:
                return const Row(
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 14,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pausado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              case _EstadoConexion.activo:
                return const Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Activo',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                );
            }
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (participante.usuarioId == widget.sesion.iniciadaPor)
              const Chip(
                label: Text(
                  'Líder',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
            if (esMiUsuario)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _onMiMenuParticipanteSelected(value),
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'pausar_ubicacion',
                        child: Row(
                          children: [
                            Icon(
                              _trackingPausadoPorUsuario
                                  ? Icons.play_arrow
                                  : Icons.pause_circle_outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _trackingPausadoPorUsuario
                                  ? 'Reanudar ubicación'
                                  : 'Pausar ubicación',
                            ),
                          ],
                        ),
                      ),
                      if (_navigationSteps != null)
                        const PopupMenuItem(
                          value: 'finalizar_viaje',
                          child: Row(
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text('Finalizar viaje'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'sos',
                        child: Row(
                          children: [
                            Icon(Icons.sos, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Emergencia',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_esLider && !_esAdminGrupo)
                        const PopupMenuItem(
                          value: 'salir_sesion',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Salir de la sesión',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      if (_esLider || _esAdminGrupo)
                        const PopupMenuItem(
                          value: 'finalizar',
                          child: Row(
                            children: [
                              Icon(Icons.stop, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Finalizar sesión',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
              ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // BANNER DE ESTADO DE CONEXIÓN
  // ========================================

  Widget _buildBannerConexion() {
    final bool perdida = _conexionPerdida;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: perdida ? Colors.orange[700] : Colors.green[600],
          child: Row(
            children: [
              Icon(
                perdida ? Icons.wifi_off : Icons.wifi,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  perdida
                      ? 'Conexión perdida. Tu ubicación no se está compartiendo.'
                      : 'Conexión a internet restablecida, compartiendo ubicación.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              if (!perdida)
                GestureDetector(
                  onTap: () {
                    _timerMensajeRestablecida?.cancel();
                    setState(() => _mostrarMensajeRestablecida = false);
                  },
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // TARJETA DE INSTRUCCIONES DE NAVEGACIÓN
  // ========================================

  Widget _buildTarjetaNavegacion() {
    if (_navigationSteps == null || _currentStepIndex == null) {
      return const SizedBox.shrink();
    }

    final currentStep = _navigationSteps![_currentStepIndex!];
    final hasNextStep = _currentStepIndex! + 1 < _navigationSteps!.length;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tarjeta superior: instrucción + distancia al giro ──────────
          Card(
            color: Colors.teal[700],
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instrucción actual + icono
                  Row(
                    children: [
                      Icon(
                        currentStep.maneuverIcon,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentStep.displayInstruction,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Phase 4b: Distancia al giro en tiempo real
                  if (_distanceToNextStepMeters != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 44),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'en ${_formatDistancia(_distanceToNextStepMeters!)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Siguiente paso
                  if (hasNextStep) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _navigationSteps![_currentStepIndex! + 1]
                              .maneuverIcon,
                          size: 20,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Luego ${_navigationSteps![_currentStepIndex! + 1].displayInstruction}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Botón "Ya llegué" (manual) ─────────────────────────────────
          // Aparece cuando el GPS detecta que estás a ≤ 150 m del destino
          // (igual que en Rutas). Útil cuando el GPS pierde precisión cerca
          // de edificios o estacionamientos.
          if (_distanceToDestinationMeters != null &&
              _distanceToDestinationMeters! <= 150) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _voiceService.announceArrival();
                  _detenerNavegacionPorVoz();
                  _mostrarMensajeLlegada();
                },
                icon: const Icon(Icons.flag_rounded, size: 20),
                label: const Text(
                  'Ya llegué',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Panel inferior siempre visible: participantes | info de ruta | centrar cámara
  Widget _buildNavInfoBottomBar() {
    if (!(_estaAprobado || _esLider)) return const SizedBox.shrink();

    final tieneRuta = _navigationSteps != null && _currentStepIndex != null;
    final participantesAprobados =
        _participantes.where((p) => p.estaAprobado).length;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle — swipe hacia arriba abre el panel de participantes
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dy < -200) {
                  setState(() => _panelParticipantesVisible = true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                // Botón participantes (izquierda)
                GestureDetector(
                  onTap: _mostrarPanelParticipantes,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.teal, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: Colors.teal,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$participantesAprobados',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Info de ruta (centro, expandido)
                Expanded(
                  child:
                      tieneRuta
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _formatDuracion(_remainingDurationSeconds),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF93),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDistancia(_remainingDistanceMeters)}  •  ${_formatEta(_remainingDurationSeconds)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          )
                          : Text(
                            widget.sesion.nombreSesion,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                ),

                const SizedBox(width: 16),

                // Botón centrar cámara (derecha)
                GestureDetector(
                  onTap: () {
                    if (_miPosicion != null) {
                      _isProgrammaticMove = true;
                      setState(() => _isCameraFollowing = true);
                      final bool conRuta = _navigationSteps != null;
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _miPosicion!,
                            zoom: conRuta ? 17.0 : 16.0,
                            bearing: conRuta ? _miHeading : 0.0,
                            tilt: conRuta ? 45.0 : 0.0,
                          ),
                        ),
                      );
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) _isProgrammaticMove = false;
                      });
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          _isCameraFollowing
                              ? Colors.teal[700]
                              : Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCameraFollowing ? Icons.navigation : Icons.my_location,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // MÉTODOS DE RUTA COMPARTIDA
  // ========================================

  Future<void> _calcularPolylineHaciaDestino(
    double destinoLat,
    double destinoLng,
  ) async {
    try {
      debugPrint('🗺️ Iniciando cálculo de polyline hacia destino');

      // Obtener ubicación actual
      debugPrint('📍 Obteniendo ubicación actual...');
      final position = await _trackingService.obtenerUbicacionActual();
      final origen = LatLng(position.latitude, position.longitude);
      final destino = LatLng(destinoLat, destinoLng);

      debugPrint('   Origen: (${position.latitude}, ${position.longitude})');
      debugPrint('   Destino: ($destinoLat, $destinoLng)');

      // Calcular ruta usando GoogleDirectionsService
      debugPrint('🔍 Consultando Google Directions API...');
      final directions = await _directionsService.getDirections(
        origin: origen,
        destination: destino,
      );

      if (directions.routes.isNotEmpty) {
        final route = directions.routes.first;
        debugPrint(
          '✅ Ruta encontrada con ${route.polylineEncoded.length} caracteres de polyline',
        );

        // Decodificar polyline
        final polylinePoints = _directionsService.decodePolyline(
          route.polylineEncoded,
        );
        debugPrint('   ${polylinePoints.length} puntos decodificados');

        // Extraer steps de navegación para instrucciones de voz
        final steps = <NavigationStep>[];
        if (route.legs.isNotEmpty) {
          final leg = route.legs.first;
          debugPrint('   ${leg.steps.length} pasos de navegación encontrados');

          for (final directionStep in leg.steps) {
            final stepPolylinePoints = _directionsService.decodePolyline(
              directionStep.polylineEncoded,
            );
            final navStep = directionStep.toNavigationStep(stepPolylinePoints);
            steps.add(navStep);
          }

          debugPrint('✅ ${steps.length} pasos de navegación procesados');
        }

        // Guardar polyline de alta precisión (concatenación de step polylines)
        // para snapToPolyline. La overview polyline (polylinePoints) tiene
        // muy pocos puntos y causa errores de hasta 100 m en el snap.
        final completeFromSteps = <LatLng>[];
        for (final s in steps) {
          if (completeFromSteps.isNotEmpty && s.polylinePoints.isNotEmpty) {
            completeFromSteps.addAll(s.polylinePoints.skip(1));
          } else {
            completeFromSteps.addAll(s.polylinePoints);
          }
        }
        _completePolylinePoints = List.unmodifiable(
          completeFromSteps.isNotEmpty ? completeFromSteps : polylinePoints,
        );

        // Crear polyline (se actualizará dinámicamente durante navegación)
        final polyline = Polyline(
          polylineId: const PolylineId('ruta_compartida'),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        );

        // Agregar marcador de destino (draggable para ajuste fino de posición)
        final destinoMarker = Marker(
          markerId: const MarkerId('destino_compartido'),
          position: destino,
          draggable: true,
          onDragEnd: (nuevoPunto) {
            setState(() => _destinoAjustado = nuevoPunto);
            _calcularPolylineHaciaDestinoConRetry(
              nuevoPunto.latitude,
              nuevoPunto.longitude,
            );
          },
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: _rutaCompartida?['destino_nombre'] as String? ?? 'Destino',
            snippet: 'Toca para navegar',
          ),
          onTap: _iniciarNavegacionHaciaDestino,
        );

        // Calcular métricas iniciales de la ruta
        double totalDist = 0;
        int totalDur = 0;
        for (final s in steps) {
          totalDist += s.distanceMeters;
          totalDur += s.durationSeconds;
        }

        setState(() {
          _polylineCompartida = polyline;
          _markers['destino_compartido'] = destinoMarker;
          _navigationSteps = steps; // Guardar steps para navegación por voz
          _currentStepIndex = null; // Resetear índice
          _remainingDistanceMeters = totalDist;
          _remainingDurationSeconds = totalDur;
          _distanceToNextStepMeters = null;
          _offRouteSince = null;
          _isRecalculating = false;
        });

        // Inicializar navegación por voz si hay pasos
        if (steps.isNotEmpty && _estaAprobado) {
          // Cancelar suscripción anterior antes de crear una nueva
          _navigationLocationSubscription?.cancel();
          _iniciarNavegacionPorVoz();
        }

        debugPrint('✅ Polyline, marcador y navegación por voz configurados');
      } else {
        _isRecalculating = false;
        debugPrint('⚠️ Google Directions no encontró rutas');
      }
    } catch (e, stackTrace) {
      _isRecalculating = false;
      debugPrint('❌ Error al calcular polyline: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Re-lanzar para que el retry lo capture
    }
  }

  /// Wrapper con retry automático para calcular polyline
  ///
  /// Reintenta hasta 3 veces con exponential backoff si falla
  Future<void> _calcularPolylineHaciaDestinoConRetry(
    double destinoLat,
    double destinoLng, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
  }) async {
    int intento = 0;

    while (intento < maxRetries) {
      try {
        intento++;
        debugPrint('🔄 Intento $intento/$maxRetries de calcular polyline');

        await _calcularPolylineHaciaDestino(destinoLat, destinoLng);
        debugPrint('✅ Polyline calculada exitosamente');
        return; // Éxito, salir
      } catch (e) {
        debugPrint('❌ Error en intento $intento: $e');

        if (intento >= maxRetries) {
          // Falló después de todos los intentos
          debugPrint('🚫 Máximo de reintentos alcanzado ($maxRetries)');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('No se pudo calcular ruta al destino'),
                action: SnackBarAction(
                  label: 'Reintentar',
                  onPressed:
                      () => _calcularPolylineHaciaDestinoConRetry(
                        destinoLat,
                        destinoLng,
                      ),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return; // Salir después de mostrar error
        }

        // Exponential backoff: 2s, 4s, 8s
        final delay =
            baseDelay * (1 << (intento - 1)); // Bitshift para potencia de 2
        debugPrint(
          '⏳ Esperando ${delay.inSeconds}s antes del siguiente intento',
        );
        await Future.delayed(delay);
      }
    }
  }

  void _mostrarIniciarRuta() async {
    // Validar permisos
    if (!_esLider) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo el líder puede compartir rutas.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _IniciarRutaDialog(),
    );

    if (resultado != null && mounted) {
      try {
        await _grupoRepository.compartirRuta(
          sesionId: widget.sesion.id,
          destinoLat: resultado['lat'] as double,
          destinoLng: resultado['lng'] as double,
          destinoNombre: resultado['nombre'] as String?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ruta compartida: ${resultado['nombre'] ?? 'Destino'}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al compartir ruta: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _confirmarCancelarRuta() {
    // Validar permisos
    if (!_esLider) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo el líder puede cancelar rutas.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _showRouteOptionsDialog();
  }

  void _showRouteOptionsDialog() {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: const Text(
              'Opciones de ruta',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RouteOptionTile(
                  icon: Icons.cancel_outlined,
                  iconColor: Colors.redAccent,
                  title: 'Cancelar ruta',
                  subtitle: 'Eliminar el destino para todos los participantes',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _cancelarRuta();
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.12), height: 1),
                _RouteOptionTile(
                  icon: Icons.play_circle_outline,
                  iconColor: const Color(0xFF4CAF93),
                  title: 'Continuar ruta',
                  subtitle: 'Cerrar este menú y seguir navegando',
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
    );
  }

  void _mostrarDialogSesionFinalizada() {
    // Determinar mensaje según rol
    String mensaje;
    if (_esLider) {
      // El usuario es el líder de la sesión (quien la inició)
      mensaje = 'Has finalizado "${widget.sesion.nombreSesion}".';
    } else if (_esAdminGrupo) {
      // El usuario es admin del grupo y finalizó la sesión de otro
      mensaje =
          'Has finalizado la sesión "${widget.sesion.nombreSesion}" como líder del grupo.';
    } else {
      // El usuario es participante normal
      mensaje =
          'El líder del grupo ha finalizado "${widget.sesion.nombreSesion}".';
    }

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Sesión Finalizada')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensaje, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text(
                  'El tracking de ubicación ha sido detenido.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cerrar dialog
                  Navigator.pop(
                    context,
                  ); // Volver a pantalla anterior (detalle o lista)
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Entendido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelarRuta() async {
    try {
      debugPrint('🗑️ Iniciando cancelación de ruta...');

      // PASO 0: Detener navegación por voz si estaba activa
      if (_navigationSteps != null) {
        _detenerNavegacionPorVoz();
      }

      // PASO 1: Limpiar UI INMEDIATAMENTE (no esperar stream)
      if (mounted) {
        setState(() {
          _rutaCompartida = null;
          _polylineCompartida = null;
          _markers.remove('destino_compartido');
        });
        debugPrint('✅ UI limpiada localmente');
      }

      // PASO 2: Eliminar de base de datos (notifica a otros vía stream)
      await _grupoRepository.eliminarRutaCompartida(widget.sesion.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ruta cancelada para todos los participantes'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error cancelando ruta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar ruta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Inicia la navegación por voz
  ///
  /// - Inicializa el servicio TTS
  /// - Anuncia la primera instrucción
  /// - Inicia el tracking de ubicación para detectar cambios de paso
  Future<void> _iniciarNavegacionPorVoz() async {
    if (_navigationSteps == null || _navigationSteps!.isEmpty) {
      debugPrint('⚠️ No hay pasos de navegación, no se puede iniciar voz');
      return;
    }

    try {
      debugPrint('🔊 Inicializando navegación por voz...');

      // 1. Inicializar servicio de voz
      await _voiceService.initialize();

      // 2. Anunciar primera instrucción
      if (_navigationSteps!.isNotEmpty) {
        final firstStep = _navigationSteps!.first;
        setState(() {
          _currentStepIndex = 0;
        });

        _voiceProximity200Fired = false;
        _voiceProximity50Fired = false;
        await _voiceService.announceInstruction(
          firstStep.instruction,
          firstStep.distanceText,
        );

        debugPrint('✅ Primera instrucción anunciada: ${firstStep.instruction}');
      }

      // 3. Iniciar tracking de ubicación para detectar cambios de paso
      _navigationLocationSubscription = _trackingService.ubicacionStream.listen(
        (position) => _onNavigationLocationUpdate(position),
      );

      debugPrint('✅ Navegación por voz iniciada');
    } catch (e) {
      debugPrint('❌ Error al iniciar navegación por voz: $e');
    }
  }

  /// Callback cuando se actualiza la ubicación durante navegación
  ///
  /// Usa el mismo algoritmo que NavigationBloc:
  /// - determineCurrentStep() con lookahead de 5 pasos (evita lag en moto)
  /// - Snap to road via Roads API
  /// - Cámara bearing-up con zoom dinámico
  /// - Recorte visual de polyline restante
  /// - Auto-recalculación al salir de ruta
  /// - Alertas de proximidad y anuncios de voz
  Future<void> _onNavigationLocationUpdate(Position position) async {
    if (_navigationSteps == null ||
        _navigationSteps!.isEmpty ||
        _currentStepIndex == null ||
        !mounted) {
      return;
    }

    final rawLocation = LatLng(position.latitude, position.longitude);
    final speedKmh = (position.speed < 0 ? 0 : position.speed) * 3.6;
    final heading = position.heading < 0 ? 0.0 : position.heading;

    // Snap local a la polyline cuando hay ruta activa — sin coste de API.
    final LatLng navLocation =
        (_navigationSteps != null && _completePolylinePoints.length >= 2)
            ? _navTrackingService.snapToPolyline(
              rawLocation,
              _completePolylinePoints,
            )
            : rawLocation;
    // ── Cámara orientada (solo cuando hay ruta activa) ───────────────────
    _actualizarCamaraNavegacion(navLocation, speedKmh, heading);

    // ── Determinar paso actual con lookahead de 5 pasos ──────────────────
    // Igual al algoritmo de NavigationBloc — evita lag a velocidad de moto
    final newStepIndex = _navTrackingService.determineCurrentStep(
      currentLocation: navLocation,
      steps: _navigationSteps!,
      lastStepIndex: _currentStepIndex!,
    );

    // Si avanzó de paso, anunciar la instrucción del nuevo paso
    if (newStepIndex > _currentStepIndex!) {
      if (newStepIndex >= _navigationSteps!.length) {
        // Llegada al destino
        _voiceService.announceArrival();
        _detenerNavegacionPorVoz();
        _mostrarMensajeLlegada();
        debugPrint('🎯 Llegada al destino');
        return;
      }
      if (mounted) setState(() => _currentStepIndex = newStepIndex);
      final newStep = _navigationSteps![newStepIndex];
      _voiceProximity200Fired = false;
      _voiceProximity50Fired = false;
      _voiceService.announceInstruction(
        newStep.instruction,
        newStep.distanceText,
      );
      debugPrint('➡️ Avanzando a paso $newStepIndex: ${newStep.instruction}');
    }

    final currentStep = _navigationSteps![_currentStepIndex!];

    // ── Distancia real al giro ────────────────────────────────────────────
    final distanceToStepEnd = _navTrackingService.calculateDistanceToStepEnd(
      currentLocation: navLocation,
      currentStep: currentStep,
    );

    // ── Progreso total restante ───────────────────────────────────────────
    final remaining = _navTrackingService.calculateRemainingDistance(
      currentLocation: navLocation,
      steps: _navigationSteps!,
      currentStepIndex: _currentStepIndex!,
    );
    final remainingDur = _navTrackingService.calculateRemainingDuration(
      steps: _navigationSteps!,
      currentStepIndex: _currentStepIndex!,
    );

    // ── Polyline restante ─────────────────────────────────────────────────
    final remainingPolyline = _calcularPolylineRestante(navLocation);

    // ── Detección de salida de ruta ───────────────────────────────────────
    // Usar rawLocation (posición GPS real) para detectar desvío.
    // navLocation ya fue ajustada a la polyline mediante snap, por lo que
    // siempre está "en ruta" y nunca dispararía el recálculo.
    if (!_isRecalculating) {
      final offRoute = _navTrackingService.isOffRoute(
        currentLocation: rawLocation,
        currentStep: currentStep,
      );

      if (offRoute) {
        _offRouteSince ??= DateTime.now();
        final offSeconds = DateTime.now().difference(_offRouteSince!).inSeconds;
        if (offSeconds >= _offRouteTriggerSeconds && _rutaCompartida != null) {
          _offRouteSince = null;
          _isRecalculating = true;
          _voiceProximity200Fired = false;
          _voiceProximity50Fired = false;
          _voiceService.announceRecalculating();
          final lat = _rutaCompartida!['destino_lat'] as double;
          final lng = _rutaCompartida!['destino_lng'] as double;
          _calcularPolylineHaciaDestinoConRetry(lat, lng);
          return;
        }
      } else {
        _offRouteSince = null;
      }
    }

    // ── setState con todas las actualizaciones ────────────────────────────
    if (mounted) {
      setState(() {
        _distanceToNextStepMeters = distanceToStepEnd;
        _remainingDistanceMeters = remaining;
        _remainingDurationSeconds = remainingDur;
        if (remainingPolyline.isNotEmpty) {
          _polylineCompartida = Polyline(
            polylineId: const PolylineId('ruta_compartida'),
            points: remainingPolyline,
            color: Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          );
        }
      });
    }

    // ── Llegada inteligente al destino (último paso) ──────────────────────
    // Idéntico al criterio de NavigationBloc (Rutas):
    //   Nivel 1: < 50 m (GPS preciso, cualquier velocidad)
    //   Nivel 2: < 80 m + velocidad < 20 km/h (edificios, estacionamientos)
    final isLastStep = _currentStepIndex! == _navigationSteps!.length - 1;
    if (isLastStep && _rutaCompartida != null) {
      final destLat = _rutaCompartida!['destino_lat'] as double;
      final destLng = _rutaCompartida!['destino_lng'] as double;
      final distToDestination = Geolocator.distanceBetween(
        navLocation.latitude,
        navLocation.longitude,
        destLat,
        destLng,
      );

      final autoArrived =
          distToDestination < 50.0 ||
          (distToDestination < 80.0 && speedKmh < 20.0);

      if (autoArrived) {
        await _voiceService.announceArrival();
        _detenerNavegacionPorVoz();
        _mostrarMensajeLlegada();
        debugPrint(
          '🎯 Llegada inteligente al destino (${distToDestination.toStringAsFixed(0)}m)',
        );
        return;
      }

      // Exponer distancia para botón "Ya llegué" manual (≤ 150 m)
      if (mounted) {
        setState(() => _distanceToDestinationMeters = distToDestination);
      }
    } else if (_distanceToDestinationMeters != null && mounted) {
      setState(() => _distanceToDestinationMeters = null);
    }

    // ── Alertas de proximidad al siguiente giro ───────────────────────────
    // Cada umbral dispara de forma independiente (igual que NavigationBloc):
    // si el usuario pasa directo de 300 m a 40 m, ambas alertas deben sonar.
    if (!_voiceProximity200Fired && distanceToStepEnd <= 200) {
      _voiceProximity200Fired = true;
      _voiceService.announceProximityAlert(currentStep.instruction, 200);
    }
    if (!_voiceProximity50Fired && distanceToStepEnd <= 50) {
      _voiceProximity50Fired = true;
      _voiceService.announceProximityAlert(currentStep.instruction, 50);
    }
  }

  /// Calcula la polyline restante desde la posición actual hasta el destino.
  List<LatLng> _calcularPolylineRestante(LatLng currentLocation) {
    if (_completePolylinePoints.length < 2)
      return _completePolylinePoints.toList();

    double minDist = double.maxFinite;
    int closestIdx = 0;

    for (int i = 0; i < _completePolylinePoints.length; i++) {
      final d = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        _completePolylinePoints[i].latitude,
        _completePolylinePoints[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    return [currentLocation, ..._completePolylinePoints.sublist(closestIdx)];
  }

  /// Actualiza la cámara del mapa con bearing y zoom dinámico (Phase 4a).
  void _actualizarCamaraNavegacion(
    LatLng location,
    double speedKmh,
    double heading,
  ) {
    if (!_isCameraFollowing) return;

    double zoom;
    if (speedKmh < 20) {
      zoom = 18.0;
    } else if (speedKmh < 60) {
      zoom = 17.0;
    } else if (speedKmh < 100) {
      zoom = 16.0;
    } else {
      zoom = 15.5;
    }

    _isProgrammaticMove = true;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: zoom,
          bearing: heading,
          tilt: 45.0,
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _isProgrammaticMove = false;
    });
  }

  /// Formatea distancia en metros/km
  String _formatDistancia(double meters) {
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Formatea duración en minutos/horas
  String _formatDuracion(int seconds) {
    final mins = (seconds / 60).ceil();
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}min';
  }

  /// Calcula la hora estimada de llegada formateada
  String _formatEta(int remainingSeconds) {
    final eta = DateTime.now().add(Duration(seconds: remainingSeconds));
    final hour = eta.hour;
    final minute = eta.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'p.m.' : 'a.m.';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Detiene la navegación por voz y limpia todo el estado de navegación
  void _detenerNavegacionPorVoz() {
    debugPrint('🔇 Deteniendo navegación por voz...');

    _navigationLocationSubscription?.cancel();
    _navigationLocationSubscription = null;
    _offRouteSince = null;
    _isRecalculating = false;

    _voiceService.stop();

    setState(() {
      _navigationSteps = null;
      _currentStepIndex = null;
      _distanceToNextStepMeters = null;
      _distanceToDestinationMeters = null;
      _remainingDistanceMeters = 0;
      _remainingDurationSeconds = 0;
    });

    debugPrint('✅ Navegación por voz detenida');
  }

  /// Muestra SnackBar de llegada al destino
  void _mostrarMensajeLlegada() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Has llegado a tu destino',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  }

  /// Maneja las opciones del menú de 3 puntos en la fila del usuario propio
  void _onMiMenuParticipanteSelected(String value) {
    switch (value) {
      case 'pausar_ubicacion':
        _togglePausarUbicacion();
        break;
      case 'finalizar_viaje':
        _confirmarFinalizarViaje();
        break;
      case 'sos':
        _confirmarEnviarSOS();
        break;
      case 'salir_sesion':
        _salirDeSesion();
        break;
      case 'finalizar':
        _finalizarSesion();
        break;
    }
  }

  /// Pide confirmación y finaliza la navegación del usuario sin salir de la sesión
  Future<void> _confirmarFinalizarViaje() async {
    if (_navigationSteps == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes navegación activa'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Finalizar viaje'),
            content: const Text(
              'Se detendrá tu navegación, pero seguirás en la sesión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Finalizar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      _detenerNavegacionPorVoz();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Has finalizado tu viaje'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Pide confirmación y envía alerta SOS a todos los participantes de la sesión
  Future<void> _confirmarEnviarSOS() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sos, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Enviar SOS', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: const Text(
              '¿Estás seguro? Se notificará a todos los participantes que necesitas apoyo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Enviar SOS',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      await _enviarSOS();
    }
  }

  /// Invoca la Edge Function para enviar notificación SOS a todos los participantes
  Future<void> _enviarSOS() async {
    try {
      await _grupoRepository.enviarSOS(
        sesionId: widget.sesion.id,
        grupoId: widget.grupo.id,
        usuarioId: _miUsuarioId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS enviado a todos los participantes'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al enviar SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre la pantalla de navegación completa hacia el destino compartido.
  ///
  /// Pasa el sesionGrupalId para que el progreso se comparta con el grupo.
  void _iniciarNavegacionHaciaDestino() {
    if (_rutaCompartida == null) return;

    // Si el usuario arrastró el marcador, usar su posición ajustada
    final destino =
        _destinoAjustado ??
        LatLng(
          _rutaCompartida!['destino_lat'] as double,
          _rutaCompartida!['destino_lng'] as double,
        );
    final nombre = _rutaCompartida!['destino_nombre'] as String?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _NavigationScreenWrapper(
              destination: destino,
              destinationName: nombre,
              sesionGrupalId: widget.sesion.id,
            ),
      ),
    );
  }
}

// ========================================
// OPCIÓN DE RUTA (TILE EN DIÁLOGO)
// ========================================

class _RouteOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RouteOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}

// ========================================
// DIÁLOGO INICIAR RUTA
// ========================================

class _IniciarRutaDialog extends StatefulWidget {
  const _IniciarRutaDialog();

  @override
  State<_IniciarRutaDialog> createState() => _IniciarRutaDialogState();
}

class _IniciarRutaDialogState extends State<_IniciarRutaDialog> {
  final _ubicacionController = TextEditingController();
  LatLng? _destinoSeleccionado;
  String? _nombreDestino;

  @override
  void dispose() {
    _ubicacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.route, color: Colors.teal),
          const SizedBox(width: 8),
          const Text('Iniciar Ruta'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Busca y selecciona el destino de la ruta. Se enviará a todos los participantes de la sesión.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            LocationSearchField(
              controller: _ubicacionController,
              labelText: 'Destino',
              hintText: 'Buscar ubicación...',
              onLocationSelected: (address, coordinates) {
                setState(() {
                  _destinoSeleccionado = coordinates;
                  _nombreDestino = address;
                });
                debugPrint('📍 Destino seleccionado: $address');
                debugPrint(
                  '   Coordenadas: ${coordinates.latitude}, ${coordinates.longitude}',
                );
              },
            ),
            if (_destinoSeleccionado != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Destino confirmado',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nombreDestino ?? 'Ubicación seleccionada',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_destinoSeleccionado!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_destinoSeleccionado!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Permite ajustar el punto exacto arrastrando el marcador en el mapa.
              // Útil para corregir el lado de la vía antes de iniciar la ruta.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/map-picker',
                      arguments: {
                        'initialPosition': _destinoSeleccionado,
                        'initialSearchQuery': _nombreDestino,
                      },
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        _destinoSeleccionado = result['latlng'] as LatLng;
                        final newAddress = result['address'] as String?;
                        if (newAddress != null && newAddress.isNotEmpty) {
                          _nombreDestino = newAddress;
                          _ubicacionController.text = newAddress;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.edit_location_alt, color: Colors.teal),
                  label: const Text(
                    'Ajustar en mapa',
                    style: TextStyle(color: Colors.teal),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _destinoSeleccionado != null ? _confirmar : null,
          icon: const Icon(Icons.navigation),
          label: const Text('Iniciar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _confirmar() {
    if (_destinoSeleccionado == null) return;

    Navigator.pop(context, {
      'lat': _destinoSeleccionado!.latitude,
      'lng': _destinoSeleccionado!.longitude,
      'nombre': _nombreDestino,
    });
  }
}

/// Widget de texto con efecto marquee (scroll horizontal) para textos largos
///
/// Si el texto cabe en el ancho disponible, se muestra normal.
/// Si es muy largo, se anima con efecto marquee (scroll horizontal continuo).
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Esperar a que se construya el widget para verificar si necesita scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrollingIfNeeded();
    });
  }

  void _startScrollingIfNeeded() {
    if (!mounted) return;

    // Verificar si el contenido excede el ancho disponible
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _isScrolling = true;
      });
      _animate();
    }
  }

  void _animate() async {
    if (!mounted || !_isScrolling) return;

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted || !_scrollController.hasClients) return;

    // Scroll hacia la derecha
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: widget.text.length * 50),
      curve: Curves.linear,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || !_scrollController.hasClients) return;

    // Volver al inicio
    await _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: widget.text.length * 50),
      curve: Curves.linear,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    // Repetir
    _animate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}

// ========================================
// WRAPPER PARA NAVEGAR A NavigationScreen
// ========================================

/// Wrapper que permite abrir NavigationScreen desde el mapa grupal.
///
/// Se usa cuando un participante toca el marcador de destino y quiere
/// activar la navegación turn-by-turn completa con datos compartidos al grupo.
class _NavigationScreenWrapper extends StatelessWidget {
  final LatLng destination;
  final String? destinationName;
  final String sesionGrupalId;

  const _NavigationScreenWrapper({
    required this.destination,
    required this.destinationName,
    required this.sesionGrupalId,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationScreen(
      destination: destination,
      destinationName: destinationName,
      sesionGrupalId: sesionGrupalId,
    );
  }
}
