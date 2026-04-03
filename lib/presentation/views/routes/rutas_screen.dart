import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/models/ruta_realizada_model.dart';
import '../../../data/models/rutas_screen_args.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../blocs/routes/routes_bloc.dart';
import '../navigation/navigation_screen.dart';

class RutasScreen extends StatelessWidget {
  final RutaRealizadaModel? rutaInicial;
  final LatLng? destinoInicial;
  final String? nombreDestino;
  final bool modoSeleccion;

  const RutasScreen({
    super.key,
    this.rutaInicial,
    this.destinoInicial,
    this.nombreDestino,
    this.modoSeleccion = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RoutesBloc(
        googleApiKey: "AIzaSyDTFLe8BeQLca2P5ES7vXetX3icv7jiFEE",
        routesRepository: context.read<RoutesRepository>(),
      )..add(const RoutesInitialized()),
      child: _RutasView(
        rutaInicial: rutaInicial,
        destinoInicial: destinoInicial,
        nombreDestino: nombreDestino,
        modoSeleccion: modoSeleccion,
      ),
    );
  }
}

class _RutasView extends StatefulWidget {
  final RutaRealizadaModel? rutaInicial;
  final LatLng? destinoInicial;
  final String? nombreDestino;
  final bool modoSeleccion;

  const _RutasView({
    this.rutaInicial,
    this.destinoInicial,
    this.nombreDestino,
    this.modoSeleccion = false,
  });

  @override
  State<_RutasView> createState() => _RutasViewState();
}

class _RutasViewState extends State<_RutasView> {
  final LatLng _defaultPosition = const LatLng(7.116816, -73.105240);
  final TextEditingController _searchController = TextEditingController();

