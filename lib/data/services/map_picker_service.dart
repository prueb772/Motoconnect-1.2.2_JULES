/// Servicio de selección de ubicación en mapa
///
/// Encapsula la lógica de búsqueda de lugares (Google Places API)
/// y geocodificación inversa, separándola de la View.
///
/// Responsabilidades:
/// - Búsqueda de lugares por texto (autocomplete)
/// - Obtener detalles de un lugar por placeId
/// - Geocodificación inversa (coordenadas → dirección)
library;

import 'package:google_place/google_place.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../../core/constants/api_constants.dart';

class MapPickerService {
  late final GooglePlace? _googlePlace;

  MapPickerService() {
    final apiKey = ApiConstants.googleMapsApiKey;
    if (apiKey.isNotEmpty && apiKey != 'TU_Maps_API_KEY') {
      _googlePlace = GooglePlace(apiKey);
    } else {
      _googlePlace = null;
    }
  }

  /// Indica si el servicio de búsqueda de lugares está disponible
  bool get isSearchAvailable => _googlePlace != null;

  /// Busca lugares por texto usando Google Places Autocomplete
  ///
  /// Retorna lista de predicciones (puede estar vacía)
  Future<List<AutocompletePrediction>> searchPlaces(String query) async {
    if (query.isEmpty || _googlePlace == null) return [];

    final result = await _googlePlace!.autocomplete.get(
      query,
      region: 'co',
      language: 'es',
    );

    if (result != null && result.predictions != null) {
      return result.predictions!;
    }
    return [];
  }

  /// Obtiene los detalles de un lugar por su placeId
  ///
  /// Retorna null si no se encuentran detalles
  Future<DetailsResult?> getPlaceDetails(String placeId) async {
    if (_googlePlace == null) return null;

    final details = await _googlePlace!.details.get(
      placeId,
      language: 'es',
    );

    return details?.result;
  }

  /// Geocodificación inversa: coordenadas → dirección legible
  ///
  /// Retorna la dirección formateada o null si no se encuentra
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      String address =
          '${place.street ?? ''}'
          '${place.subLocality != null && place.subLocality!.isNotEmpty ? ', ${place.subLocality}' : ''}'
          '${place.locality != null && place.locality!.isNotEmpty ? ', ${place.locality}' : ''}'
          '${place.administrativeArea != null && place.administrativeArea!.isNotEmpty ? ', ${place.administrativeArea}' : ''}';

      if (address.startsWith(', ')) {
        address = address.substring(2);
      }

      return address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }
}
