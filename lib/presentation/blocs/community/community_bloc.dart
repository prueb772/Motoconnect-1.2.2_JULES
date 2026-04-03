import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/models/comentario_comunidad_model.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/autor_info.dart';

part 'community_event.dart';
part 'community_state.dart';

/// CommunityBloc - Gestiona el estado de la pantalla de Comunidad
///
/// Este BLoC reemplaza a CommunityViewModel.
/// Es responsable de:
/// - Cargar publicaciones de la comunidad
/// - Crear nuevas publicaciones
/// - Cachear nombres de usuarios
class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  CommunityBloc({
    required CommunityRepository communityRepository,
  })  : _communityRepository = communityRepository,
        super(const CommunityState()) {
    on<CommunityLoadRequested>(_onLoadRequested);
    on<CommunityRefreshRequested>(_onRefreshRequested);
    on<CommunityTextPostRequested>(_onTextPostRequested);
    on<CommunityPostDeleteRequested>(_onPostDeleteRequested);
    on<CommunityErrorCleared>(_onErrorCleared);
    on<CommunityMediaPostRequested>(_onMediaPostRequested);
    on<CommunityPostEditRequested>(_onPostEditRequested);
  }

  final CommunityRepository _communityRepository;

  // Cache de datos de usuarios (nombre y avatar)
  final Map<String, AutorInfo> _cacheUsuarios = {};

  /// Carga las publicaciones de la comunidad
  Future<void> _onLoadRequested(
    CommunityLoadRequested event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(status: CommunityStatus.loading));

    try {
      final publicaciones = await _communityRepository.getPublicaciones();
      final currentUserId = _communityRepository.getCurrentUserId();

      List<PublicacionConAutor> tempLista = [];

      // Limpiar cache para datos actualizados
      _cacheUsuarios.clear();

      for (var publicacion in publicaciones) {
        // Obtener datos del autor
        String? nombreAutor;
        String? avatarAutor;
        final datosAutor = await _obtenerDatosUsuario(publicacion.usuarioId);
        nombreAutor = datosAutor.nombre;
        avatarAutor = datosAutor.fotoPerfilUrl;

        // Variables para rutas y eventos compartidos
        String? nombreRutaComp;
        String? idRutaComp = publicacion.referenciaRutaId;
        Event? eventoDataComp;
        String? nombreOrganizadorEv;
        String? idEventoComp = publicacion.referenciaEventoId;

        // Si es una ruta compartida, obtener su nombre
        if (publicacion.tipo == 'ruta_compartida' && idRutaComp != null) {
          nombreRutaComp = await _communityRepository.getNombreRuta(idRutaComp);
        }
        // Si es un evento compartido, obtener sus datos
        else if (publicacion.tipo == 'evento_compartido' &&
            idEventoComp != null) {
          eventoDataComp = await _communityRepository.getEventoCompartido(idEventoComp);

          if (eventoDataComp != null) {
            final organizadorIdEvento = eventoDataComp.createdBy;
            if (organizadorIdEvento != null) {
              final datosOrganizador = await _obtenerDatosUsuario(organizadorIdEvento);
              nombreOrganizadorEv = datosOrganizador.nombre;
            }
          }
        }

        tempLista.add(
          PublicacionConAutor(
            publicacionData: publicacion,
            nombreAutor: nombreAutor ?? "Usuario Anónimo",
            avatarUrl: avatarAutor,
            nombreRutaCompartida: nombreRutaComp,
            idRutaCompartida: idRutaComp,
            eventoCompartidoData: eventoDataComp,
            nombreOrganizadorEvento: nombreOrganizadorEv,
          ),
        );
      }

      emit(state.copyWith(
        status: CommunityStatus.loaded,
        publicaciones: tempLista,
        currentUserId: currentUserId,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: 'Error al cargar publicaciones: ${e.toString()}',
      ));
      debugPrint('Error en CommunityBloc._onLoadRequested: $e');
    }
  }

  /// Refresca las publicaciones
  Future<void> _onRefreshRequested(
    CommunityRefreshRequested event,
    Emitter<CommunityState> emit,
  ) async {
    await _onLoadRequested(const CommunityLoadRequested(), emit);
  }

  /// Crea una publicación de texto simple
  Future<void> _onTextPostRequested(
    CommunityTextPostRequested event,
    Emitter<CommunityState> emit,
  ) async {
    final currentUserId = _communityRepository.getCurrentUserId();

    if (currentUserId == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión para publicar'));
      return;
    }

    if (event.content.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Escribe algo para publicar'));
      return;
    }

    emit(state.copyWith(status: CommunityStatus.posting));

    try {
      await _communityRepository.createTextPost(
        userId: currentUserId,
        content: event.content.trim(),
      );

      emit(state.copyWith(status: CommunityStatus.posted));

      // Recargar publicaciones
      add(const CommunityLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: 'Error al crear la publicación: ${e.toString()}',
      ));
      debugPrint('Error en CommunityBloc._onTextPostRequested: $e');
    }
  }

  /// Elimina una publicación
  Future<void> _onPostDeleteRequested(
    CommunityPostDeleteRequested event,
    Emitter<CommunityState> emit,
  ) async {
    final currentUserId = _communityRepository.getCurrentUserId();

    if (currentUserId == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión'));
      return;
    }

    emit(state.copyWith(status: CommunityStatus.loading));

    try {
      await _communityRepository.deletePost(
        postId: event.postId,
        userId: currentUserId,
      );

      // Remover de la lista local
      final updatedPublicaciones = state.publicaciones
          .where((p) => p.publicacionData.id != event.postId)
          .toList();

      emit(state.copyWith(
        status: CommunityStatus.deleted,
        publicaciones: updatedPublicaciones,
        clearError: true,
      ));

      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(status: CommunityStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: 'Error al eliminar publicación: ${e.toString()}',
      ));
      debugPrint('Error en CommunityBloc._onPostDeleteRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    CommunityErrorCleared event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  /// Crea una publicación con media (imagen o video)
  Future<void> _onMediaPostRequested(
    CommunityMediaPostRequested event,
    Emitter<CommunityState> emit,
  ) async {
    final currentUserId = _communityRepository.getCurrentUserId();

    if (currentUserId == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión para publicar'));
      return;
    }

    emit(state.copyWith(status: CommunityStatus.posting));

    try {
      await _communityRepository.createMediaPost(
        userId: currentUserId,
        tipo: event.tipo,
        content: event.content?.trim().isEmpty == true ? null : event.content?.trim(),
        mediaUrl: event.mediaUrl,
      );

      emit(state.copyWith(status: CommunityStatus.posted));

      // Recargar publicaciones
      add(const CommunityLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: 'Error al crear la publicación: ${e.toString()}',
      ));
      debugPrint('Error en CommunityBloc._onMediaPostRequested: $e');
    }
  }

  /// Edita una publicación existente
  Future<void> _onPostEditRequested(
    CommunityPostEditRequested event,
    Emitter<CommunityState> emit,
  ) async {
    final currentUserId = _communityRepository.getCurrentUserId();

    if (currentUserId == null) {
      emit(state.copyWith(errorMessage: 'Debes iniciar sesión'));
      return;
    }

    emit(state.copyWith(status: CommunityStatus.loading));

    try {
      await _communityRepository.editPost(
        postId: event.postId,
        userId: currentUserId,
        newContent: event.newContent,
      );

      emit(state.copyWith(status: CommunityStatus.posted));

      // Recargar publicaciones
      add(const CommunityLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: 'Error al editar publicación: ${e.toString()}',
      ));
      debugPrint('Error en CommunityBloc._onPostEditRequested: $e');
    }
  }

  /// Obtiene los datos de un usuario por su ID (con cache)
  Future<AutorInfo> _obtenerDatosUsuario(String userId) async {
    if (_cacheUsuarios.containsKey(userId)) {
      return _cacheUsuarios[userId]!;
    }

    final datos = await _communityRepository.getDatosUsuario(userId);
    _cacheUsuarios[userId] = datos;
    return datos;
  }

  /// Obtiene el ID del usuario actual (expuesto desde el state)
  String? get currentUserId => _communityRepository.getCurrentUserId();
}
