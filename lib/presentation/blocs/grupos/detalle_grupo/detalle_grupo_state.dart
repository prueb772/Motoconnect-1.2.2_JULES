part of 'detalle_grupo_bloc.dart';

enum DetalleGrupoStatus { initial, loading, loaded, error }

/// Estados de acciones puntuales (no afectan la UI principal)
enum DetalleGrupoActionStatus {
  idle,
  loading,
  sesionCreada,
  sesionFinalizada,
  miembroExpulsado,
  grupoSalido,
  grupoEliminado,
  codigoRegenerado,
  error,
}

class DetalleGrupoState extends Equatable {
  const DetalleGrupoState({
    this.status = DetalleGrupoStatus.initial,
    this.actionStatus = DetalleGrupoActionStatus.idle,
    this.miembros = const [],
    this.sesionesActivas = const [],
    this.esAdmin = false,
    this.solicitudesPendientes = 0,
    this.errorMessage,
    this.actionErrorMessage,
    this.actionMessage,
    this.sesionCreada,
    this.nuevoCodigo,
  });

  final DetalleGrupoStatus status;
  final DetalleGrupoActionStatus actionStatus;
  final List<MiembroGrupoModel> miembros;
  final List<SesionRutaActivaModel> sesionesActivas;
  final bool esAdmin;
  final int solicitudesPendientes;
  final String? errorMessage;
  final String? actionErrorMessage;
  final String? actionMessage;
  final SesionRutaActivaModel? sesionCreada;
  final String? nuevoCodigo;

  DetalleGrupoState copyWith({
    DetalleGrupoStatus? status,
    DetalleGrupoActionStatus? actionStatus,
    List<MiembroGrupoModel>? miembros,
    List<SesionRutaActivaModel>? sesionesActivas,
    bool? esAdmin,
    int? solicitudesPendientes,
    String? errorMessage,
    String? actionErrorMessage,
    String? actionMessage,
    SesionRutaActivaModel? sesionCreada,
    String? nuevoCodigo,
  }) {
    return DetalleGrupoState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      miembros: miembros ?? this.miembros,
      sesionesActivas: sesionesActivas ?? this.sesionesActivas,
      esAdmin: esAdmin ?? this.esAdmin,
      solicitudesPendientes: solicitudesPendientes ?? this.solicitudesPendientes,
      errorMessage: errorMessage ?? this.errorMessage,
      actionErrorMessage: actionErrorMessage ?? this.actionErrorMessage,
      actionMessage: actionMessage ?? this.actionMessage,
      sesionCreada: sesionCreada ?? this.sesionCreada,
      nuevoCodigo: nuevoCodigo ?? this.nuevoCodigo,
    );
  }

  @override
  List<Object?> get props => [
        status,
        actionStatus,
        miembros,
        sesionesActivas,
        esAdmin,
        solicitudesPendientes,
        errorMessage,
        actionErrorMessage,
        actionMessage,
        sesionCreada,
        nuevoCodigo,
      ];
}
