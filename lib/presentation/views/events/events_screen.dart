/// Pantalla de Eventos
///
/// Responsabilidades:
/// - Mostrar lista de eventos próximos
/// - Navegar a detalle y creación de eventos
///
/// Patrón: MVVM + BLoC
/// - Esta es la View (solo UI)
/// - Usa EventsBloc para la lógica de presentación
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../data/models/event_model.dart';
import '../../../data/repositories/event_repository.dart';
import '../../blocs/events/events_bloc.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

/// La Vista (View) para la pantalla de eventos.
///
/// Provee EventsBloc localmente.
class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EventsBloc(
        eventRepository: context.read<EventRepository>(),
      )..add(const EventsLoadRequested()),
      child: const _EventosScreenBody(),
    );
  }
}

/// El cuerpo de la vista de eventos.
class _EventosScreenBody extends StatefulWidget {
  const _EventosScreenBody();

  @override
  State<_EventosScreenBody> createState() => _EventosScreenBodyState();
}

class _EventosScreenBodyState extends State<_EventosScreenBody> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximos Eventos'),
        actions: [
          BlocBuilder<EventsBloc, EventsState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.status == EventsStatus.loading
                    ? null
                    : () => context
                        .read<EventsBloc>()
                        .add(const EventsRefreshRequested()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar eventos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<EventsBloc, EventsState>(
              builder: (context, state) {
                return _buildBody(context, state);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEventScreen(),
            ),
          );
          if (result == true && context.mounted) {
            context.read<EventsBloc>().add(const EventsRefreshRequested());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EventsState state) {
    if (state.status == EventsStatus.loading ||
        state.status == EventsStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == EventsStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<EventsBloc>()
                  .add(const EventsRefreshRequested()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final filteredEvents = _searchQuery.isEmpty
        ? state.events
        : state.events.where((e) {
            final q = _searchQuery.toLowerCase();
            return e.title.toLowerCase().contains(q) ||
                (e.puntoEncuentro?.toLowerCase().contains(q) ?? false) ||
                (e.destino?.toLowerCase().contains(q) ?? false) ||
                (e.description.toLowerCase().contains(q));
          }).toList();

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No hay eventos próximos'
                  : 'Sin resultados para "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<EventsBloc>().add(const EventsRefreshRequested());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding + 80),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return _EventCard(
            event: event,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: event.id),
                ),
              );
              // Recargar eventos al volver por si hubo cambios
              if (context.mounted) {
                context.read<EventsBloc>().add(const EventsRefreshRequested());
              }
            },
          );
        },
      ),
    );
  }
}

/// Widget de tarjeta para mostrar un evento
class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del evento (si existe)
            if (event.fotoUrl != null)
              Image.network(
                event.fotoUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child:
                        Icon(Icons.event, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  );
                },
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.event, size: 60, color: Colors.white70),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chip de grupo (si existe)
                  if (event.grupoNombre != null) ...[
                    Chip(
                      avatar: const Icon(Icons.group, size: 16),
                      label: Text(
                        event.grupoNombre!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Título del evento
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Fecha y hora
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy - HH:mm').format(event.date),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Ubicación
                  Row(
                    children: [
                      const Icon(Icons.flag, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.puntoEncuentro ?? event.destino ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Destino si existe
                  if (event.destino != null && event.destino!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.destino!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Descripción
                  if (event.description.isNotEmpty)
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
