/// Pantalla Splash - Pantalla de carga inicial
///
/// Responsabilidades:
/// - Mostrar logo de la aplicación
/// - Verificar estado de autenticación
/// - Redirigir a login o home según corresponda
///
/// Patrón: MVVM + BLoC
/// - Esta es la View (solo UI)
/// - Usa AuthBloc para la lógica de autenticación
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth/auth_bloc.dart';
import '../../../core/constants/route_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Dispara el evento de verificación de autenticación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(const AuthStarted());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Navega según el estado de autenticación
        if (state is AuthAuthenticated) {
          Navigator.pushReplacementNamed(context, RouteConstants.home);
        } else if (state is AuthUnauthenticated) {
          Navigator.pushReplacementNamed(context, RouteConstants.login);
        }
      },
      child: Scaffold(
        // Fondo con gradiente
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFB0BEC5), // Gris claro
                Color(0xFF455A64), // Gris oscuro
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo de la aplicación
                Image.asset(
                  'assets/images/logo.png',
                  height: 150,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback si no se encuentra el logo
                    return const Icon(
                      Icons.motorcycle,
                      size: 100,
                      color: Colors.white,
                    );
                  },
                ),
                const SizedBox(height: 24),

                /* // Nombre de la app
                const Text(
                  'MotoConnect',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),*/

                // Indicador de carga
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),

                // Texto de carga
                const Text(
                  'Cargando...',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
