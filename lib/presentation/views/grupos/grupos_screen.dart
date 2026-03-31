import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/grupo_ruta_model.dart';
import '../../../data/repositories/grupo_repository.dart';
import '../../blocs/grupos/grupos/grupos_bloc.dart';
import 'crear_grupo_screen.dart';
import 'unirse_grupo_screen.dart';
import 'detalle_grupo_screen.dart';

/// Pantalla de lista de grupos
///
/// Patrón: MVVM + BLoC
/// - View solo dispara eventos y consume estados
/// - GruposBloc maneja la carga de la lista
class GruposScreen extends StatelessWidget {
  const GruposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GruposBloc(
        grupoRepository: context.read<GrupoRepository>(),
      )..add(const GruposLoadRequested()),
      child: const _GruposScreenBody(),
    );
  }
}

class _GruposScreenBody extends StatelessWidget {
  const _GruposScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<GruposBloc>().add(const GruposLoadRequested()),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: BlocBuilder<GruposBloc, GruposState>(
        builder: (context, state) {
          switch (state.status) {
            case GruposStatus.initial:
            case GruposStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case GruposStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Error al cargar grupos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<GruposBloc>().add(const GruposLoadRequested()),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );

            case GruposStatus.loaded:
              if (state.grupos.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildGruposList(context, state.grupos);
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'unirse',
            onPressed: () => _unirseAGrupo(context),
            tooltip: 'Unirse a grupo',
            child: const Icon(Icons.vpn_key),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'crear',
            onPressed: () => _crearGrupo(context),
            tooltip: 'Crear grupo',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 100,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes grupos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Crea un grupo o únete a uno existente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _crearGrupo(context),
                icon: const Icon(Icons.add),
                label: const Text('Crear grupo'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _unirseAGrupo(context),
                icon: const Icon(Icons.vpn_key),
                label: const Text('Unirse con código'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGruposList(BuildContext context, List<GrupoRutaModel> grupos) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<GruposBloc>().add(const GruposLoadRequested());
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 96),
        itemCount: grupos.length,
        itemBuilder: (context, index) {
          final grupo = grupos[index];
          return _buildGrupoCard(context, grupo);
        },
      ),
    );
  }

  Widget _buildGrupoCard(BuildContext context, GrupoRutaModel grupo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          backgroundImage: grupo.fotoUrl != null
              ? NetworkImage(grupo.fotoUrl!)
              : null,
          child: grupo.fotoUrl == null
              ? const Icon(Icons.groups, color: Colors.white)
              : null,
        ),
        title: Text(
          grupo.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (grupo.descripcion != null && grupo.descripcion!.isNotEmpty)
              Text(grupo.descripcion!),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.vpn_key, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  grupo.codigoInvitacion,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: grupo.codigoInvitacion));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Código ${grupo.codigoInvitacion} copiado al portapapeles'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _abrirDetalleGrupo(context, grupo),
      ),
    );
  }

  Future<void> _crearGrupo(BuildContext context) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CrearGrupoScreen()),
    );
    if (resultado == true && context.mounted) {
      context.read<GruposBloc>().add(const GruposLoadRequested());
    }
  }

  Future<void> _unirseAGrupo(BuildContext context) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const UnirseGrupoScreen()),
    );
    if (resultado == true && context.mounted) {
      context.read<GruposBloc>().add(const GruposLoadRequested());
    }
  }

  void _abrirDetalleGrupo(BuildContext context, GrupoRutaModel grupo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleGrupoScreen(grupo: grupo),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<GruposBloc>().add(const GruposLoadRequested());
      }
    });
  }
}
