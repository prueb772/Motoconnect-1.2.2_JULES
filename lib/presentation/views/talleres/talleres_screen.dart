import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/taller_model.dart';
import '../../../data/models/map_picker_result.dart';
import '../../../data/repositories/taller_repository.dart';
import '../../blocs/talleres/talleres_bloc.dart';
import '../routes/map_picker_screen.dart';
import '../../../data/models/routes/map_picker_args.dart';
import '../routes/rutas_screen.dart';

class TalleresScreen extends StatelessWidget {
  const TalleresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TalleresBloc(
        tallerRepository: context.read<TallerRepository>(),
      )..add(const TalleresLoadRequested()),
      child: const _TalleresView(),
    );
  }
}

class _TalleresView extends StatelessWidget {
  const _TalleresView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TalleresBloc, TalleresState>(
      listener: (context, state) {
        // Mostrar SnackBars según el estado
        if (state.status == TalleresStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Taller guardado con éxito.")),
          );
        } else if (state.status == TalleresStatus.deleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Taller eliminado.")),
          );
        } else if (state.status == TalleresStatus.shared) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Taller compartido en la comunidad!")),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<TalleresBloc>().add(const TalleresErrorCleared());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Talleres Disponibles"),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<TalleresBloc>().add(const TalleresRefreshRequested());
                },
                tooltip: 'Recargar Talleres',
              ),
            ],
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _mostrarDialogoTaller(context),
            label: const Text("Agregar Taller"),
            icon: const Icon(Icons.add),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TalleresState state) {
    if (state.status == TalleresStatus.loading ||
        state.status == TalleresStatus.saving ||
        state.status == TalleresStatus.processing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == TalleresStatus.error && state.displayTalleres.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.errorMessage ?? 'Error desconocido',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.read<TalleresBloc>().add(const TalleresLoadRequested());
                },
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      );
    }

    if (state.displayTalleres.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "No hay talleres registrados.",
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              "¡Sé el primero en agregar uno!",
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TalleresBloc>().add(const TalleresRefreshRequested());
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 80),
        itemCount: state.displayTalleres.length,
        itemBuilder: (context, index) {
          final tallerConCreador = state.displayTalleres[index];
          return _TallerCard(
            tallerConCreador: tallerConCreador,
            onEdit: () => _mostrarDialogoTaller(
              context,
              tallerExistente: tallerConCreador.tallerData,
            ),
            onDelete: () => _confirmarEliminar(
              context,
              tallerConCreador.tallerData.id,
              tallerConCreador.tallerData.nombre,
            ),
            onShare: () => _compartirTaller(context, tallerConCreador.tallerData),
            onOpenMap: () => _abrirEnMapa(context, tallerConCreador.tallerData),
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoTaller(
    BuildContext context, {
    TallerModel? tallerExistente,
  }) async {
    final bool modoEdicion = tallerExistente != null;
    final String tituloDialogo =
        modoEdicion ? 'Editar Taller' : 'Crear Nuevo Taller';

    final TextEditingController nombreController = TextEditingController(
      text: modoEdicion ? tallerExistente.nombre : '',
    );
    final TextEditingController direccionTextoManualController =
        TextEditingController(
          text: modoEdicion ? tallerExistente.direccion ?? '' : '',
        );
    final TextEditingController telefonoController = TextEditingController(
      text: modoEdicion ? tallerExistente.telefono ?? '' : '',
    );
    final TextEditingController horarioController = TextEditingController(
      text: modoEdicion ? tallerExistente.horario ?? '' : '',
    );

    final formKeyDialog = GlobalKey<FormState>();

    LatLng? selectedLatLng;
    String? selectedAddressString;

    if (modoEdicion) {
      if (tallerExistente.latitud != null &&
          tallerExistente.longitud != null) {
        selectedLatLng = LatLng(
          tallerExistente.latitud!,
          tallerExistente.longitud!,
        );
      }
      selectedAddressString = tallerExistente.direccion;
      if (selectedAddressString != null) {
        direccionTextoManualController.text = selectedAddressString;
      }
    }

    final datosTaller = await showDialog<TallerModel>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setDialogState) {
            return AlertDialog(
              title: Text(tituloDialogo),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: nombreController,
                        autofocus: !modoEdicion,
                        decoration: const InputDecoration(
                          labelText: "Nombre del Taller*",
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'El nombre es obligatorio'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Ubicación del Taller*",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedAddressString ??
                                    "No se ha seleccionado ubicación",
                                style: TextStyle(
                                  color:
                                      selectedAddressString == null
                                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                          : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.location_on_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      if (selectedLatLng != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Lat: ${selectedLatLng!.latitude.toStringAsFixed(5)}, Lng: ${selectedLatLng!.longitude.toStringAsFixed(5)}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          selectedLatLng == null
                              ? "Seleccionar en Mapa"
                              : "Cambiar Ubicación",
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        onPressed: () async {
                          final MapPickerResult? result =
                              await Navigator.pushNamed(
                                context,
                                '/map-picker',
                                arguments: MapPickerArgs(
                                  initialPosition: selectedLatLng,
                                  initialSearchQuery:
                                      selectedAddressString ??
                                      direccionTextoManualController.text,
                                ),
                              ) as MapPickerResult?;

                          if (result != null) {
                            setDialogState(() {
                              selectedLatLng = result.latlng;
                              selectedAddressString = result.address;
                              direccionTextoManualController.text =
                                  selectedAddressString!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "O ingresa la dirección manualmente:",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextFormField(
                        controller: direccionTextoManualController,
                        decoration: const InputDecoration(
                          labelText: "Dirección (texto manual)",
                        ),
                        onChanged: (value) {
                          if (selectedAddressString != value ||
                              selectedLatLng != null) {
                            setDialogState(() {
                              selectedLatLng = null;
                              selectedAddressString = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: telefonoController,
                        decoration: const InputDecoration(
                          labelText: "Teléfono",
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: horarioController,
                        decoration: const InputDecoration(
                          labelText: "Horario (Ej: Lun-Vie 9am-6pm)",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  child: Text(modoEdicion ? 'Guardar Cambios' : 'Crear Taller'),
                  onPressed: () {
                    if (formKeyDialog.currentState!.validate()) {
                      final direccionFinal =
                          selectedAddressString ??
                          direccionTextoManualController.text.trim();

                      if (direccionFinal.isEmpty && selectedLatLng == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Por favor, selecciona o ingresa una dirección para el taller.",
                            ),
                          ),
                        );
                        return;
                      }

                      final tallerModel = TallerModel(
                        id: modoEdicion ? tallerExistente.id : '',
                        nombre: nombreController.text.trim(),
                        direccion: direccionFinal.isEmpty ? null : direccionFinal,
                        telefono: telefonoController.text.trim().isEmpty
                            ? null
                            : telefonoController.text.trim(),
                        horario: horarioController.text.trim().isEmpty
                            ? null
                            : horarioController.text.trim(),
                        latitud: selectedLatLng?.latitude,
                        longitud: selectedLatLng?.longitude,
                        creadoPor: modoEdicion ? tallerExistente.creadoPor : '',
                        createdAt: modoEdicion ? tallerExistente.createdAt : DateTime.now(),
                      );

                      Navigator.pop(dialogContext, tallerModel);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (datosTaller != null && context.mounted) {
      final bloc = context.read<TalleresBloc>();
      if (modoEdicion) {
        bloc.add(TallerUpdateRequested(
          tallerId: datosTaller.id,
          tallerData: datosTaller,
        ));
      } else {
        bloc.add(TallerCreateRequested(datosTaller));
      }
    }
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    String tallerId,
    String nombreTaller,
  ) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text("Confirmar Eliminación"),
            content: Text(
              "¿Seguro que quieres eliminar el taller '$nombreTaller'?",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Eliminar"),
              ),
            ],
          ),
    );

    if (confirmar == true && context.mounted) {
      context.read<TalleresBloc>().add(TallerDeleteRequested(tallerId));
    }
  }

  Future<void> _compartirTaller(
    BuildContext context,
    TallerModel tallerData,
  ) async {
    final TextEditingController mensajeController = TextEditingController();

    final bool? confirmarCompartir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Compartir Taller: ${tallerData.nombre}"),
          content: TextField(
            controller: mensajeController,
            decoration: const InputDecoration(
              hintText: "Añade un mensaje (opcional)...",
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Compartir"),
            ),
          ],
        );
      },
    );

    if (confirmarCompartir == true && context.mounted) {
      context.read<TalleresBloc>().add(TallerShareRequested(
        tallerData: tallerData,
        message: mensajeController.text.trim(),
      ));
    }
  }

  void _abrirEnMapa(BuildContext context, TallerModel taller) {
    final lat = taller.latitud;
    final lon = taller.longitud;

    if (lat != null && lon != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RutasScreen(
            destinoInicial: LatLng(lat, lon),
            nombreDestino: taller.nombre,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay coordenadas disponibles para este taller',
          ),
        ),
      );
    }
  }
}

/// Widget para mostrar un taller individual
class _TallerCard extends StatelessWidget {
  final TallerConCreador tallerConCreador;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onOpenMap;

  const _TallerCard({
    required this.tallerConCreador,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final taller = tallerConCreador.tallerData;
    final nombreCreador = tallerConCreador.nombreCreador;
    final currentUserUid = context.read<TalleresBloc>().state.currentUserId;
    final esCreador =
        (currentUserUid != null && taller.creadoPor == currentUserUid);
    final bool estaLogueado = currentUserUid != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.handyman_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taller.nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      if (nombreCreador != null && nombreCreador != 'N/A')
                        Text(
                          "Por: $nombreCreador",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (estaLogueado)
                      IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        tooltip: 'Compartir este taller',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: onShare,
                      ),
                    if (esCreador)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        tooltip: "Más opciones",
                        onSelected: (value) {
                          if (value == 'editar') {
                            onEdit();
                          } else if (value == 'eliminar') {
                            onDelete();
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'editar',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Editar'),
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'eliminar',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18, thickness: 0.5),
            if (taller.direccion != null && taller.direccion!.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      taller.direccion!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.map_outlined,
                      color: Colors.blueAccent[700],
                      size: 22,
                    ),
                    tooltip: 'Ver en mapa',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onOpenMap,
                  ),
                ],
              ),
            if (taller.telefono != null && taller.telefono!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        taller.telefono!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (taller.horario != null && taller.horario!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.access_time_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        taller.horario!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
