import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/grupo_ruta_model.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/grupos/editar_grupo/editar_grupo_bloc.dart';

/// Pantalla para editar un grupo existente
///
/// Patrón: MVVM + BLoC
/// - View solo dispara eventos y consume estados
/// - EditarGrupoBloc maneja toda la lógica de negocio
class EditarGrupoScreen extends StatelessWidget {
  final GrupoRutaModel grupo;

  const EditarGrupoScreen({
    super.key,
    required this.grupo,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditarGrupoBloc(
        grupoRepository: context.read<GrupoRepository>(),
      ),
      child: _EditarGrupoScreenBody(grupo: grupo),
    );
  }
}

class _EditarGrupoScreenBody extends StatefulWidget {
  final GrupoRutaModel grupo;

  const _EditarGrupoScreenBody({required this.grupo});

  @override
  State<_EditarGrupoScreenBody> createState() => _EditarGrupoScreenBodyState();
}

class _EditarGrupoScreenBodyState extends State<_EditarGrupoScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _imagenSeleccionada;

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.grupo.nombre;
    _descripcionController.text = widget.grupo.descripcion ?? '';
  }

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
    return BlocConsumer<EditarGrupoBloc, EditarGrupoState>(
      listener: (context, state) {
        if (state.status == EditarGrupoStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else if (state.status == EditarGrupoStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == EditarGrupoStatus.loading;

        return Scaffold(
          appBar: AppBar(title: const Text('Editar Grupo')),
          body: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Guardando cambios...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24, 24, 24,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Foto del grupo
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
                                      : (widget.grupo.fotoUrl != null
                                          ? NetworkImage(widget.grupo.fotoUrl!)
                                          : null) as ImageProvider?,
                                  child: (_imagenSeleccionada == null &&
                                          widget.grupo.fotoUrl == null)
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
                          'Toca para cambiar la foto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),

                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del grupo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.group),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es obligatorio';
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
                          decoration: InputDecoration(
                            labelText: 'Descripción (opcional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.description),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              context.read<EditarGrupoBloc>().add(
                                EditarGrupoSubmitted(
                                  grupoId: widget.grupo.id,
                                  nombre: _nombreController.text.trim(),
                                  descripcion: _descripcionController.text.trim().isNotEmpty
                                      ? _descripcionController.text.trim()
                                      : null,
                                  imagePath: _imagenSeleccionada?.path,
                                  fotoUrlActual: widget.grupo.fotoUrl,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Cambios'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
}
