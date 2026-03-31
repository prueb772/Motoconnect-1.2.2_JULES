part of 'saved_routes_bloc.dart';

/// Estados posibles de la pantalla de Rutas Guardadas
enum SavedRoutesStatus {
  /// Estado inicial
  initial,

  /// Cargando rutas
  loading,

  /// Rutas cargadas correctamente
  loaded,

  /// Error al cargar
  error,

  /// Procesando acción (eliminar, compartir)
  processing,

  /// Ruta compartida exitosamente
  shared,

  /// Ruta eliminada exitosamente
  deleted,

  /// Ruta guardada/creada exitosamente
  saved,
}

/// Estado del SavedRoutesBloc
///
/// Representa el estado de la pantalla de Rutas Guardadas.
class SavedRoutesState extends Equatable {
  const SavedRoutesState({
    this.status = SavedRoutesStatus.initial,
    this.routes = const [],
    this.errorMessage,
  });

  /// Estado actual
  final SavedRoutesStatus status;

  /// Lista de rutas
  final List<RutaRealizadaModel> routes;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Rutas a mostrar
  List<RutaRealizadaModel> get displayRoutes => routes;

  /// Crea una copia del estado con los campos modificados
  SavedRoutesState copyWith({
    SavedRoutesStatus? status,
    List<RutaRealizadaModel>? routes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SavedRoutesState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        routes,
        errorMessage,
      ];
}
