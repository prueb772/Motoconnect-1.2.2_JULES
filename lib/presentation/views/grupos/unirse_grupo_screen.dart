import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/grupos/unirse_grupo/unirse_grupo_bloc.dart';

/// Pantalla para unirse a un grupo mediante código
///
/// Patrón: MVVM + BLoC
/// - View solo dispara eventos y consume estados
/// - UnirseGrupoBloc maneja la solicitud de unión
class UnirseGrupoScreen extends StatelessWidget {
  const UnirseGrupoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UnirseGrupoBloc(
        grupoRepository: context.read<GrupoRepository>(),
      ),
      child: const _UnirseGrupoScreenBody(),
    );
  }
}

class _UnirseGrupoScreenBody extends StatefulWidget {
  const _UnirseGrupoScreenBody();

  @override
  State<_UnirseGrupoScreenBody> createState() => _UnirseGrupoScreenBodyState();
}

class _UnirseGrupoScreenBodyState extends State<_UnirseGrupoScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UnirseGrupoBloc, UnirseGrupoState>(
      listener: (context, state) {
        if (state.status == UnirseGrupoStatus.success) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Solicitud Enviada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top, color: Colors.orange, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Tu solicitud ha sido enviada.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El líder del grupo debe aprobar tu solicitud. Te notificaremos cuando seas aceptado.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar diálogo
                    Navigator.pop(context, true); // Volver a la lista
                  },
                  child: const Text('ENTENDIDO'),
                ),
              ],
            ),
          );
        } else if (state.status == UnirseGrupoStatus.error && state.errorMessage != null) {
          String errorMessage = 'Error al solicitar unirse';

          final errorStr = state.errorMessage!.toLowerCase();
          if (errorStr.contains('inválido')) {
            errorMessage = 'Código de invitación inválido';
          } else if (errorStr.contains('ya eres miembro')) {
            errorMessage = 'Ya eres miembro de este grupo';
          } else if (errorStr.contains('solicitud pendiente')) {
            errorMessage = 'Ya tienes una solicitud pendiente para este grupo';
          } else if (errorStr.contains('bloqueado')) {
            errorMessage = 'No puedes unirte a este grupo. Contacta al líder.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == UnirseGrupoStatus.loading;

        return Scaffold(
          appBar: AppBar(title: const Text('Unirse a Grupo')),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.vpn_key, size: 80, color: Colors.orangeAccent),
                        const SizedBox(height: 24),
                        Text(
                          'Ingresa el código de invitación',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pide el código al administrador del grupo',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _codigoController,
                          decoration: const InputDecoration(
                            labelText: 'Código de invitación',
                            prefixIcon: Icon(Icons.vpn_key),
                            border: OutlineInputBorder(),
                            hintText: 'Ej: ABC123',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa el código';
                            }
                            if (value.trim().length != 6) {
                              return 'El código debe tener 6 caracteres';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final upperValue = value.toUpperCase();
                            if (value != upperValue) {
                              _codigoController.value = TextEditingValue(
                                text: upperValue,
                                selection: TextSelection.collapsed(
                                  offset: upperValue.length,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              context.read<UnirseGrupoBloc>().add(
                                UnirseGrupoSubmitted(
                                  _codigoController.text.trim().toUpperCase(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Unirse al Grupo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.orange[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info, color: Colors.orange[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Importante',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '• El código debe tener exactamente 6 caracteres',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Solo puedes unirte a grupos activos',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Una vez dentro, podrás compartir tu ubicación',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ],
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
