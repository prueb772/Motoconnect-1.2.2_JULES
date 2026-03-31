/// Pantalla de Restablecimiento de Contraseña
///
/// Se muestra cuando el usuario llega desde el deep link del correo
/// de recuperación de contraseña.
///
/// Permite al usuario ingresar y confirmar su nueva contraseña.
///
/// Patrón: MVVM + BLoC
/// - Esta es la View (solo UI)
/// - Usa ResetPasswordBloc para toda la lógica de actualización
/// - La View solo dispara eventos y consume estados
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../blocs/auth/reset_password/reset_password_bloc.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ResetPasswordBloc(
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _ResetPasswordScreenBody(),
    );
  }
}

class _ResetPasswordScreenBody extends StatefulWidget {
  const _ResetPasswordScreenBody();

  @override
  State<_ResetPasswordScreenBody> createState() =>
      _ResetPasswordScreenBodyState();
}

class _ResetPasswordScreenBodyState extends State<_ResetPasswordScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
      listener: (context, state) async {
        if (state.status == ResetPasswordStatus.success) {
          // Mostrar diálogo de éxito y navegar al login
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('¡Contraseña Actualizada!'),
              content: const Text(
                'Tu contraseña ha sido actualizada exitosamente. '
                'Ahora puedes iniciar sesión con tu nueva contraseña.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );

          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      },
      builder: (context, state) {
        final isLoading = state.status == ResetPasswordStatus.loading;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB0BEC5), Color(0xFF455A64)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono
                        const Icon(
                          Icons.lock_reset,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 24),

                        // Título
                        const Text(
                          'Nueva Contraseña',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'Ingresa tu nueva contraseña para\nrestablecer el acceso a tu cuenta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (state.errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Text(
                              state.errorMessage!,
                              style:
                                  const TextStyle(color: Colors.redAccent),
                            ),
                          ),

                        // Campo nueva contraseña
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !state.isPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Nueva contraseña',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                state.isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => context
                                  .read<ResetPasswordBloc>()
                                  .add(const ResetPasswordVisibilityToggled()),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) => context
                              .read<ResetPasswordBloc>()
                              .add(ResetPasswordPasswordChanged(value)),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa una contraseña';
                            }
                            if (value.trim().length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo confirmar contraseña
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !state.isConfirmPasswordVisible,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Confirmar contraseña',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                state.isConfirmPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => context
                                  .read<ResetPasswordBloc>()
                                  .add(const ResetPasswordConfirmVisibilityToggled()),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) => context
                              .read<ResetPasswordBloc>()
                              .add(ResetPasswordConfirmPasswordChanged(value)),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Confirma tu contraseña';
                            }
                            if (value.trim() !=
                                _passwordController.text.trim()) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Botón guardar
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      context
                                          .read<ResetPasswordBloc>()
                                          .add(const ResetPasswordSubmitted());
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Guardar Nueva Contraseña',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Volver al login
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (route) => false,
                                  );
                                },
                          child: const Text(
                            'Volver al inicio de sesión',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
