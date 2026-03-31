import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/grupo_ruta_model.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/events/create_event/create_event_bloc.dart';
import '../routes/rutas_screen.dart';
import '../routes/map_picker_screen.dart';
import '../../../data/models/map_picker_result.dart';

/// Pantalla para crear o editar un evento
class CreateEventScreen extends StatelessWidget {
  /// Evento a editar (null para crear nuevo)
  final Event? event;

  const CreateEventScreen({super.key, this.event});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = CreateEventBloc(
          eventRepository: context.read<EventRepository>(),
          grupoRepository: context.read<GrupoRepository>(),
        )..add(const CreateEventGruposLoadRequested());

        // Si estamos editando, cargar los grupos asociados al evento
        if (event != null) {
          bloc.add(CreateEventGruposForEventLoadRequested(event!.id));
        }

        return bloc;
      },
      child: _CreateEventView(event: event),
    );
  }
}

class _CreateEventView extends StatefulWidget {
  final Event? event;

  const _CreateEventView({this.event});

  @override
  State<_CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<_CreateEventView> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _labelPuntoEncuentroController = TextEditingController();
  final _labelDestinoController = TextEditingController();

  // Coordenadas y direcciones de las ubicaciones (estado UI local)
  double? _puntoEncuentroLat;
  double? _puntoEncuentroLng;
  String? _puntoEncuentroDireccion;

