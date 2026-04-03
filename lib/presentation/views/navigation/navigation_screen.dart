/// Pantalla de Navegación Turn-by-Turn
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../blocs/navigation/navigation_bloc.dart';
import '../../widgets/navigation/navigation_panel.dart';
import '../../widgets/navigation/navigation_summary_dialog.dart';
import '../../../domain/usecases/navigation/start_navigation_usecase.dart';
import '../../../domain/usecases/navigation/update_navigation_progress_usecase.dart';
import '../../../domain/usecases/navigation/end_navigation_usecase.dart';
import '../../../domain/usecases/navigation/recalculate_route_usecase.dart';
import '../../../data/services/navigation/google_directions_service.dart';
import '../../../data/services/navigation/navigation_tracking_service.dart';
import '../../../data/repositories/navigation_repository.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/navigation_voice_service.dart';
import '../../../core/constants/api_constants.dart';

class NavigationScreen extends StatelessWidget {
  final LatLng destination;
  final String? destinationName;
  final String? sesionGrupalId;

  const NavigationScreen({
    super.key,
    required this.destination,
    this.destinationName,
    this.sesionGrupalId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final directionsService =
            GoogleDirectionsService(apiKey: ApiConstants.googleMapsApiKey);
        final trackingService = NavigationTrackingService();
        final navigationRepository = context.read<NavigationRepository>();
        final locationService = LocationTrackingService();

        final startNavigationUseCase = StartNavigationUseCase(
          directionsService: directionsService,
          navigationRepository: navigationRepository,
          locationService: locationService,
        );
        final updateProgressUseCase = UpdateNavigationProgressUseCase(
          trackingService: trackingService,
          navigationRepository: navigationRepository,
        );
        final endNavigationUseCase = EndNavigationUseCase(
          repository: navigationRepository,
          locationService: locationService,
        );
        final recalculateRouteUseCase = RecalculateRouteUseCase(
          directionsService: directionsService,
          locationService: locationService,
        );
        final voiceService = NavigationVoiceService();

        final bloc = NavigationBloc(
          startNavigationUseCase: startNavigationUseCase,
          updateProgressUseCase: updateProgressUseCase,
          endNavigationUseCase: endNavigationUseCase,
          recalculateRouteUseCase: recalculateRouteUseCase,
          locationService: locationService,
          voiceService: voiceService,
          trackingService: trackingService,
          routesRepository: context.read<RoutesRepository>(),
        );

        bloc.add(NavigationStartRequested(
          destination: destination,
          destinationName: destinationName,
          sesionGrupalId: sesionGrupalId,
        ));

        return bloc;
      },
      child: _NavigationView(
        destination: destination,
        destinationName: destinationName,
      ),
    );
  }
}

class _NavigationView extends StatefulWidget {
  final LatLng destination;
  final String? destinationName;

  const _NavigationView({
    required this.destination,
    this.destinationName,
  });

