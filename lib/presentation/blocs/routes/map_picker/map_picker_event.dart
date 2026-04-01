import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import '../../../../data/models/map_picker_result.dart';

sealed class MapPickerEvent extends Equatable {
  const MapPickerEvent();

  @override
  List<Object?> get props => [];
}

final class MapPickerInitialize extends MapPickerEvent {
  final LatLng? initialPosition;
  final String? initialSearchQuery;
  const MapPickerInitialize({this.initialPosition, this.initialSearchQuery});

  @override
  List<Object?> get props => [initialPosition, initialSearchQuery];
}

final class MapPickerUpdateMarker extends MapPickerEvent {
  final LatLng position;
  final String? addressFromSearch;
  const MapPickerUpdateMarker(this.position, {this.addressFromSearch});

  @override
  List<Object?> get props => [position, addressFromSearch];
}

final class MapPickerSelectSearchedPlace extends MapPickerEvent {
  final AutocompletePrediction prediction;
  const MapPickerSelectSearchedPlace(this.prediction);

  @override
  List<Object?> get props => [prediction];
}

final class MapPickerSearchRequested extends MapPickerEvent {
  final String query;
  const MapPickerSearchRequested(this.query);

  @override
  List<Object> get props => [query];
}

final class MapPickerLocationSelected extends MapPickerEvent {
  final MapPickerResult result;
  const MapPickerLocationSelected(this.result);

  @override
  List<Object> get props => [result];
}

final class MapPickerLocationConfirmed extends MapPickerEvent {
  final MapPickerResult result;
  const MapPickerLocationConfirmed(this.result);

  @override
  List<Object> get props => [result];
}

final class MapPickerCleared extends MapPickerEvent {}