  double? _destinoLat;
  double? _destinoLng;
  String? _destinoDireccion;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _selectedImage;
  String? _imageUrl;
  List<GrupoRutaModel> _selectedGrupos = [];
  bool _isPublic = true;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _initializeFromEvent();
    }
  }

  void _initializeFromEvent() {
    final event = widget.event!;
    _tituloController.text = event.title;
    _descripcionController.text = event.description;

    if (event.puntoEncuentro != null && event.puntoEncuentro!.isNotEmpty) {
      _puntoEncuentroDireccion = event.puntoEncuentro;
      _puntoEncuentroLat = event.puntoEncuentroLat;
      _puntoEncuentroLng = event.puntoEncuentroLng;
    }

    if (event.destino != null && event.destino!.isNotEmpty) {
      _destinoDireccion = event.destino!;
      _destinoLat = event.destinoLat;
      _destinoLng = event.destinoLng;
    }

    _selectedDate = event.date;
    _selectedTime = TimeOfDay.fromDateTime(event.date);
    _imageUrl = event.fotoUrl;
    _isPublic = event.isPublic;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona fecha y hora')),
      );
      return;
    }

    if (_destinoDireccion == null || _destinoDireccion!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona el destino')),
      );
      return;
    }

    if (!_isPublic && _selectedGrupos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los eventos privados requieren un grupo asociado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Combinar fecha y hora en local, luego convertir a UTC
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    ).toUtc();

    // Validar que no sea en el pasado
    if (dateTime.isBefore(DateTime.now().toUtc())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora del evento debe ser en el futuro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Punto de encuentro es opcional
    final String? puntoEncuentroTexto = _puntoEncuentroDireccion != null
        ? (_labelPuntoEncuentroController.text.trim().isNotEmpty
            ? '${_labelPuntoEncuentroController.text.trim()} ($_puntoEncuentroDireccion)'
            : _puntoEncuentroDireccion)
        : null;

    // Destino es requerido
    final String destinoTexto = _labelDestinoController.text.trim().isNotEmpty
        ? '${_labelDestinoController.text.trim()} ($_destinoDireccion)'
        : _destinoDireccion!;

    // Disparar evento al BLoC
    context.read<CreateEventBloc>().add(CreateEventSaveRequested(
          title: _tituloController.text.trim(),
          description: _descripcionController.text.trim(),
          dateTime: dateTime,
          destinoTexto: destinoTexto,
          isPublic: _isPublic,
          gruposIds: _selectedGrupos.map((g) => g.id).toList(),
          existingEventId: widget.event?.id,
          existingImageUrl: _imageUrl,
          imageFile: _selectedImage,
          puntoEncuentroTexto: puntoEncuentroTexto,
          puntoEncuentroLat: _puntoEncuentroLat,
          puntoEncuentroLng: _puntoEncuentroLng,
          destinoLat: _destinoLat,
          destinoLng: _destinoLng,
        ));
  }

  Future<void> _seleccionarUbicacion(bool esPuntoEncuentro) async {
    final resultado = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialPosition: esPuntoEncuentro
              ? (_puntoEncuentroLat != null
                  ? LatLng(_puntoEncuentroLat!, _puntoEncuentroLng!)
                  : null)
              : (_destinoLat != null
                  ? LatLng(_destinoLat!, _destinoLng!)
                  : null),
        ),
      ),
    );

    if (resultado != null && mounted) {
      setState(() {
        if (esPuntoEncuentro) {
          _puntoEncuentroLat = resultado.latlng.latitude;
          _puntoEncuentroLng = resultado.latlng.longitude;
          _puntoEncuentroDireccion = resultado.address;
        } else {
          _destinoLat = resultado.latlng.latitude;
          _destinoLng = resultado.latlng.longitude;
          _destinoDireccion = resultado.address;
        }
      });
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _labelPuntoEncuentroController.dispose();
    _labelDestinoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return BlocConsumer<CreateEventBloc, CreateEventState>(
      listener: (context, state) {
        // Sincronizar grupos seleccionados cuando se cargan desde BLoC
        if (state.selectedGrupoIds.isNotEmpty && _selectedGrupos.isEmpty) {
          final selected = state.grupos
              .where((g) => state.selectedGrupoIds.contains(g.id))
              .toList();
          if (selected.isNotEmpty) {
            setState(() {
              _selectedGrupos = selected;
            });
          }
        }

        if (state.status == CreateEventStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.event == null
                    ? 'Evento creado exitosamente'
                    : 'Evento actualizado exitosamente',
              ),
            ),
          );
          Navigator.of(context).pop(true);
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context
              .read<CreateEventBloc>()
              .add(const CreateEventErrorCleared());
        }
      },
      builder: (context, state) {
        final isSaving = state.status == CreateEventStatus.saving;

        return Scaffold(
          appBar: AppBar(
            title: Text(
                widget.event == null ? 'Crear Evento' : 'Editar Evento'),
          ),
          body: isSaving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: bottomPadding + 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildImageSection(),
                        const SizedBox(height: 24),

                        // Título
                        TextFormField(
                          controller: _tituloController,
                          decoration: const InputDecoration(
                            labelText: 'Título del evento *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El título es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Descripción
                        TextFormField(
                          controller: _descripcionController,
                          decoration: const InputDecoration(
                            labelText: 'Descripción *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'La descripción es requerida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Punto de Encuentro
                        _buildUbicacionSelector(
                          titulo: 'Punto de Encuentro (Opcional)',
                          icono: Icons.flag,
                          direccion: _puntoEncuentroDireccion,
                          latitud: _puntoEncuentroLat,
                          longitud: _puntoEncuentroLng,
                          labelController: _labelPuntoEncuentroController,
                          onSeleccionar: () =>
                              _seleccionarUbicacion(true),
                          onVerRuta: _puntoEncuentroLat != null &&
                                  _puntoEncuentroLng != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RutasScreen(
                                        destinoInicial: LatLng(
                                          _puntoEncuentroLat!,
                                          _puntoEncuentroLng!,
                                        ),
                                        nombreDestino:
                                            _puntoEncuentroDireccion,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        const SizedBox(height: 24),

                        // Destino
                        _buildUbicacionSelector(
                          titulo: 'Destino *',
                          icono: Icons.location_on,
                          direccion: _destinoDireccion,
                          latitud: _destinoLat,
                          longitud: _destinoLng,
                          labelController: _labelDestinoController,
                          onSeleccionar: () =>
                              _seleccionarUbicacion(false),
                          onVerRuta:
                              _destinoLat != null && _destinoLng != null
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RutasScreen(
                                            destinoInicial: LatLng(
                                              _destinoLat!,
                                              _destinoLng!,
                                            ),
                                            nombreDestino:
                                                _destinoDireccion,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                        ),
                        const SizedBox(height: 24),

                        // Fecha
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _selectedDate == null
                                  ? 'Seleccionar fecha'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Hora
                        InkWell(
                          onTap: _selectTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _selectedTime == null
                                  ? 'Seleccionar hora'
                                  : _selectedTime!.format(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selector de grupos
                        if (state.isLoadingGrupos)
                          const Center(child: CircularProgressIndicator())
                        else if (state.grupos.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Asociar con Grupos',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: state.grupos.map((grupo) {
                                  final seleccionado =
                                      _selectedGrupos.contains(grupo);
                                  return FilterChip(
                                    label: Text(grupo.nombre),
                                    selected: seleccionado,
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
                                          _selectedGrupos.add(grupo);
                                        } else {
                                          _selectedGrupos.remove(grupo);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // Privacidad
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Privacidad del Evento',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _isPublic ? 'Público' : 'Privado',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  _isPublic
                                      ? 'Todos los usuarios pueden ver y unirse'
                                      : 'Solo miembros del grupo pueden ver y unirse',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                value: _isPublic,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isPublic = value;
                                  });
                                },
                                activeTrackColor:
                                    Colors.blue.withValues(alpha: 0.5),
                                activeColor: Colors.blue,
                              ),
                              if (!_isPublic && _selectedGrupos.isEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: Colors.orange[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Los eventos privados requieren un grupo asociado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botón guardar
                        ElevatedButton(
                          onPressed: isSaving ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            widget.event == null
                                ? 'Crear Evento'
                                : 'Guardar Cambios',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildUbicacionSelector({
    required String titulo,
    required IconData icono,
    required String? direccion,
    required double? latitud,
    required double? longitud,
    required TextEditingController labelController,
    required VoidCallback onSeleccionar,
    required VoidCallback? onVerRuta,
  }) {
    final tieneUbicacion = direccion != null && direccion.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (!tieneUbicacion)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSeleccionar,
              icon: Icon(icono),
              label: const Text('Seleccionar en Mapa'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      labelText: 'Nombre personalizado (opcional)',
                      hintText: 'Ej: Casa de Juan, Aeropuerto...',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(icono),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          direccion,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (latitud != null && longitud != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${latitud.toStringAsFixed(4)}, Lng: ${longitud.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onSeleccionar,
                          icon: const Icon(Icons.edit_location),
                          label: const Text('Cambiar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onVerRuta,
                          icon: const Icon(Icons.directions),
                          label: const Text('Ver Ruta'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                )
              : _imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                              child: Icon(Icons.error, size: 48));
                        },
                      ),
                    )
                  : Center(
                      child: Icon(Icons.image,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Seleccionar foto'),
        ),
      ],
    );
  }
}
