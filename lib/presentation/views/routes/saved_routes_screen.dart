/// Pantalla de Rutas Guardadas
///
/// Responsabilidades:
/// - Mostrar lista de rutas guardadas del usuario
/// - Eliminar y compartir rutas
/// - Seleccionar ruta para ver en mapa
///
/// Patrón: MVVM + BLoC
/// - Esta es la View (solo UI)
/// - Usa SavedRoutesBloc para la lógica de presentación
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/ruta_realizada_model.dart';
import '../../../data/repositories/saved_routes_repository.dart';
import '../../blocs/routes/saved_routes/saved_routes_bloc.dart';

class RutasRecomendadasScreen extends StatelessWidget {
  const RutasRecomendadasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SavedRoutesBloc(
        savedRoutesRepository: context.read<SavedRoutesRepository>(),
      )..add(const SavedRoutesLoadRequested()),
      child: const _RutasRecomendadasScreenBody(),
    );
  }
}

class _RutasRecomendadasScreenBody extends StatelessWidget {
  const _RutasRecomendadasScreenBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SavedRoutesBloc, SavedRoutesState>(
      listener: (context, state) {
        // Mostrar mensajes según el estado
        if (state.status == SavedRoutesStatus.deleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruta eliminada correctamente.')),
          );
        }

        if (state.status == SavedRoutesStatus.shared) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruta compartida en la comunidad.')),
          );
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<SavedRoutesBloc>().add(const SavedRoutesErrorCleared());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rutas Guardadas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.status == SavedRoutesStatus.loading
                    ? null
                    : () => context
                        .read<SavedRoutesBloc>()
                        .add(const SavedRoutesRefreshRequested()),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SavedRoutesState state) {
    if (state.status == SavedRoutesStatus.loading ||
        state.status == SavedRoutesStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == SavedRoutesStatus.error && state.routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Error al cargar rutas',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<SavedRoutesBloc>()
                  .add(const SavedRoutesRefreshRequested()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.displayRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No hay rutas guardadas.',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SavedRoutesBloc>().add(const SavedRoutesRefreshRequested());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom + 16),
        itemCount: state.displayRoutes.length,
        itemBuilder: (context, index) {
          final ruta = state.displayRoutes[index];
          return _RutaCard(
            ruta: ruta,
            onTap: () => Navigator.pop(context, ruta),
            onDelete: () => _confirmarEliminar(context, ruta),
            onShare: () => _mostrarDialogoCompartir(context, ruta),
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    RutaRealizadaModel ruta,
  ) async {
    final nombreRuta = ruta.nombreRuta;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la ruta "$nombreRuta"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      context.read<SavedRoutesBloc>().add(
            SavedRouteDeleteRequested(
              routeId: ruta.id,
              routeName: nombreRuta,
            ),
          );
    }
  }

  Future<void> _mostrarDialogoCompartir(
    BuildContext context,
    RutaRealizadaModel ruta,
  ) async {
    final mensajeController = TextEditingController();
    final nombreRuta = ruta.nombreRuta;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Compartir Ruta: $nombreRuta'),
        content: TextField(
          controller: mensajeController,
          decoration: const InputDecoration(
            hintText: 'Añade un mensaje (opcional)...',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      context.read<SavedRoutesBloc>().add(
            SavedRouteShareRequested(
              routeData: ruta,
              message: mensajeController.text.trim(),
            ),
          );
    }

    mensajeController.dispose();
  }
}

/// Widget de tarjeta para mostrar una ruta guardada
class _RutaCard extends StatelessWidget {
  final RutaRealizadaModel ruta;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _RutaCard({
    required this.ruta,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final nombreRuta = ruta.nombreRuta;
    final fecha = ruta.fecha.toIso8601String().split('T').first;
    final descripcion = ruta.descripcionRuta ?? '';
    final tipo = ruta.tipo;
    final esRealizada = tipo == 'realizada';

    final distanciaKm = ruta.distanciaKm;
    final duracionMin = ruta.duracionMinutos;

    String subtitulo = 'Fecha: $fecha';
    if (esRealizada && distanciaKm > 0) {
      subtitulo += ' · ${distanciaKm.toStringAsFixed(1)} km';
      if (duracionMin > 0) {
        subtitulo += ' · $duracionMin min';
      }
    }
    if (descripcion.isNotEmpty) subtitulo += '\n$descripcion';

    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
        leading: Icon(
          esRealizada ? Icons.directions_bike : Icons.bookmark_outline,
          color: esRealizada ? Colors.teal : Colors.blueGrey,
        ),
        title: Row(
          children: [
            Expanded(child: Text(nombreRuta)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: esRealizada
                    ? Colors.teal.withOpacity(0.15)
                    : Colors.blueGrey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                esRealizada ? 'Recorrida' : 'Guardada',
                style: TextStyle(
                  fontSize: 11,
                  color: esRealizada ? Colors.teal[700] : Colors.blueGrey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(subtitulo),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.share_outlined, color: Colors.green[700]),
              tooltip: 'Compartir en comunidad',
              onPressed: onShare,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: 'Eliminar ruta',
              onPressed: onDelete,
            ),
            const Icon(Icons.map_outlined),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
