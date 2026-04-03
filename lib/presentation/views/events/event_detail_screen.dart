import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/event_participant_model.dart';
import '../../../data/repositories/event_repository.dart';
import '../../blocs/events/event_detail/event_detail_bloc.dart';
import 'create_event_screen.dart';
import '../routes/rutas_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EventDetailBloc(
        eventRepository: context.read<EventRepository>(),
        eventId: eventId,
      )
        ..add(const EventDetailLoadRequested())
        ..add(const EventDetailParticipantsLoadRequested()),
      child: const _EventDetailView(),
    );
  }
}

class _EventDetailView extends StatelessWidget {
  const _EventDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventDetailBloc, EventDetailState>(
      listener: (context, state) {
        if (state.status == EventDetailStatus.deleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento eliminado')),
          );
          Navigator.pop(context);
        }

        if (state.status == EventDetailStatus.attendanceUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado actualizado')),
          );
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<EventDetailBloc>().add(const EventDetailErrorCleared());
        }
      },
      builder: (context, state) {
        if (state.status == EventDetailStatus.loading && state.event == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.event == null) {
          return const Scaffold(
            body: Center(child: Text('Evento no encontrado')),
          );
        }

        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              context
                  .read<EventDetailBloc>()
                  .add(const EventDetailRefreshRequested());
            },
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, state),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.event!.grupoNombre != null) ...[
                          _buildGrupoChip(context, state),
                          const SizedBox(height: 16),
                        ],
                        _buildEventInfo(context, state),
                        const SizedBox(height: 24),
                        _buildDescription(context, state),
                        const SizedBox(height: 24),
                        _buildLocationInfo(context, state),
                        const SizedBox(height: 24),
                        _buildAttendanceButtons(context, state),
                        const SizedBox(height: 24),
                        _buildParticipants(context, state),
                        SizedBox(height: bottomPadding + 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, EventDetailState state) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: [
        if (state.isCreator) ...[
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateEventScreen(event: state.event),
                ),
              );

              if (result == true) {
                if (context.mounted) {
                  context
                      .read<EventDetailBloc>()
                      .add(const EventDetailLoadRequested());
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          state.event!.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black45,
              ),
            ],
          ),
        ),
        background: state.event!.fotoUrl != null
            ? Image.network(
                state.event!.fotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Icon(
                      Icons.event,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.event, size: 80, color: Colors.white),
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Estás seguro de eliminar este evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<EventDetailBloc>().add(const EventDetailDeleteRequested());
    }
  }

  Widget _buildGrupoChip(BuildContext context, EventDetailState state) {
    return Chip(
      avatar: const Icon(Icons.group, size: 18),
      label: Text(state.event!.grupoNombre!),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
    );
  }

  Widget _buildEventInfo(BuildContext context, EventDetailState state) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(
              context,
              Icons.calendar_today,
              'Fecha',
              DateFormat('dd/MM/yyyy').format(state.event!.date),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context,
              Icons.access_time,
              'Hora',
              DateFormat('HH:mm').format(state.event!.date),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context,
              Icons.people,
              'Participantes',
              '${state.participants.length} registrados',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, EventDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descripción',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          state.event!.description.isEmpty
              ? 'Sin descripción disponible'
              : state.event!.description,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(BuildContext context, EventDetailState state) {
    final event = state.event!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicaciones',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (event.puntoEncuentro != null &&
            event.puntoEncuentro!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildLocationCard(
            context,
            icon: Icons.flag,
            title: 'Punto de Encuentro',
            location: event.puntoEncuentro,
            latitude: event.puntoEncuentroLat,
            longitude: event.puntoEncuentroLng,
            onVerRuta: event.puntoEncuentroLat != null &&
                    event.puntoEncuentroLng != null
                ? () => _openRouteToLocation(
                      context,
                      event.puntoEncuentroLat!,
                      event.puntoEncuentroLng!,
                      event.puntoEncuentro,
                    )
                : null,
          ),
        ],
        if (event.destino != null && event.destino!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildLocationCard(
            context,
            icon: Icons.location_on,
            title: 'Destino',
            location: event.destino!,
            latitude: event.destinoLat,
            longitude: event.destinoLng,
            onVerRuta:
                event.destinoLat != null && event.destinoLng != null
                    ? () => _openRouteToLocation(
                          context,
                          event.destinoLat!,
                          event.destinoLng!,
                          event.destino!,
                        )
                    : null,
          ),
        ],
      ],
    );
  }

  void _openRouteToLocation(
      BuildContext context, double lat, double lng, String? name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RutasScreen(
          destinoInicial: LatLng(lat, lng),
          nombreDestino: name,
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String? location,
    required double? latitude,
    required double? longitude,
    required VoidCallback? onVerRuta,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (latitude != null && longitude != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (onVerRuta != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onVerRuta,
                  icon: const Icon(Icons.directions, size: 20),
                  label: const Text('Ver Ruta'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButtons(
      BuildContext context, EventDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu estado de asistencia',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAttendanceButton(
                context,
                state,
                EstadoAsistencia.confirmado,
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAttendanceButton(
                context,
                state,
                EstadoAsistencia.posible,
                Icons.help_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAttendanceButton(
                context,
                state,
                EstadoAsistencia.noAsiste,
                Icons.cancel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceButton(
    BuildContext context,
    EventDetailState state,
    EstadoAsistencia estado,
    IconData icon,
  ) {
    final isSelected = state.userAttendanceStatus == estado;
    final color = Color(
        int.parse(estado.colorHex.substring(1), radix: 16) + 0xFF000000);

    return ElevatedButton(
      onPressed: () => context
          .read<EventDetailBloc>()
          .add(EventDetailAttendanceUpdateRequested(estado)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? color
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            estado.displayText,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipants(BuildContext context, EventDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participantes (${state.participants.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (state.isLoadingParticipants)
          const Center(child: CircularProgressIndicator())
        else if (state.participants.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'Sé el primero en unirte',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ..._buildParticipantsByStatus(context, state),
      ],
    );
  }

  List<Widget> _buildParticipantsByStatus(
      BuildContext context, EventDetailState state) {
    final confirmados = state.participants
        .where((p) => p.estado == EstadoAsistencia.confirmado)
        .toList();
    final posibles = state.participants
        .where((p) => p.estado == EstadoAsistencia.posible)
        .toList();
    final noAsisten = state.participants
        .where((p) => p.estado == EstadoAsistencia.noAsiste)
        .toList();

    return [
      if (confirmados.isNotEmpty) ...[
        _buildStatusHeader(context, EstadoAsistencia.confirmado,
            confirmados.length),
        ...confirmados.map((p) => _buildParticipantTile(context, p)),
        const SizedBox(height: 16),
      ],
      if (posibles.isNotEmpty) ...[
        _buildStatusHeader(
            context, EstadoAsistencia.posible, posibles.length),
        ...posibles.map((p) => _buildParticipantTile(context, p)),
        const SizedBox(height: 16),
      ],
      if (noAsisten.isNotEmpty) ...[
        _buildStatusHeader(
            context, EstadoAsistencia.noAsiste, noAsisten.length),
        ...noAsisten.map((p) => _buildParticipantTile(context, p)),
      ],
    ];
  }

  Widget _buildStatusHeader(
      BuildContext context, EstadoAsistencia estado, int count) {
    final color = Color(
        int.parse(estado.colorHex.substring(1), radix: 16) + 0xFF000000);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            '${estado.displayText} ($count)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
      BuildContext context, EventParticipantModel participant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          backgroundImage: participant.usuario?.fotoPerfil != null
              ? NetworkImage(participant.usuario!.fotoPerfil!)
              : null,
          child: participant.usuario?.fotoPerfil == null
              ? Text(
                  participant.displayName.isNotEmpty
                      ? participant.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          participant.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          participant.grupoDisplay,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Color(int.parse(
                      participant.estado.colorHex.substring(1),
                      radix: 16,
                    ) +
                    0xFF000000)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            participant.estado.displayText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(int.parse(
                    participant.estado.colorHex.substring(1),
                    radix: 16,
                  ) +
                  0xFF000000),
            ),
          ),
        ),
      ),
    );
  }
}
