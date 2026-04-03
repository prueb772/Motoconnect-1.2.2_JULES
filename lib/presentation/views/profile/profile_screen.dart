/// Pantalla de Perfil
///
/// Responsabilidades:
/// - Mostrar y editar información del usuario
/// - Manejar foto de perfil (delegando al BLoC)
/// - Cerrar sesión
///
/// Patrón: MVVM + BLoC
/// - Esta es la View (solo UI)
/// - Usa ProfileBloc para toda la lógica de datos del perfil
/// - La View solo dispara eventos y consume estados
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/models/ruta_realizada_model.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/auth/auth/auth_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        profileRepository: context.read<ProfileRepository>(),
      )..add(const ProfileLoadRequested()),
      child: const _PerfilScreenBody(),
    );
  }
}

class _PerfilScreenBody extends StatefulWidget {
  const _PerfilScreenBody();

  @override
  State<_PerfilScreenBody> createState() => _PerfilScreenBodyState();
}

class _PerfilScreenBodyState extends State<_PerfilScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _modeloMotoController = TextEditingController();
  final _apodoController = TextEditingController();

  String? _appVersion;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (Build ${info.buildNumber})';
        });
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _modeloMotoController.dispose();
    _apodoController.dispose();
    super.dispose();
  }

  void _syncControllersWithState(ProfileState state) {
    if (_nombreController.text != state.nombre) {
      _nombreController.text = state.nombre;
    }
    if (_correoController.text != state.correo) {
      _correoController.text = state.correo;
    }
    if (_modeloMotoController.text != state.modeloMoto) {
      _modeloMotoController.text = state.modeloMoto;
    }
    if (_apodoController.text != state.apodo) {
      _apodoController.text = state.apodo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        // Sincronizar controllers cuando se cargan datos
        if (state.status == ProfileStatus.loaded ||
            state.status == ProfileStatus.saved) {
          _syncControllersWithState(state);
        }

        // Mostrar mensajes de éxito/error
        if (state.status == ProfileStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil guardado con éxito.')),
          );
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<ProfileBloc>().add(const ProfileErrorCleared());
        }

      },
      builder: (context, state) {
        final isLoading = state.status == ProfileStatus.loading ||
            state.status == ProfileStatus.saving;

        return Scaffold(
          appBar: AppBar(title: const Text('Mi Perfil')),
          body: isLoading && state.nombre.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16, 16, 16,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    children: [
                        _buildAvatarSection(state),
                        const SizedBox(height: 24),
                        _buildNombreField(),
                        const SizedBox(height: 16),
                        _buildApodoField(),
                        const SizedBox(height: 16),
                        _buildCorreoField(),
                        const SizedBox(height: 16),
                        _buildModeloMotoField(),
                        const SizedBox(height: 32),
                        _buildGuardarButton(context, state),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildRutasSection(context),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildAparienciaSection(context),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        if (_appVersion != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Versión $_appVersion',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        _buildCerrarSesionButton(context, state),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  Widget _buildAvatarSection(ProfileState state) {
    final isSaving = state.status == ProfileStatus.saving;
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage:
                state.avatarUrl != null ? NetworkImage(state.avatarUrl!) : null,
            child: state.avatarUrl == null
                ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant)
                : null,
          ),
          if (isSaving)
            Positioned.fill(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.black54,
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onInverseSurface),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: isSaving ? null : () => _mostrarOpcionesFoto(state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNombreField() {
    return TextFormField(
      controller: _nombreController,
      decoration: const InputDecoration(
        labelText: 'Nombre',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_outline),
      ),
      onChanged: (value) {
        context.read<ProfileBloc>().add(ProfileNameChanged(value));
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor, ingresa tu nombre';
        }
        return null;
      },
    );
  }

  Widget _buildApodoField() {
    return TextFormField(
      controller: _apodoController,
      decoration: const InputDecoration(
        labelText: 'Apodo',
        hintText: 'Se mostrará en rutas grupales',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.badge),
      ),
      maxLength: 20,
      onChanged: (value) {
        context.read<ProfileBloc>().add(ProfileNicknameChanged(value));
      },
    );
  }

  Widget _buildCorreoField() {
    return TextFormField(
      controller: _correoController,
      decoration: const InputDecoration(
        labelText: 'Correo Electrónico',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email_outlined),
      ),
      readOnly: true,
    );
  }

  Widget _buildModeloMotoField() {
    return TextFormField(
      controller: _modeloMotoController,
      decoration: const InputDecoration(
        labelText: 'Modelo de Moto',
        hintText: 'Ej: Yamaha MT-07',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.motorcycle_outlined),
      ),
      onChanged: (value) {
        context.read<ProfileBloc>().add(ProfileMotoModelChanged(value));
      },
    );
  }

  Widget _buildGuardarButton(BuildContext context, ProfileState state) {
    final isSaving = state.status == ProfileStatus.saving;
    return ElevatedButton.icon(
      icon: isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_alt_outlined),
      label: Text(isSaving ? 'Guardando...' : 'Guardar Cambios'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
      onPressed: isSaving
          ? null
          : () {
              if (_formKey.currentState!.validate()) {
                context.read<ProfileBloc>().add(const ProfileSaveRequested());
              }
            },
    );
  }

  Widget _buildRutasSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis Rutas Guardadas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('Ver mis rutas'),
          onPressed: () async {
            final resultado = await Navigator.pushNamed(
              context,
              '/rutas-recomendadas',
            );
            if (resultado != null && resultado is RutaRealizadaModel) {
              if (mounted) {
                Navigator.pushNamed(context, '/rutas', arguments: resultado);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildAparienciaSection(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apariencia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistema'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Oscuro'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (Set<ThemeMode> selection) {
                context.read<ThemeCubit>().setThemeMode(selection.first);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCerrarSesionButton(BuildContext context, ProfileState state) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Cerrar Sesión'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
      onPressed: state.status == ProfileStatus.loading ? null : _cerrarSesion,
    );
  }

  // ========================================
  // MÉTODOS DE IMAGEN — Solo UI, delega al BLoC
  // ========================================

  void _mostrarOpcionesFoto(ProfileState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _tomarFoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarDeGaleria();
              },
            ),
            if (state.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarFoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (photo != null && mounted) {
        context
            .read<ProfileBloc>()
            .add(ProfileAvatarUploadRequested(File(photo.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (image != null && mounted) {
        context
            .read<ProfileBloc>()
            .add(ProfileAvatarUploadRequested(File(image.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _eliminarFoto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto de perfil'),
        content: const Text(
            '¿Estás seguro de que deseas eliminar tu foto de perfil?'),
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

    if (mounted) {
      context.read<ProfileBloc>().add(const ProfileAvatarDeleteRequested());
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
