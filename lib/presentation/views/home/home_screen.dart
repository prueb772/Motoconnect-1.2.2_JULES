import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_event.dart';
import '../../blocs/home/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(),
      child: BlocListener<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeNavigationRequested) {
            Navigator.pushNamed(context, state.route);
          }
        },
        child: _HomeScreenView(),
      ),
    );
  }
}

class _HomeScreenView extends StatelessWidget {
  const _HomeScreenView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MotoConnect',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        /*actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // Menú lateral si lo deseas
            },
          ),
        ],*/
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              '¿Qué deseas explorar?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                children: [
                  _buildProfileTile(
                    context,
                    'Rutas',
                    'assets/images/icon_rutas.png',
                    route: '/rutas',
                  ),
                  _buildProfileTile(
                    context,
                    'Talleres',
                    'assets/images/icon_talleres.png',
                    route: '/talleres',
                  ),
                  _buildProfileTile(
                    context,
                    'Eventos',
                    'assets/images/icon_eventos.png',
                    route: '/eventos',
                  ),
                  _buildProfileTile(
                    context,
                    'Comunidad',
                    'assets/images/icon_comunidad.png',
                    route: '/comunidad',
                  ),
                  _buildProfileTile(
                    context,
                    'Grupos',
                    'assets/images/icon_grupos.png',
                    route: '/grupos',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<HomeBloc>().add(HomeProfileSelected()),
        tooltip: 'Perfil',
        backgroundColor: Colors.orangeAccent, // O el color que prefieras
        child: const Icon(Icons.person, color: Colors.black),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, // Posición
    );
  }

  Widget _buildProfileTile(
    BuildContext context,
    String title,
    String imagePath, {
    required String route,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: () => context.read<HomeBloc>().add(HomeRouteSelected(route)),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        size: 64,
                        color: Colors.orangeAccent,
                      )
                    : Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
