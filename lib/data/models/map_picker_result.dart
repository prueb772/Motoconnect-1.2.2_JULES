/// Resultado de MapPickerScreen
///
/// DTO tipado que reemplaza el Map<String, dynamic> genérico
/// que retornaba MapPickerScreen. Usado por talleres_screen,
/// create_event_screen y cualquier pantalla que invoque el picker de mapa.
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerResult {
  /// Coordenadas seleccionadas en el mapa
  final LatLng latlng;

  /// Dirección legible obtenida por geocodificación inversa o búsqueda
  final String address;

  const MapPickerResult({
    required this.latlng,
    required this.address,
  });
}
