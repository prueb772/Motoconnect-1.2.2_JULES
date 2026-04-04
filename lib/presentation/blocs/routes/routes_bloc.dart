import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter/material.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/models/ruta_realizada_model.dart';
import '../../../data/models/geo_point.dart';

part 'routes_event.dart';
part 'routes_state.dart';

/// RoutesBloc - Gestiona el estado de la pantalla de Rutas
///
/// Este BLoC reemplaza a RoutesViewModel.
/// Es responsable de:
/// - Gestionar el estado del mapa de Google Maps
/// - Manejar la búsqueda de lugares con Google Place
/// - Calcular y mostrar rutas entre ubicaciones
/// - Gestionar la ubicación del usuario en tiempo real
/// - Guardar rutas realizadas
/// - Cargar y mostrar rutas guardadas
/// - Gestionar el seguimiento de ruta
class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  RoutesBloc({
    required this.googleApiKey,
    required RoutesRepository routesRepository,
  })  : _routesRepository = routesRepository,
        super(const RoutesState()) {
    _googlePlace = GooglePlace(googleApiKey);

    on<RoutesInitialized>(_onInitialized);
    on<RoutesMapCreated>(_onMapCreated);
    on<RoutesUserLocationRequested>(_onUserLocationRequested);
    on<RoutesSearchQueryChanged>(_onSearchQueryChanged);
    on<RoutesPredictionSelected>(_onPredictionSelected);
    on<RoutesCalculateRequested>(_onCalculateRequested);
    on<RoutesSearchCleared>(_onSearchCleared);
    on<RoutesTrackingStarted>(_onTrackingStarted);
    on<RoutesTrackingStopped>(_onTrackingStopped);
    on<RoutesSaveRequested>(_onSaveRequested);
    on<RoutesSavedRouteLoadRequested>(_onSavedRouteLoadRequested);
    on<RoutesLoadByIdRequested>(_onLoadByIdRequested);
    on<RoutesErrorCleared>(_onErrorCleared);
    on<_RoutesLocationUpdated>(_onLocationUpdated);
    on<RoutesDestinationSet>(_onDestinationSet);
    on<RoutesMarkerDragged>(_onMarkerDragged);
  }

  /// API Key de Google Maps
  final String googleApiKey;

  /// Posición por defecto (Bucaramanga)
  final LatLng defaultPosition = const LatLng(7.116816, -73.105240);

  final RoutesRepository _routesRepository;
  late GooglePlace _googlePlace;

  /// Controlador del mapa (se guarda referencia para animaciones)
  GoogleMapController? _mapController;

  /// Stream subscription para seguimiento de ubicación
  StreamSubscription<Position>? _posicionSubscription;

  /// Inicialización
  Future<void> _onInitialized(
    RoutesInitialized event,
    Emitter<RoutesState> emit,
  ) async {
    add(const RoutesUserLocationRequested());
  }

  /// Callback cuando el mapa es creado
  void _onMapCreated(
    RoutesMapCreated event,
    Emitter<RoutesState> emit,
  ) {
    _mapController = event.controller;
  }

  /// Obtiene la ubicación actual del usuario
  Future<void> _onUserLocationRequested(
    RoutesUserLocationRequested event,
    Emitter<RoutesState> emit,
  ) async {
    emit(state.copyWith(status: RoutesStatus.loadingLocation));

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userMarker = Marker(
        markerId: const MarkerId("user"),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(title: "Tu ubicación"),
      );

      // Animar cámara a la posición del usuario
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16,
          ),
        );
      }

      emit(state.copyWith(
        status: RoutesStatus.locationLoaded,
        currentPosition: position,
        userMarker: userMarker,
        clearError: true,
      ));

      // Si ya hay un destino marcado pero la ruta no fue calculada aún
      if (state.searchedMarker != null && state.polylineCoordinates.isEmpty) {
        add(RoutesCalculateRequested(state.searchedMarker!.position));
      }
    } catch (e) {
      emit(state.copyWith(
        status: RoutesStatus.error,
        errorMessage: 'Error obteniendo ubicación: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onUserLocationRequested: $e');
    }
  }

  /// Realiza autocompletado de búsqueda de lugares
  Future<void> _onSearchQueryChanged(
    RoutesSearchQueryChanged event,
    Emitter<RoutesState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(
        predictions: [],
        clearPredictions: true,
        clearSelectedPlaceName: true,
      ));
      return;
    }

    if (state.currentPosition == null) {
      emit(state.copyWith(
        errorMessage: 'Esperando ubicación del usuario',
        clearSelectedPlaceName: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: RoutesStatus.searchingPlaces,
      clearSelectedPlaceName: true,
    ));

    try {
      var result = await _googlePlace.autocomplete.get(
        event.query,
        location: LatLon(
          state.currentPosition!.latitude,
          state.currentPosition!.longitude,
        ),
        radius: 15000,
      );

      if (result != null && result.predictions != null) {
        emit(state.copyWith(
          status: RoutesStatus.locationLoaded,
          predictions: result.predictions!,
          clearError: true,
          clearSelectedPlaceName: true,
        ));
      } else {
        emit(state.copyWith(
          status: RoutesStatus.locationLoaded,
          predictions: [],
          clearPredictions: true,
          clearSelectedPlaceName: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Error en la búsqueda: ${e.toString()}',
        predictions: [],
        clearPredictions: true,
        clearSelectedPlaceName: true,
      ));
      debugPrint('Error en RoutesBloc._onSearchQueryChanged: $e');
    }
  }

  /// Selecciona una predicción de búsqueda
  Future<void> _onPredictionSelected(
    RoutesPredictionSelected event,
    Emitter<RoutesState> emit,
  ) async {
    if (event.prediction.placeId == null) return;

    try {
      final detail = await _googlePlace.details.get(event.prediction.placeId!);

      if (detail != null &&
          detail.result != null &&
          detail.result!.geometry != null) {
        final location = detail.result!.geometry!.location!;
        final latLng = LatLng(location.lat!, location.lng!);

        final searchedMarker = Marker(
          markerId: MarkerId(event.prediction.placeId!),
          position: latLng,
          draggable: true,
          onDragEnd: (newPosition) => add(RoutesMarkerDragged(newPosition)),
          infoWindow: InfoWindow(title: detail.result!.name),
        );

        emit(state.copyWith(
          searchedMarker: searchedMarker,
          predictions: [],
          clearPredictions: true,
          selectedPlaceName: detail.result!.name,
        ));

        // Animar cámara al lugar seleccionado
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
        }

        // Calcular ruta al destino
        add(RoutesCalculateRequested(latLng));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Error al obtener detalles del lugar: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onPredictionSelected: $e');
    }
  }

  /// Establece un destino directamente (sin búsqueda)
  Future<void> _onDestinationSet(
    RoutesDestinationSet event,
    Emitter<RoutesState> emit,
  ) async {
    final searchedMarker = Marker(
      markerId: MarkerId("destino_${DateTime.now().millisecondsSinceEpoch}"),
      position: event.destination,
      draggable: true,
      onDragEnd: (newPosition) => add(RoutesMarkerDragged(newPosition)),
      infoWindow: InfoWindow(title: event.destinationName ?? 'Destino'),
    );

    emit(state.copyWith(
      searchedMarker: searchedMarker,
      selectedPlaceName: event.destinationName,
    ));

    // Calcular ruta al destino
    add(RoutesCalculateRequested(event.destination));
  }

  /// Calcula la ruta entre la ubicación actual y un destino
  Future<void> _onCalculateRequested(
    RoutesCalculateRequested event,
    Emitter<RoutesState> emit,
  ) async {
    if (state.currentPosition == null) {
      return;
    }

    emit(state.copyWith(status: RoutesStatus.calculatingRoute));

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey,
        PointLatLng(
          state.currentPosition!.latitude,
          state.currentPosition!.longitude,
        ),
        PointLatLng(event.destination.latitude, event.destination.longitude),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        final polylines = <Polyline>{
          Polyline(
            polylineId: const PolylineId("route"),
            color: Colors.blue,
            width: 6,
            points: polylineCoordinates,
          ),
        };

        emit(state.copyWith(
          status: RoutesStatus.routeCalculated,
          polylineCoordinates: polylineCoordinates,
          polylines: polylines,
          clearError: true,
        ));
      } else {
        emit(state.copyWith(
          status: RoutesStatus.error,
          errorMessage: 'No se pudo calcular la ruta',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: RoutesStatus.error,
        errorMessage: 'Error calculando ruta: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onCalculateRequested: $e');
    }
  }

  /// Limpia la búsqueda y la ruta actual
  void _onSearchCleared(
    RoutesSearchCleared event,
    Emitter<RoutesState> emit,
  ) {
    // Detener seguimiento si está activo
    _posicionSubscription?.cancel();
    _posicionSubscription = null;

    emit(state.copyWith(
      status: RoutesStatus.locationLoaded,
      predictions: [],
      clearPredictions: true,
      clearSearchedMarker: true,
      polylineCoordinates: [],
      polylines: {},
      siguiendoRuta: false,
      clearSelectedPlaceName: true,
    ));
  }

  /// Inicia el seguimiento de la ruta en tiempo real
  void _onTrackingStarted(
    RoutesTrackingStarted event,
    Emitter<RoutesState> emit,
  ) {
    if (state.siguiendoRuta) return;

    emit(state.copyWith(siguiendoRuta: true));

    _posicionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      add(_RoutesLocationUpdated(position));
    });
  }

  /// Detiene el seguimiento de la ruta
  void _onTrackingStopped(
    RoutesTrackingStopped event,
    Emitter<RoutesState> emit,
  ) {
    _posicionSubscription?.cancel();
    _posicionSubscription = null;
    emit(state.copyWith(siguiendoRuta: false));
  }

  /// Actualización de ubicación durante seguimiento
  void _onLocationUpdated(
    _RoutesLocationUpdated event,
    Emitter<RoutesState> emit,
  ) {
    final pos = LatLng(event.position.latitude, event.position.longitude);

    final userMarker = Marker(
      markerId: const MarkerId("user"),
      position: pos,
      infoWindow: const InfoWindow(title: "Tú"),
    );

    // Centrar cámara en la posición del usuario
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    }

    emit(state.copyWith(
      currentPosition: event.position,
      userMarker: userMarker,
    ));
  }

  /// Guarda la ruta actual
  Future<void> _onSaveRequested(
    RoutesSaveRequested event,
    Emitter<RoutesState> emit,
  ) async {
    if (state.polylineCoordinates.isEmpty || state.currentPosition == null) {
      emit(state.copyWith(
        errorMessage: 'No hay ruta activa para guardar',
      ));
      return;
    }

    final uid = _routesRepository.getCurrentUserId();
    if (uid == null) {
      emit(state.copyWith(
        errorMessage: 'Debes iniciar sesión para guardar rutas',
      ));
      return;
    }

    if (event.routeName.trim().isEmpty) {
      emit(state.copyWith(
        errorMessage: 'El nombre de la ruta no puede estar vacío',
      ));
      return;
    }

    emit(state.copyWith(status: RoutesStatus.savingRoute));

    try {
      // Convertir puntos a JSON
      final puntosJson = state.polylineCoordinates
          .map((p) => GeoPoint(lat: p.latitude, lng: p.longitude))
          .toList();

      final now = DateTime.now();
      final rutaModel = RutaRealizadaModel(
        id: '', // Supabase genera el UUID
        usuarioId: uid,
        nombreRuta: event.routeName.trim(),
        fecha: now,
        puntos: puntosJson,
        distanciaKm: 0.0,
        duracionMinutos: 0,
        descripcionRuta: event.routeDescription?.trim().isEmpty == true
            ? null
            : event.routeDescription?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _routesRepository.saveRoute(rutaModel);

      emit(state.copyWith(
        status: RoutesStatus.routeSaved,
        clearError: true,
      ));

      // Después de un breve delay, volver al estado anterior
      await Future.delayed(const Duration(milliseconds: 500));
      emit(state.copyWith(status: RoutesStatus.routeCalculated));
    } catch (e) {
      emit(state.copyWith(
        status: RoutesStatus.error,
        errorMessage: 'Error al guardar la ruta: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onSaveRequested: $e');
    }
  }

  /// Muestra una ruta guardada en el mapa
  Future<void> _onSavedRouteLoadRequested(
    RoutesSavedRouteLoadRequested event,
    Emitter<RoutesState> emit,
  ) async {
    final ruta = event.routeData;
    final puntos = ruta.puntos;

    if (puntos.isEmpty) {
      emit(state.copyWith(
        errorMessage: 'Esta ruta no tiene puntos para mostrar',
      ));
      return;
    }

    emit(state.copyWith(status: RoutesStatus.loadingRoute));

    try {
      // Limpiar búsqueda anterior inline
      _posicionSubscription?.cancel();
      _posicionSubscription = null;

      List<LatLng> polylineCoordinates = [];

      // Convertir puntos GeoPoint a LatLng
      for (var punto in puntos) {
        polylineCoordinates.add(
          LatLng(punto.lat, punto.lng),
        );
      }

      if (polylineCoordinates.isEmpty) {
        emit(state.copyWith(
          status: RoutesStatus.error,
          errorMessage: 'No se pudieron procesar los puntos de la ruta',
        ));
        return;
      }

      // Crear polyline con color distintivo
      final polylines = <Polyline>{
        Polyline(
          polylineId: PolylineId(
            "ruta_guardada_${ruta.id}",
          ),
          color: Colors.purple,
          width: 6,
          points: polylineCoordinates,
        ),
      };

      final destinationPoint = polylineCoordinates.last;
      final destinationMarker = Marker(
        markerId: const MarkerId('saved_route_destination'),
        position: destinationPoint,
        draggable: true,
        onDragEnd: (newPosition) => add(RoutesMarkerDragged(newPosition)),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(title: ruta.nombreRuta),
      );

      emit(state.copyWith(
        status: RoutesStatus.routeLoaded,
        polylineCoordinates: polylineCoordinates,
        polylines: polylines,
        selectedPlaceName: ruta.nombreRuta,
        searchedMarker: destinationMarker,
        clearPredictions: true,
        clearError: true,
      ));

      // Centrar el mapa en la ruta
      if (_mapController != null && polylineCoordinates.isNotEmpty) {
        if (polylineCoordinates.length == 1) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(polylineCoordinates.first, 15),
          );
        } else {
          LatLngBounds bounds = _calculateBounds(polylineCoordinates);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      }
    } catch (e) {
      emit(state.copyWith(
        status: RoutesStatus.error,
        errorMessage: 'Error al mostrar la ruta guardada: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onSavedRouteLoadRequested: $e');
    }
  }

  /// Carga y muestra una ruta por su ID
  Future<void> _onLoadByIdRequested(
    RoutesLoadByIdRequested event,
    Emitter<RoutesState> emit,
  ) async {
    emit(state.copyWith(status: RoutesStatus.loadingRoute));

    try {
      final ruta = await _routesRepository.getRouteById(event.routeId);
      add(RoutesSavedRouteLoadRequested(ruta));
    } catch (e) {
      emit(state.copyWith(
        status: RoutesStatus.error,
        errorMessage: 'No se pudo cargar la ruta: ${e.toString()}',
      ));
      debugPrint('Error en RoutesBloc._onLoadByIdRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    RoutesErrorCleared event,
    Emitter<RoutesState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  /// Calcula los bounds para una lista de puntos
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Marcador de destino arrastrado — actualiza posición y recalcula ruta
  void _onMarkerDragged(
    RoutesMarkerDragged event,
    Emitter<RoutesState> emit,
  ) {
    if (state.searchedMarker == null) return;

    final current = state.searchedMarker!;
    final updatedMarker = Marker(
      markerId: current.markerId,
      position: event.newPosition,
      draggable: true,
      onDragEnd: (newPosition) => add(RoutesMarkerDragged(newPosition)),
      infoWindow: current.infoWindow,
      icon: current.icon,
    );

    emit(state.copyWith(searchedMarker: updatedMarker));
    add(RoutesCalculateRequested(event.newPosition));
  }

  @override
  Future<void> close() {
    _posicionSubscription?.cancel();
    return super.close();
  }
}
