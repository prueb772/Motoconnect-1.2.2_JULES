import 'package:equatable/equatable.dart';
import 'package:google_place/google_place.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/models/map_picker_result.dart';

sealed class MapPickerState extends Equatable {
  final LatLng? pickedLocation;
  final String currentAddress;
  final bool isLoadingAddress;
  final List<AutocompletePrediction> results;

  const MapPickerState({
    this.pickedLocation,
    this.currentAddress = "Mueve el mapa o busca una dirección",
    this.isLoadingAddress = false,
    this.results = const [],
  });

  @override
  List<Object?> get props => [pickedLocation, currentAddress, isLoadingAddress, results];
}

final class MapPickerInitial extends MapPickerState {
  const MapPickerInitial({
    super.pickedLocation,
    super.currentAddress,
    super.isLoadingAddress,
    super.results,
  });
}

final class MapPickerLoading extends MapPickerState {
  const MapPickerLoading({
    super.pickedLocation,
    super.currentAddress,
    super.isLoadingAddress,
    super.results,
  });
}

final class MapPickerLoaded extends MapPickerState {
  const MapPickerLoaded({
    super.pickedLocation,
    super.currentAddress,
    super.isLoadingAddress,
    required List<AutocompletePrediction> results,
  }) : super(results: results);
}

final class MapPickerError extends MapPickerState {
  final String message;
  const MapPickerError(this.message, {
    super.pickedLocation,
    super.currentAddress,
    super.isLoadingAddress,
    super.results,
  });

  @override
  List<Object?> get props => [...super.props, message];
}

final class MapPickerLocationConfirmedState extends MapPickerState {
  final MapPickerResult result;
  const MapPickerLocationConfirmedState(this.result, {
    super.pickedLocation,
    super.currentAddress,
    super.isLoadingAddress,
    super.results,
  });

  @override
  List<Object?> get props => [...super.props, result];
}

final class MapPickerLocationUpdated extends MapPickerState {
  const MapPickerLocationUpdated({
    required super.pickedLocation,
    required super.currentAddress,
    required super.isLoadingAddress,
    super.results,
  });
}
