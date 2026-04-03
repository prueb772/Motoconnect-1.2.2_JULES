import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerArgs {
  final LatLng? initialPosition;
  final String? initialSearchQuery;

  const MapPickerArgs({
    this.initialPosition,
    this.initialSearchQuery,
  });
}
