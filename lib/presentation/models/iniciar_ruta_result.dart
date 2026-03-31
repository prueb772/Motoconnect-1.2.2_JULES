import 'package:google_maps_flutter/google_maps_flutter.dart';

class IniciarRutaResult {
  final LatLng destino;
  final String? nombre;

  const IniciarRutaResult({
    required this.destino,
    this.nombre,
  });
}
