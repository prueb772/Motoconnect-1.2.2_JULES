part of 'talleres_bloc.dart';

/// Clase auxiliar para combinar datos del taller con el nombre del creador
class TallerConCreador extends Equatable {
  final TallerModel tallerData;
  final String? nombreCreador;

  const TallerConCreador({
    required this.tallerData,
    this.nombreCreador,
  });

  @override
  List<Object?> get props => [tallerData, nombreCreador];
}

/// Estados posibles de la pantalla de talleres
enum TalleresStatus {
  /// Estado inicial
  initial,

  /// Cargando talleres
  loading,

  /// Talleres cargados correctamente
  loaded,

  /// Guardando (crear/actualizar)
  saving,

  /// Guardado exitoso
  saved,

  /// Procesando (eliminar/compartir)
  processing,

  /// Compartido exitosamente
  shared,

  /// Eliminado exitosamente
  deleted,

  /// Error
  error,
}

/// Estado del TalleresBloc
class TalleresState extends Equatable {
  const TalleresState({
    this.status = TalleresStatus.initial,
    this.talleres = const [],
    this.currentUserId,
    this.errorMessage,
  });

  /// Estado actual
  final TalleresStatus status;

  /// Lista completa de talleres
  final List<TallerConCreador> talleres;

  /// ID del usuario autenticado actual
  final String? currentUserId;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Talleres a mostrar
  List<TallerConCreador> get displayTalleres => talleres;

  /// Crea una copia del estado con los campos modificados
  TalleresState copyWith({
    TalleresStatus? status,
    List<TallerConCreador>? talleres,
    String? currentUserId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TalleresState(
      status: status ?? this.status,
      talleres: talleres ?? this.talleres,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        talleres,
        currentUserId,
        errorMessage,
      ];
}

