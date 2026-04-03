import 'package:equatable/equatable.dart';
import '../../../../../data/models/ruta_sesion_model.dart';
import '../../../../../data/models/navigation_progress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class MapaNavigationEvent extends Equatable {
  const MapaNavigationEvent();

  @override
  List<Object?> get props => [];
}

class MapaNavigationIniciar extends MapaNavigationEvent {
  final String sesionId;
  final bool estaAprobado;

  const MapaNavigationIniciar(this.sesionId, this.estaAprobado);

  @override
  List<Object> get props => [sesionId, estaAprobado];
}

class MapaNavigationRutaActualizada extends MapaNavigationEvent {
  final RutaSesionModel? ruta;

  const MapaNavigationRutaActualizada(this.ruta);

  @override
  List<Object?> get props => [ruta];
}

class MapaNavigationProgresoGrupalActualizado extends MapaNavigationEvent {
  final Map<String, NavigationProgress> progress;

  const MapaNavigationProgresoGrupalActualizado(this.progress);

  @override
  List<Object> get props => [progress];
}

class MapaNavigationCompartirRuta extends MapaNavigationEvent {
  final double destinoLat;
  final double destinoLng;
  final String? destinoNombre;

  const MapaNavigationCompartirRuta({
    required this.destinoLat,
    required this.destinoLng,
    this.destinoNombre,
  });

  @override
  List<Object?> get props => [destinoLat, destinoLng, destinoNombre];
}

class MapaNavigationCancelarRuta extends MapaNavigationEvent {}

class MapaNavigationAjustarDestino extends MapaNavigationEvent {
  final LatLng destinoAjustado;

  const MapaNavigationAjustarDestino(this.destinoAjustado);

  @override
  List<Object> get props => [destinoAjustado];
}

class MapaNavigationLlegadaManual extends MapaNavigationEvent {}

class MapaNavigationFinalizarViaje extends MapaNavigationEvent {}

class MapaNavigationDismissError extends MapaNavigationEvent {}

class MapaNavigationDismissLlegada extends MapaNavigationEvent {}