  @override
  State<_NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<_NavigationView> {
  GoogleMapController? _mapController;
  bool _isCameraFollowing = true;

  /// Evita que `onCameraMoveStarted` desactive el seguimiento
  /// cuando la animación es programática (no un gesto del usuario).
  bool _isProgrammaticMove = false;

  BitmapDescriptor? _arrowIcon;

  @override
  void initState() {
    super.initState();
    _createArrowIcon();
  }

  /// Dibuja una flecha de navegación en canvas y la convierte a BitmapDescriptor.
  Future<void> _createArrowIcon() async {
    const double size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final path = Path()
      ..moveTo(size / 2, 2) // punta superior
      ..lineTo(size - 4, size - 4) // esquina inferior derecha
      ..lineTo(size / 2, size * 0.62) // muesca inferior central
      ..lineTo(4, size - 4) // esquina inferior izquierda
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

  Future<void> _centerOnCurrentLocation() async {
    if (_mapController == null) return;
    final state = context.read<NavigationBloc>().state;
    if (state.lastKnownLocation != null) {
      _isProgrammaticMove = true;
      setState(() => _isCameraFollowing = true);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: state.lastKnownLocation!,
          zoom: _zoomForSpeed(state.currentSpeedKmh),
          bearing: state.currentHeading,
          tilt: 45.0,
        )),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _isProgrammaticMove = false;
      });
    }
  }

  /// Zoom dinámico basado en velocidad (Phase 4)
  double _zoomForSpeed(double speedKmh) {
    if (speedKmh < 20) return 18.0; // Zona urbana / detenido
    if (speedKmh < 60) return 17.0; // Velocidad moderada
    if (speedKmh < 100) return 16.0; // Carretera
    return 15.5; // Autopista
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<NavigationBloc, NavigationState>(
        listener: (context, state) {
          // ── Camera follow with heading ────────────────────────────────
          if (_isCameraFollowing &&
              state.isNavigating &&
              state.lastKnownLocation != null &&
              _mapController != null) {
            _isProgrammaticMove = true;
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(CameraPosition(
                target: state.lastKnownLocation!,
                zoom: _zoomForSpeed(state.currentSpeedKmh),
                bearing: state.currentHeading,
                tilt: 45.0,
              )),
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _isProgrammaticMove = false;
            });
          }

          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
            context.read<NavigationBloc>().add(const NavigationErrorCleared());
          }

          if (state.isCancelled) {
            Navigator.pop(context);
          }

          if (state.routeSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ruta guardada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          if (state.isCalculating && state.currentSession == null) {
            return _buildLoadingScreen();
          }

          if (state.errorMessage != null && state.currentSession == null) {
            return _buildErrorScreen(state.errorMessage!);
          }

          if (state.isCompleted) {
            return _buildCompletedScreen(state);
          }

          return Stack(
            children: [
              _NavigationMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onCameraMoveStarted: () {
                  // Solo desactivar seguimiento si el movimiento es del usuario,
                  // no de una animación programática.
                  if (!_isProgrammaticMove && _isCameraFollowing) {
                    setState(() => _isCameraFollowing = false);
                  }
                },
                arrowIcon: _arrowIcon,
              ),
              NavigationPanel(
                onCenterLocation: _centerOnCurrentLocation,
                isCameraFollowing: _isCameraFollowing,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Calculando ruta...',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al iniciar navegación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedScreen(NavigationState state) {
    return Stack(
      children: [
        _NavigationMap(
          onMapCreated: (controller) => _mapController = controller,
          arrowIcon: _arrowIcon,
        ),
        Container(color: Colors.black.withOpacity(0.3)),
        Align(
          alignment: Alignment.bottomCenter,
          child: NavigationSummaryBottomSheet(
            session: state.currentSession!,
            realizedDistanceMeters: state.realizedDistanceMeters,
            onClose: () => Navigator.pop(context),
            onSave: () async {
              final result = await _showSaveRouteDialog(context);
              if (result != null && mounted) {
                context.read<NavigationBloc>().add(NavigationSaveRouteRequested(
                  routeName: result['nombre']!,
                  routeDescription: result['descripcion'],
                ));
              }
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>?> _showSaveRouteDialog(BuildContext context) async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Guardar Ruta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre*',
                  hintText: 'Dale un nombre a tu ruta',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Añade detalles si quieres...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () {
                final nombre = nombreController.text.trim();
                final descripcion = descripcionController.text.trim();
                if (nombre.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'nombre': nombre,
                    'descripcion': descripcion,
                  });
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre no puede estar vacío.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// ========================================
// WIDGET INTERNO DEL MAPA
// ========================================

class _NavigationMap extends StatelessWidget {
  final void Function(GoogleMapController)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final BitmapDescriptor? arrowIcon;

  const _NavigationMap({this.onMapCreated, this.onCameraMoveStarted, this.arrowIcon});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
        if (state.currentSession == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = state.currentSession!;

        // Phase 1: Use remaining polyline if available, fallback to complete
        final routePoints = state.remainingPolyline.isNotEmpty
            ? state.remainingPolyline
            : session.completePolyline;

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: session.origin,
            zoom: 16,
          ),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: onMapCreated,
          onCameraMoveStarted: onCameraMoveStarted,
          markers: {
            Marker(
              markerId: const MarkerId('destination'),
              position: session.destination,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: session.destinationName ?? 'Destino',
              ),
            ),
            if (state.lastKnownLocation != null)
              Marker(
                markerId: const MarkerId('user_location'),
                position: state.lastKnownLocation!,
                rotation: state.currentHeading,
                flat: true,
                anchor: const Offset(0.5, 0.5),
                icon: arrowIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                zIndex: 10,
              ),
          },
          polylines: {
            // Ruta restante (se va consumiendo con el avance)
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: Colors.blue,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          },
        );
      },
    );
  }
}
