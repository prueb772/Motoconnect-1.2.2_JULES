import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/map_picker_result.dart';
import '../../../data/services/map_picker_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_place/google_place.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/routes/map_picker/map_picker_bloc.dart';
import '../../blocs/routes/map_picker/map_picker_event.dart';
import '../../blocs/routes/map_picker/map_picker_state.dart';
import '../../../data/models/routes/map_picker_args.dart';

class MapPickerScreen extends StatelessWidget {
  const MapPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as MapPickerArgs?;

    return BlocProvider(
      create: (context) => MapPickerBloc(
        mapPickerService: MapPickerService(),
      ),
      child: _MapPickerScreenView(
        initialPosition: args?.initialPosition,
        initialSearchQuery: args?.initialSearchQuery,
      ),
    );
  }
}

class _MapPickerScreenView extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialSearchQuery;

  const _MapPickerScreenView({
    super.key,
    this.initialPosition,
    this.initialSearchQuery,
  });

  @override
  State<_MapPickerScreenView> createState() => _MapPickerScreenViewState();
}

class _MapPickerScreenViewState extends State<_MapPickerScreenView> {
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();

  final LatLng _defaultInitialPiedecuesta = const LatLng(7.0039, -73.0530);

  @override
  void initState() {
    super.initState();

    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapPickerBloc>().add(MapPickerInitialize(
        initialPosition: widget.initialPosition,
        initialSearchQuery: widget.initialSearchQuery,
      ));
    });
  }

  Future<void> _requestPermissionAndGetCurrentLocation() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        LatLng currentLocation = LatLng(position.latitude, position.longitude);
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation, 15),
          );
        }
      } catch (e) {
        debugPrint("Error obteniendo ubicación actual: $e");
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_defaultInitialPiedecuesta, 13),
          );
        }
      }
    } else {
      debugPrint("Permiso de ubicación denegado.");
      if (mounted && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_defaultInitialPiedecuesta, 13),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.initialPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(widget.initialPosition!, 16),
      );
    } else {
      _requestPermissionAndGetCurrentLocation();
    }
  }

  void _onTapMap(LatLng position) {
    context.read<MapPickerBloc>().add(MapPickerUpdateMarker(position));
    context.read<MapPickerBloc>().add(MapPickerCleared());
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  /// Búsqueda de lugares delegada al servicio
  void _searchPlace(String query) {
    context.read<MapPickerBloc>().add(MapPickerSearchRequested(query));
  }

  void _selectSearchedPlace(AutocompletePrediction prediction) {
    context.read<MapPickerBloc>().add(MapPickerSelectSearchedPlace(prediction));
    FocusScope.of(context).unfocus();
  }

  void _confirmSelection(MapPickerState state) {
    if (state.pickedLocation != null) {
      final result = MapPickerResult(
        latlng: state.pickedLocation!,
        address: state.currentAddress,
      );
      context.read<MapPickerBloc>().add(MapPickerLocationConfirmed(result));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, selecciona una ubicación en el mapa."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MapPickerBloc, MapPickerState>(
      listenWhen: (previous, current) => current is MapPickerLocationConfirmedState,
      listener: (context, state) {
        if (state is MapPickerLocationConfirmedState) {
          Navigator.pop(context, state.result);
        }
      },
      child: BlocBuilder<MapPickerBloc, MapPickerState>(
        builder: (context, state) {
          return Scaffold(
          appBar: AppBar(
            title: const Text("Seleccionar Ubicación"),
            actions: [
              if (state.pickedLocation != null)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _confirmSelection(state),
                  tooltip: "Confirmar Ubicación",
                ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: widget.initialPosition ?? _defaultInitialPiedecuesta,
                    zoom: widget.initialPosition != null ? 16 : 12,
                  ),
                  onTap: _onTapMap,
                  markers: state.pickedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('pickedLocation'),
                            position: state.pickedLocation!,
                            infoWindow: InfoWindow(
                              title: state.currentAddress,
                            ),
                            draggable: true,
                            onDragEnd: (newPosition) {
                              context.read<MapPickerBloc>().add(MapPickerUpdateMarker(newPosition));
                            },
                          )
                        }
                      : {},
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(
                top: 80,
                bottom: 140,
                right: 10,
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Buscar dirección o lugar...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<MapPickerBloc>().add(MapPickerCleared());
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    onChanged: _searchPlace,
                  ),
                  BlocBuilder<MapPickerBloc, MapPickerState>(
                    builder: (context, state) {
                      if (state is MapPickerLoaded && state.results.isNotEmpty) {
                        return Material(
                          elevation: 2,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: state.results.length,
                              itemBuilder: (context, index) {
                                final prediction = state.results[index];
                                return ListTile(
                                  leading: const Icon(Icons.pin_drop_outlined),
                                  title: Text(prediction.description ?? ''),
                                  onTap: () => _selectSearchedPlace(prediction),
                                );
                              },
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Botones de zoom personalizados
          Positioned(
            top: 80,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoom_in",
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoom_out",
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Icon(Icons.remove, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 70,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_pin,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isLoadingAddress
                            ? "Obteniendo dirección..."
                            : state.currentAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
      floatingActionButton:
          state.pickedLocation != null
              ? FloatingActionButton.extended(
                onPressed: () => _confirmSelection(state),
                label: const Text("Confirmar"),
                icon: const Icon(Icons.check_circle_outline),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }
}
