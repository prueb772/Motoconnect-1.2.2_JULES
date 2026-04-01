import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/services/map_picker_service.dart';
import 'map_picker_event.dart';
import 'map_picker_state.dart';

class MapPickerBloc extends Bloc<MapPickerEvent, MapPickerState> {
  final MapPickerService _mapPickerService;

  MapPickerBloc({required MapPickerService mapPickerService})
      : _mapPickerService = mapPickerService,
        super(const MapPickerInitial()) {
    on<MapPickerInitialize>(_onInitialize);
    on<MapPickerUpdateMarker>(_onUpdateMarker);
    on<MapPickerSelectSearchedPlace>(_onSelectSearchedPlace);
    on<MapPickerSearchRequested>(_onSearchRequested);
    on<MapPickerLocationSelected>(_onLocationSelected);
    on<MapPickerCleared>(_onCleared);
    on<MapPickerLocationConfirmed>(_onLocationConfirmed);
  }

  Future<void> _onInitialize(
    MapPickerInitialize event,
    Emitter<MapPickerState> emit,
  ) async {
    if (event.initialPosition != null) {
      add(MapPickerUpdateMarker(event.initialPosition!, addressFromSearch: event.initialSearchQuery));
    }
    if (event.initialSearchQuery != null && event.initialSearchQuery!.isNotEmpty) {
      add(MapPickerSearchRequested(event.initialSearchQuery!));
    }
  }

  Future<void> _onUpdateMarker(
    MapPickerUpdateMarker event,
    Emitter<MapPickerState> emit,
  ) async {
    emit(MapPickerLocationUpdated(
      pickedLocation: event.position,
      currentAddress: event.addressFromSearch ?? "Obteniendo dirección...",
      isLoadingAddress: event.addressFromSearch == null,
    ));

    if (event.addressFromSearch == null) {
      final address = await _mapPickerService.reverseGeocode(
        event.position.latitude,
        event.position.longitude,
      );
      emit(MapPickerLocationUpdated(
        pickedLocation: event.position,
        currentAddress: address ?? "No se encontró dirección para esta ubicación.",
        isLoadingAddress: false,
      ));
    }
  }

  Future<void> _onSelectSearchedPlace(
    MapPickerSelectSearchedPlace event,
    Emitter<MapPickerState> emit,
  ) async {
    if (event.prediction.placeId == null) return;

    emit(MapPickerInitial(
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
    ));

    final details = await _mapPickerService.getPlaceDetails(
      event.prediction.placeId!,
    );
    if (details != null && details.geometry != null) {
      final lat = details.geometry!.location!.lat!;
      final lng = details.geometry!.location!.lng!;
      final newPos = LatLng(lat, lng);
      final String address =
          details.formattedAddress ??
          details.name ??
          event.prediction.description ??
          "Dirección no disponible";

      add(MapPickerUpdateMarker(newPos, addressFromSearch: address));
    }
  }

  Future<void> _onSearchRequested(
    MapPickerSearchRequested event,
    Emitter<MapPickerState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(MapPickerInitial(
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
      ));
      return;
    }

    emit(MapPickerLoading(
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
    ));
    try {
      final predictions = await _mapPickerService.searchPlaces(event.query);
      emit(MapPickerLoaded(
        results: predictions,
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
      ));
    } catch (e) {
      emit(MapPickerError('Error al buscar lugares: \$e',
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
      ));
    }
  }

  void _onLocationSelected(
    MapPickerLocationSelected event,
    Emitter<MapPickerState> emit,
  ) {
    emit(MapPickerInitial(
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
    ));
  }

  void _onCleared(
    MapPickerCleared event,
    Emitter<MapPickerState> emit,
  ) {
    emit(MapPickerInitial(
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
    ));
  }

  void _onLocationConfirmed(
    MapPickerLocationConfirmed event,
    Emitter<MapPickerState> emit,
  ) {
    emit(MapPickerLocationConfirmedState(event.result,
        pickedLocation: state.pickedLocation,
        currentAddress: state.currentAddress,
        isLoadingAddress: state.isLoadingAddress,
    ));
  }
}
