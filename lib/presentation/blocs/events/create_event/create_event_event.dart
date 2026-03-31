part of 'create_event_bloc.dart';

/// Eventos del CreateEventBloc
sealed class CreateEventEvent extends Equatable {
  const CreateEventEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar grupos del usuario
class CreateEventGruposLoadRequested extends CreateEventEvent {
  const CreateEventGruposLoadRequested();
}

/// Cargar grupos asociados a un evento (modo edición)
class CreateEventGruposForEventLoadRequested extends CreateEventEvent {
  const CreateEventGruposForEventLoadRequested(this.eventId);

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// Guardar evento (crear o actualizar)
class CreateEventSaveRequested extends CreateEventEvent {
  const CreateEventSaveRequested({
    required this.title,
    required this.description,
    required this.dateTime,
    required this.destinoTexto,
    required this.isPublic,
    required this.gruposIds,
    this.existingEventId,
    this.existingImageUrl,
    this.imageFile,
    this.puntoEncuentroTexto,
    this.puntoEncuentroLat,
    this.puntoEncuentroLng,
    this.destinoLat,
    this.destinoLng,
  });

  final String title;
  final String description;
  final DateTime dateTime;
  final String destinoTexto;
  final bool isPublic;
  final List<String> gruposIds;
  final String? existingEventId;
  final String? existingImageUrl;
  final File? imageFile;
  final String? puntoEncuentroTexto;
  final double? puntoEncuentroLat;
  final double? puntoEncuentroLng;
  final double? destinoLat;
  final double? destinoLng;

  @override
  List<Object?> get props => [
        title,
        description,
        dateTime,
        destinoTexto,
        isPublic,
        gruposIds,
        existingEventId,
        existingImageUrl,
        imageFile,
        puntoEncuentroTexto,
        puntoEncuentroLat,
        puntoEncuentroLng,
        destinoLat,
        destinoLng,
      ];
}

/// Limpiar error
class CreateEventErrorCleared extends CreateEventEvent {
  const CreateEventErrorCleared();
}