  // Variables para modo selección (mantenidas en View - UI específica)
  LatLng? _ubicacionSeleccionada;
  String? _direccionSeleccionada;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments != null && arguments is RutasScreenArgs) {
      final String rutaId = arguments.rutaIdParaCargar;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<RoutesBloc>().add(RoutesLoadByIdRequested(rutaId));
        }
      });
    } else if (arguments != null && arguments is RutaRealizadaModel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<RoutesBloc>().add(RoutesSavedRouteLoadRequested(arguments));
        }
      });
    } else if (widget.rutaInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<RoutesBloc>().add(RoutesSavedRouteLoadRequested(widget.rutaInicial!));
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      if (mounted) {
        context.read<RoutesBloc>().add(const RoutesUserLocationRequested());

        // Si hay un destino inicial, establecerlo inmediatamente.
        // El BLoC calculará la ruta en cuanto la ubicación esté disponible.
        if (widget.destinoInicial != null) {
          context.read<RoutesBloc>().add(RoutesDestinationSet(
            destination: widget.destinoInicial!,
            destinationName: widget.nombreDestino,
          ));
          if (widget.nombreDestino != null) {
            _searchController.text = widget.nombreDestino!;
          }
        }
      }
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  void _limpiarBusqueda() {
    _searchController.clear();
    context.read<RoutesBloc>().add(const RoutesSearchCleared());
    FocusScope.of(context).unfocus();
  }

  Future<Map<String, String>?> _mostrarDialogoNombreRuta(
    BuildContext context,
  ) async {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Guardar Ruta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Nombre*",
                  hintText: "Dale un nombre a tu ruta",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: "Descripción (Opcional)",
                  hintText: "Añade detalles si quieres...",
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.pop(dialogContext);
              },
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () {
                final nombre = nombreController.text.trim();
                final descripcion = descripcionController.text.trim();
                if (nombre.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'nombre': nombre,
                    'descripcion': descripcion,
                  });
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text("El nombre no puede estar vacío."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _guardarRutaActual() async {
    final state = context.read<RoutesBloc>().state;

    if (!state.tieneRutaActiva) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay ruta activa para guardar.")),
      );
      return;
    }

    final Map<String, String>? rutaInfo = await _mostrarDialogoNombreRuta(context);

    if (rutaInfo != null && mounted) {
      context.read<RoutesBloc>().add(RoutesSaveRequested(
        routeName: rutaInfo['nombre']!,
        routeDescription: rutaInfo['descripcion'],
      ));
    }
  }

  void _iniciarNavegacion(RoutesState state) {
    if (state.searchedMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay destino seleccionado.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          destination: state.searchedMarker!.position,
          destinationName: _searchController.text.isNotEmpty
              ? _searchController.text
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoutesBloc, RoutesState>(
      listener: (context, state) {
        // Mostrar mensajes según el estado
        if (state.status == RoutesStatus.routeSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ruta guardada correctamente.")),
          );
        } else if (state.status == RoutesStatus.routeLoaded) {
          _mostrarSnackBarRutaCargada(state);
        } else if (state.status == RoutesStatus.routeCalculated &&
            state.selectedPlaceName != null) {
          _mostrarSnackBarRutaTrazada(state.selectedPlaceName!);
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<RoutesBloc>().add(const RoutesErrorCleared());
        }

        // Actualizar controller de búsqueda cuando se selecciona un lugar
        if (state.selectedPlaceName != null &&
            _searchController.text != state.selectedPlaceName) {
          _searchController.text = state.selectedPlaceName!;
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text("Mapa de Rutas")),
          body: SafeArea(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _defaultPosition,
                    zoom: 13,
                  ),
                  onMapCreated: (controller) {
                    context.read<RoutesBloc>().add(RoutesMapCreated(controller));
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: state.markers,
                  polylines: state.polylines,
                  padding: const EdgeInsets.only(
                    top: 80,
                    bottom: 100,
                  ),
                ),
                _buildSearchBar(context, state),
                _buildSavedRoutesButton(context),
                if (state.tieneRutaActiva) _buildSaveRouteButton(context),
                if (state.tieneRutaActiva && state.searchedMarker != null)
                  _buildNavigationButton(context, state),
                if (state.status == RoutesStatus.loadingLocation ||
                    state.status == RoutesStatus.calculatingRoute ||
                    state.status == RoutesStatus.savingRoute ||
                    state.status == RoutesStatus.loadingRoute)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          floatingActionButton: widget.modoSeleccion && _ubicacionSeleccionada != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pop(context, {
                      'latitud': _ubicacionSeleccionada!.latitude,
                      'longitud': _ubicacionSeleccionada!.longitude,
                      'direccion': _direccionSeleccionada ?? '',
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar Ubicación'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, RoutesState state) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _limpiarBusqueda,
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    onChanged: (value) {
                      context.read<RoutesBloc>().add(RoutesSearchQueryChanged(value));
                    },
                    decoration: InputDecoration(
                      hintText: "Buscar ubicación...",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.predictions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: state.predictions.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onSurface),
                    title: Text(
                      state.predictions[index].description ?? "",
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      if (widget.modoSeleccion) {
                        _handleSelectionMode(state.predictions[index]);
                      } else {
                        context.read<RoutesBloc>().add(
                          RoutesPredictionSelected(state.predictions[index]),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _handleSelectionMode(prediction) async {
    // En modo selección, solo guardar ubicación sin trazar ruta
    // Esta lógica se mantiene en la Vista porque es específica del modo de selección
    final bloc = context.read<RoutesBloc>();
    bloc.add(RoutesPredictionSelected(prediction));

    // Esperar a que se actualice el estado
    await Future.delayed(const Duration(milliseconds: 300));
    final state = bloc.state;

    if (state.searchedMarker != null) {
      setState(() {
        _ubicacionSeleccionada = state.searchedMarker!.position;
        _direccionSeleccionada = state.selectedPlaceName;
      });
    }
  }

  Widget _buildSavedRoutesButton(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.route),
        label: const Text("Rutas guardadas"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        onPressed: () async {
          final resultado = await Navigator.pushNamed(
            context,
            '/rutas-recomendadas',
          );
          if (resultado != null && resultado is RutaRealizadaModel && mounted) {
            context.read<RoutesBloc>().add(RoutesSavedRouteLoadRequested(resultado));
          }
        },
      ),
    );
  }

  Widget _buildSaveRouteButton(BuildContext context) {
    return Positioned(
      bottom: 70,
      left: 20,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save),
        label: const Text("Guardar ruta"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        onPressed: _guardarRutaActual,
      ),
    );
  }

  Widget _buildNavigationButton(BuildContext context, RoutesState state) {
    return Positioned(
      bottom: 120,
      left: 20,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.navigation),
        label: const Text("Iniciar Navegación"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _iniciarNavegacion(state),
      ),
    );
  }

  void _mostrarSnackBarRutaCargada(RoutesState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[700],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.route, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ruta Trazada Hacia ${state.selectedPlaceName ?? 'destino'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarSnackBarRutaTrazada(String nombreDestino) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[700],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ruta trazada hacia $nombreDestino',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
