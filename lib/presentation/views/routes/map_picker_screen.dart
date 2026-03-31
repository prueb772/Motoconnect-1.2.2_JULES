import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/map_picker_result.dart';
import '../../../data/services/map_picker_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_place/google_place.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialSearchQuery;

  const MapPickerScreen({
    super.key,
    this.initialPosition,
    this.initialSearchQuery,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  Marker? _marker;
  String _currentAddress = "Mueve el mapa o busca una dirección";
  bool _isLoadingAddress = false;

  /// Servicio de búsqueda y geocodificación (inyectado)
  final MapPickerService _mapPickerService = MapPickerService();

  List<AutocompletePrediction> _placePredictions = [];
  final TextEditingController _searchController = TextEditingController();

  final LatLng _defaultInitialPiedecuesta = const LatLng(7.0039, -73.0530);

  @override
  void initState() {
    super.initState();
    if (!_mapPickerService.isSearchAvailable) {
      debugPrint(
        "ADVERTENCIA: Google API Key no configurada para MapPickerScreen. "
        "La búsqueda de lugares no funcionará.",
      );
    }

    if (widget.initialPosition != null) {
      _pickedLocation = widget.initialPosition;
      _updateMarkerAndAddress(
        _pickedLocation!,
        fromSearch: widget.initialSearchQuery != null,
      );
    } else {
      _requestPermissionAndGetCurrentLocation();
    }

    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      if (_mapPickerService.isSearchAvailable) {
        _searchPlace(widget.initialSearchQuery!);
      }
    }
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
        if (mounted && _mapController != null && _pickedLocation == null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_defaultInitialPiedecuesta, 13),
          );
        }
      }
    } else {
      debugPrint("Permiso de ubicación denegado.");
      if (mounted && _mapController != null && _pickedLocation == null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_defaultInitialPiedecuesta, 13),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pickedLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickedLocation!, 16),
      );
    } else if (widget.initialPosition == null) {
      _requestPermissionAndGetCurrentLocation();
    }
  }

  Future<void> _updateMarkerAndAddress(
    LatLng position, {
    String? addressFromSearch,
    bool fromSearch = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _pickedLocation = position;
      _marker = Marker(
        markerId: const MarkerId('pickedLocation'),
        position: _pickedLocation!,
        infoWindow: InfoWindow(
          title: addressFromSearch ?? 'Ubicación Seleccionada',
        ),
        draggable: true,
        onDragEnd: (newPosition) {
          _updateMarkerAndAddress(newPosition);
        },
      );
      if (addressFromSearch == null) {
        _isLoadingAddress = true;
        _currentAddress = "Obteniendo dirección...";
      } else {
        _currentAddress = addressFromSearch;
        _searchController.text = addressFromSearch;
      }
    });

    if (!fromSearch) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    }

    // Geocodificación inversa delegada al servicio
    if (addressFromSearch == null) {
      final address = await _mapPickerService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = address ??
              "No se encontró dirección para esta ubicación.";
          _searchController.text = _currentAddress;
          _isLoadingAddress = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _onTapMap(LatLng position) {
    _updateMarkerAndAddress(position);
  }

  /// Búsqueda de lugares delegada al servicio
  Future<void> _searchPlace(String query) async {
    final predictions = await _mapPickerService.searchPlaces(query);
    if (mounted) {
      setState(() => _placePredictions = predictions);
    }
  }

  Future<void> _selectSearchedPlace(AutocompletePrediction prediction) async {
    if (prediction.placeId == null) return;

    if (mounted) setState(() => _placePredictions = []);
    FocusScope.of(context).unfocus();

    final details = await _mapPickerService.getPlaceDetails(
      prediction.placeId!,
    );
    if (details != null && details.geometry != null) {
      final lat = details.geometry!.location!.lat!;
      final lng = details.geometry!.location!.lng!;
      final newPos = LatLng(lat, lng);
      final String address =
          details.formattedAddress ??
          details.name ??
          prediction.description ??
          "Dirección no disponible";
      _searchController.text = address;

      _updateMarkerAndAddress(
        newPos,
        addressFromSearch: address,
        fromSearch: true,
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
    }
  }

  void _confirmSelection() {
    if (_pickedLocation != null) {
      Navigator.pop(context, MapPickerResult(
        latlng: _pickedLocation!,
        address: _currentAddress,
      ));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Ubicación"),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _confirmSelection,
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
              markers: _marker != null ? {_marker!} : {},
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
                                  if (mounted) {
                                    setState(() => _placePredictions = []);
                                  }
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    onChanged: _searchPlace,
                  ),
                  if (_placePredictions.isNotEmpty)
                    Material(
                      elevation: 2,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _placePredictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _placePredictions[index];
                            return ListTile(
                              leading: const Icon(Icons.pin_drop_outlined),
                              title: Text(prediction.description ?? ''),
                              onTap: () => _selectSearchedPlace(prediction),
                            );
                          },
                        ),
                      ),
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
                        _isLoadingAddress
                            ? "Obteniendo dirección..."
                            : _currentAddress,
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
          _pickedLocation != null
              ? FloatingActionButton.extended(
                onPressed: _confirmSelection,
                label: const Text("Confirmar"),
                icon: const Icon(Icons.check_circle_outline),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
