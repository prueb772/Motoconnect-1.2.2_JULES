import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/storage_service.dart';
import 'package:video_player/video_player.dart';
import '../../../data/models/event_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/models/rutas_screen_args.dart';
import '../../blocs/community/community_bloc.dart';

class ComunidadScreen extends StatelessWidget {
  const ComunidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CommunityBloc(
        communityRepository: context.read<CommunityRepository>(),
      )..add(const CommunityLoadRequested()),
      child: const _ComunidadView(),
    );
  }
}

class _ComunidadView extends StatefulWidget {
  const _ComunidadView();

  @override
  State<_ComunidadView> createState() => _ComunidadViewState();
}

class _ComunidadViewState extends State<_ComunidadView> {
  final TextEditingController _textoController = TextEditingController();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  // Estado para media seleccionada (mantenido en View - operación de UI)
  File? _selectedMediaFile;
  bool _isVideo = false;
  bool _subiendoMedia = false;

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  /// Selecciona una imagen de la galería
  Future<void> _seleccionarImagen() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedMediaFile = File(image.path);
          _isVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
          ),
        );
      }
    }
  }

  /// Selecciona un video de la galería
  Future<void> _seleccionarVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (video != null) {
        setState(() {
          _selectedMediaFile = File(video.path);
          _isVideo = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar video: ${e.toString()}'),
          ),
        );
      }
    }
  }

  /// Limpia el archivo seleccionado
  void _limpiarMediaSeleccionada() {
    setState(() {
      _selectedMediaFile = null;
      _isVideo = false;
    });
  }

  /// Crea una publicación (con o sin media)
  Future<void> _crearPublicacion() async {
    final currentUserId = context.read<CommunityBloc>().state.currentUserId;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debes iniciar sesión para publicar.")),
        );
      }
      return;
    }

    final String contenido = _textoController.text.trim();
    if (contenido.isEmpty && _selectedMediaFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Escribe algo o selecciona una imagen/video."),
          ),
        );
      }
      return;
    }

    try {
      setState(() => _subiendoMedia = true);

      String? mediaUrl;
      String tipo = 'texto';

      // Si hay un archivo seleccionado, subirlo primero
      if (_selectedMediaFile != null) {
        final postId = DateTime.now().millisecondsSinceEpoch.toString();
        mediaUrl = await _storageService.uploadCommunityMedia(
          mediaFile: _selectedMediaFile!,
          userId: currentUserId,
          postId: postId,
          isVideo: _isVideo,
        );
        tipo = _isVideo ? 'video' : 'imagen';
      }

      if (mounted) {
        final bloc = context.read<CommunityBloc>();

        if (mediaUrl != null) {
          bloc.add(CommunityMediaPostRequested(
            content: contenido.isEmpty ? null : contenido,
            mediaUrl: mediaUrl,
            tipo: tipo,
          ));
        } else {
          bloc.add(CommunityTextPostRequested(contenido));
        }

        _textoController.clear();
        _limpiarMediaSeleccionada();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al crear la publicación: ${e.toString()}"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoMedia = false);
    }
  }

  /// Elimina una publicación
  Future<void> _eliminarPublicacion(String publicacionId, String? mediaUrl) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta publicación? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Eliminar el archivo de media si existe
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        await _storageService.deleteCommunityMedia(mediaUrl: mediaUrl);
      }

      if (mounted) {
        context.read<CommunityBloc>().add(CommunityPostDeleteRequested(publicacionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Edita una publicación
  Future<void> _editarPublicacion(String publicacionId, String contenidoActual) async {
    final nuevoContenido = await showDialog<String>(
      context: context,
      builder: (context) => _EditarPublicacionDialog(contenidoActual: contenidoActual),
    );

    if (nuevoContenido == null || nuevoContenido.isEmpty) return;

    if (mounted) {
      context.read<CommunityBloc>().add(CommunityPostEditRequested(
        postId: publicacionId,
        newContent: nuevoContenido,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityBloc, CommunityState>(
      listener: (context, state) {
        if (state.status == CommunityStatus.posted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.purple[700],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Publicación creada",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state.status == CommunityStatus.deleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publicación eliminada')),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<CommunityBloc>().add(const CommunityErrorCleared());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Comunidad Biker"),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<CommunityBloc>().add(const CommunityRefreshRequested());
                },
                tooltip: 'Refrescar',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildContent(context, state)),
                const Divider(height: 1),
                _buildMediaPreview(),
                _buildInputArea(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CommunityState state) {
    if (state.status == CommunityStatus.loading && state.publicaciones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.displayPublicaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "Aún no hay publicaciones.",
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              "¡Sé el primero en compartir algo!",
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityBloc>().add(const CommunityRefreshRequested());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: state.displayPublicaciones.length,
        itemBuilder: (context, index) {
          final item = state.displayPublicaciones[index];
          return _PublicacionCard(
            item: item,
            onEdit: (id, contenido) => _editarPublicacion(id, contenido),
            onDelete: (id, mediaUrl) => _eliminarPublicacion(id, mediaUrl),
          );
        },
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMediaFile == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _isVideo
                    ? Center(
                        child: Icon(
                          Icons.video_library,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                      )
                    : Image.file(
                        _selectedMediaFile!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _limpiarMediaSeleccionada,
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: _subiendoMedia ? null : _seleccionarImagen,
            tooltip: 'Seleccionar imagen',
            color: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: _subiendoMedia ? null : _seleccionarVideo,
            tooltip: 'Seleccionar video',
            color: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TextField(
              controller: _textoController,
              decoration: InputDecoration(
                hintText: "¿Qué quieres compartir?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
              ),
              onSubmitted: (value) => _crearPublicacion(),
              enabled: !_subiendoMedia,
            ),
          ),
          const SizedBox(width: 8),
          _subiendoMedia
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _crearPublicacion,
                ),
        ],
      ),
    );
  }
}

/// Widget para mostrar una publicación individual
class _PublicacionCard extends StatelessWidget {
  final PublicacionConAutor item;
  final Function(String id, String contenido) onEdit;
  final Function(String id, String? mediaUrl) onDelete;

  const _PublicacionCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final publicacion = item.publicacionData;
    final nombreAutor = item.nombreAutor;
    final avatarUrl = item.avatarUrl;
    final nombreRutaCompartida = item.nombreRutaCompartida;
    final idRutaCompartida = item.idRutaCompartida;
    final eventoCompartido = item.eventoCompartidoData;
    final nombreOrganizadorEvento = item.nombreOrganizadorEvento;

    String fechaFormateadaPublicacion = 'Fecha desconocida';
    try {
      fechaFormateadaPublicacion = DateFormat(
        'dd MMM yy, hh:mm a',
        'es_CO',
      ).format(
        publicacion.fecha.toLocal(),
      );
    } catch (e) {
      fechaFormateadaPublicacion = publicacion.fecha.toString();
    }

    final currentUserId = context.read<CommunityBloc>().state.currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con avatar, nombre y fecha
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreAutor ?? "Usuario",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fechaFormateadaPublicacion,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // Menú de opciones (solo si es el autor)
                if (publicacion.usuarioId ==
                    currentUserId)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'editar') {
                        onEdit(
                          publicacion.id,
                          publicacion.contenido ?? '',
                        );
                      } else if (value == 'eliminar') {
                        onDelete(
                          publicacion.id,
                          publicacion.mediaUrl,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Contenido textual de la publicación
            if (publicacion.contenido != null &&
                publicacion.contenido!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(publicacion.contenido!),
              ),

            // Mostrar IMAGEN
            if (publicacion.tipo == 'imagen' && publicacion.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    publicacion.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.broken_image, size: 50, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Mostrar VIDEO
            if (publicacion.tipo == 'video' && publicacion.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _VideoPlayerWidget(videoUrl: publicacion.mediaUrl!),
              ),

            // Mostrar RUTA COMPARTIDA
            if (publicacion.tipo == 'ruta_compartida')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ha compartido la ruta:",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    nombreRutaCompartida ?? "Nombre de ruta no disponible",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text("Ver Ruta en Mapa"),
                    onPressed: () {
                      if (idRutaCompartida != null) {
                        Navigator.pushNamed(
                          context,
                          '/rutas',
                          arguments: RutasScreenArgs(rutaIdParaCargar: idRutaCompartida),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("No se puede abrir la ruta."),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

            // Mostrar EVENTO COMPARTIDO
            if (publicacion.tipo == 'evento_compartido' && eventoCompartido != null)
              _EventoCompartidoWidget(
                eventoCompartido: eventoCompartido,
                nombreOrganizadorEvento: nombreOrganizadorEvento,
                nombreAutor: nombreAutor,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar un evento compartido
class _EventoCompartidoWidget extends StatelessWidget {
  final Event eventoCompartido;
  final String? nombreOrganizadorEvento;
  final String? nombreAutor;

  const _EventoCompartidoWidget({
    required this.eventoCompartido,
    this.nombreOrganizadorEvento,
    this.nombreAutor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eventoCompartido.title.isNotEmpty
                      ? eventoCompartido.title
                      : 'Evento Compartido',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          if (nombreOrganizadorEvento != null &&
              nombreOrganizadorEvento != "Usuario Anónimo" &&
              nombreOrganizadorEvento != nombreAutor)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
              child: Text(
                "Organizado por: $nombreOrganizadorEvento",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            "Fecha: ${DateFormat('dd MMM yy, hh:mm a', 'es_CO').format(eventoCompartido.date)}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          if (eventoCompartido.puntoEncuentro != null &&
              eventoCompartido.puntoEncuentro!.isNotEmpty)
            Text(
              "Lugar: ${eventoCompartido.puntoEncuentro}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (eventoCompartido.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                eventoCompartido.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 10),
          if (eventoCompartido.id.isNotEmpty &&
              eventoCompartido.title != 'Evento no disponible')
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text("Ver Evento"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(eventoCompartido.title.isNotEmpty
                          ? eventoCompartido.title
                          : "Detalles del Evento"),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            if (nombreOrganizadorEvento != null)
                              Text("Organizador: $nombreOrganizadorEvento"),
                            const SizedBox(height: 5),
                            Text(
                              "Fecha: ${DateFormat('dd MMM yy, hh:mm a', 'es_CO').format(eventoCompartido.date)}",
                            ),
                            const SizedBox(height: 5),
                            if (eventoCompartido.puntoEncuentro != null)
                              Text("Lugar: ${eventoCompartido.puntoEncuentro}"),
                            const SizedBox(height: 5),
                            if (eventoCompartido.description.isNotEmpty)
                              Text("Descripción: ${eventoCompartido.description}"),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text("Cerrar"),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (eventoCompartido.title == 'Evento no disponible')
            Text(
              eventoCompartido.description.isNotEmpty
                  ? eventoCompartido.description
                  : "Este evento ya no está disponible.",
              style: TextStyle(
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog para editar una publicación — gestiona su propio TextEditingController
/// para evitar el assertion '_dependents.isEmpty' al disponer el controller
/// mientras la animación de cierre del dialog aún está activa.
class _EditarPublicacionDialog extends StatefulWidget {
  final String contenidoActual;

  const _EditarPublicacionDialog({required this.contenidoActual});

  @override
  State<_EditarPublicacionDialog> createState() => _EditarPublicacionDialogState();
}

class _EditarPublicacionDialogState extends State<_EditarPublicacionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.contenidoActual);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar publicación'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '¿Qué quieres compartir?',
          border: OutlineInputBorder(),
        ),
        maxLines: 5,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Widget para reproducir videos
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
