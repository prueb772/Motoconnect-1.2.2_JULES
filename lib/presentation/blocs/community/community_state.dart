part of 'community_bloc.dart';

/// Clase auxiliar para combinar datos de la publicación con información adicional
class PublicacionConAutor extends Equatable {
  final ComentarioComunidadModel publicacionData;
  final String? nombreAutor;
  final String? avatarUrl;
  final String? nombreRutaCompartida;
  final String? idRutaCompartida;
  final Event? eventoCompartidoData;
  final String? nombreOrganizadorEvento;

  const PublicacionConAutor({
    required this.publicacionData,
    this.nombreAutor,
    this.avatarUrl,
    this.nombreRutaCompartida,
    this.idRutaCompartida,
    this.eventoCompartidoData,
    this.nombreOrganizadorEvento,
  });

  @override
  List<Object?> get props => [
        publicacionData,
        nombreAutor,
        avatarUrl,
        nombreRutaCompartida,
        idRutaCompartida,
        eventoCompartidoData,
        nombreOrganizadorEvento,
      ];
}

/// Estados posibles de la pantalla de comunidad
enum CommunityStatus {
  /// Estado inicial
  initial,

  /// Cargando publicaciones
  loading,

  /// Publicaciones cargadas correctamente
  loaded,

  /// Publicando
  posting,

  /// Publicado exitosamente
  posted,

  /// Eliminado exitosamente
  deleted,

  /// Error
  error,
}

/// Estado del CommunityBloc
class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.publicaciones = const [],
    this.currentUserId,
    this.errorMessage,
  });

  /// Estado actual
  final CommunityStatus status;

  /// Lista completa de publicaciones
  final List<PublicacionConAutor> publicaciones;

  /// ID del usuario autenticado actual
  final String? currentUserId;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Publicaciones a mostrar
  List<PublicacionConAutor> get displayPublicaciones => publicaciones;

  /// Crea una copia del estado con los campos modificados
  CommunityState copyWith({
    CommunityStatus? status,
    List<PublicacionConAutor>? publicaciones,
    String? currentUserId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommunityState(
      status: status ?? this.status,
      publicaciones: publicaciones ?? this.publicaciones,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        publicaciones,
        currentUserId,
        errorMessage,
      ];
}
