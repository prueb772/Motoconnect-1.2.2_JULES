part of 'community_bloc.dart';

/// Eventos del CommunityBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Comunidad.
sealed class CommunityEvent extends Equatable {
  const CommunityEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar publicaciones
class CommunityLoadRequested extends CommunityEvent {
  const CommunityLoadRequested();
}

/// Refrescar publicaciones
class CommunityRefreshRequested extends CommunityEvent {
  const CommunityRefreshRequested();
}

/// Crear publicación de texto simple
class CommunityTextPostRequested extends CommunityEvent {
  const CommunityTextPostRequested(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// Eliminar publicación
class CommunityPostDeleteRequested extends CommunityEvent {
  const CommunityPostDeleteRequested(this.postId);

  final String postId;

  @override
  List<Object?> get props => [postId];
}

/// Limpiar mensaje de error
class CommunityErrorCleared extends CommunityEvent {
  const CommunityErrorCleared();
}

/// Crear publicación con media (imagen o video)
class CommunityMediaPostRequested extends CommunityEvent {
  const CommunityMediaPostRequested({
    this.content,
    required this.mediaUrl,
    required this.tipo,
  });

  final String? content;
  final String mediaUrl;
  final String tipo; // 'imagen' o 'video'

  @override
  List<Object?> get props => [content, mediaUrl, tipo];
}

/// Editar publicación
class CommunityPostEditRequested extends CommunityEvent {
  const CommunityPostEditRequested({
    required this.postId,
    required this.newContent,
  });

  final String postId;
  final String newContent;

  @override
  List<Object?> get props => [postId, newContent];
}
