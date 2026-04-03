part of 'talleres_bloc.dart';

/// Eventos del TalleresBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Talleres.
sealed class TalleresEvent extends Equatable {
  const TalleresEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar lista de talleres
class TalleresLoadRequested extends TalleresEvent {
  const TalleresLoadRequested();
}

/// Refrescar lista de talleres
class TalleresRefreshRequested extends TalleresEvent {
  const TalleresRefreshRequested();
}

/// Crear nuevo taller
class TallerCreateRequested extends TalleresEvent {
  const TallerCreateRequested(this.tallerData);

  final TallerModel tallerData;

  @override
  List<Object?> get props => [tallerData];
}

/// Actualizar taller existente
class TallerUpdateRequested extends TalleresEvent {
  const TallerUpdateRequested({
    required this.tallerId,
    required this.tallerData,
  });

  final String tallerId;
  final TallerModel tallerData;

  @override
  List<Object?> get props => [tallerId, tallerData];
}

/// Eliminar taller
class TallerDeleteRequested extends TalleresEvent {
  const TallerDeleteRequested(this.tallerId);

  final String tallerId;

  @override
  List<Object?> get props => [tallerId];
}

/// Compartir taller en comunidad
class TallerShareRequested extends TalleresEvent {
  const TallerShareRequested({
    required this.tallerData,
    this.message,
  });

  final TallerModel tallerData;
  final String? message;

  @override
  List<Object?> get props => [tallerData, message];
}

/// Limpiar mensaje de error
class TalleresErrorCleared extends TalleresEvent {
  const TalleresErrorCleared();
}
