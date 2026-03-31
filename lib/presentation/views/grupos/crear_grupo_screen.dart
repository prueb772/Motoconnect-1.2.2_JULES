import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/grupos/crear_grupo/crear_grupo_bloc.dart';

/// Pantalla para crear un nuevo grupo
///
/// Patrón: MVVM + BLoC
/// - View solo dispara eventos y consume estados
/// - CrearGrupoBloc maneja toda la lógica de negocio
class CrearGrupoScreen extends StatelessWidget {
  const CrearGrupoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrearGrupoBloc(
        grupoRepository: context.read<GrupoRepository>(),
      ),
      child: const _CrearGrupoScreenBody(),
    );
  }
}

class _CrearGrupoScreenBody extends StatefulWidget {
  const _CrearGrupoScreenBody();

  @override
  State<_CrearGrupoScreenBody> createState() => _CrearGrupoScreenBodyState();
}

class _CrearGrupoScreenBodyState extends State<_CrearGrupoScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _imagenSeleccionada;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imagenSeleccionada = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CrearGrupoBloc, CrearGrupoState>(
      listener: (context, state) {
        if (state.status == CrearGrupoStatus.success && state.grupoCreado != null) {
          final grupo = state.grupoCreado!;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('¡Grupo creado!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu código de invitación es:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      grupo.codigoInvitacion,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comparte este código con tus amigos para que se unan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar diálogo
                    Navigator.pop(context, true); // Volver a la lista
                  },
                  child: const Text('ACEPTAR'),
                ),
              ],
            ),
          );
        } else if (state.status == CrearGrupoStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear grupo: ${state.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == CrearGrupoStatus.loading;

        return Scaffold(
          appBar: AppBar(title: const Text('Crear Grupo')),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: _seleccionarImagen,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    backgroundImage: _imagenSeleccionada != null
                                        ? FileImage(_imagenSeleccionada!)
                                        : null,
                                    child: _imagenSeleccionada == null
                                        ? Icon(
                                            Icons.group,
                                            size: 50,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toca para agregar foto (opcional)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Crea un grupo para compartir rutas',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Invita a tus amigos y compartan su ubicación en tiempo real',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del grupo *',
                              prefixIcon: Icon(Icons.label),
                              border: OutlineInputBorder(),
                              hintText: 'Ej: Riders del Norte',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa un nombre';
                              }
                              if (value.trim().length < 3) {
                                return 'El nombre debe tener al menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descripcionController,
                            decoration: const InputDecoration(
                              labelText: 'Descripción (opcional)',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                              hintText: 'Describe el propósito del grupo',
                            ),
                            maxLines: 3,
                            maxLength: 200,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                context.read<CrearGrupoBloc>().add(
                                  CrearGrupoSubmitted(
                                    nombre: _nombreController.text.trim(),
                                    descripcion: _descripcionController.text.trim().isEmpty
                                        ? null
                                        : _descripcionController.text.trim(),
                                    imagePath: _imagenSeleccionada?.path,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Crear Grupo'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.orangeAccent),
                                      SizedBox(width: 8),
                                      Text(
                                        '¿Qué puedes hacer?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoItem('• Compartir ubicación en tiempo real'),
                                  _buildInfoItem('• Ver la ubicación de todos los miembros'),
                                  _buildInfoItem('• Planificar rutas grupales'),
                                  _buildInfoItem('• Invitar miembros con un código'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(text),
    );
  }
}
