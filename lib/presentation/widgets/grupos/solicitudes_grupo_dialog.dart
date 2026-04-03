import 'dart:async';

import 'package:flutter/material.dart';
import '../../../data/models/solicitud_grupo_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/grupo_repository.dart';

/// Dialog para gestionar solicitudes pendientes de un grupo
///
/// Patrón: MVVM + BLoC
/// - Usa su propia instancia de GrupoRepository (inyectada en composition root)
/// - Gestiona stream de solicitudes internamente
/// - No usa setState para lógica de negocio; solo para indicadores UI locales
class SolicitudesGrupoDialog extends StatefulWidget {
  final String grupoId;
  final String grupoNombre;

  const SolicitudesGrupoDialog({
    super.key,
    required this.grupoId,
    required this.grupoNombre,
  });

  @override
  State<SolicitudesGrupoDialog> createState() => _SolicitudesGrupoDialogState();
}

class _SolicitudesGrupoDialogState extends State<SolicitudesGrupoDialog> {
  List<SolicitudGrupoModel> _solicitudes = [];
  bool _isLoading = true;
  final Set<String> _procesando = {};
  StreamSubscription<List<SolicitudGrupoModel>>? _streamSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streamSubscription == null) {
      _iniciarStream();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _iniciarStream() {
    setState(() {
      _isLoading = true;
    });

    final grupoRepository = context.read<GrupoRepository>();
    _streamSubscription = grupoRepository
        .streamSolicitudesGrupo(widget.grupoId)
        .listen(
      (solicitudes) {
        if (mounted) {
          setState(() {
            _solicitudes = solicitudes;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar solicitudes: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _aprobarSolicitud(SolicitudGrupoModel solicitud) async {
    setState(() {
      _procesando.add(solicitud.id);
    });

    final grupoRepository = context.read<GrupoRepository>();
    try {
      await grupoRepository.aprobarSolicitudGrupo(solicitud.id);

      setState(() {
        _solicitudes.removeWhere((s) => s.id == solicitud.id);
        _procesando.remove(solicitud.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${solicitud.nombreMostrar} ha sido aprobado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _procesando.remove(solicitud.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rechazarSolicitud(SolicitudGrupoModel solicitud) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: Text(
          '¿Estás seguro de rechazar la solicitud de ${solicitud.nombreMostrar}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('RECHAZAR'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    setState(() {
      _procesando.add(solicitud.id);
    });

    final grupoRepository = context.read<GrupoRepository>();
    try {
      await grupoRepository.rechazarSolicitudGrupo(solicitud.id);

      setState(() {
        _solicitudes.removeWhere((s) => s.id == solicitud.id);
        _procesando.remove(solicitud.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitud de ${solicitud.nombreMostrar} rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _procesando.remove(solicitud.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solicitudes Pendientes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.grupoNombre,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _solicitudes.isEmpty
                      ? _buildEmptyState()
                      : _buildSolicitudesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes pendientes',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolicitudesList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      itemCount: _solicitudes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final solicitud = _solicitudes[index];
        final estaProcesando = _procesando.contains(solicitud.id);

        return _buildSolicitudCard(solicitud, estaProcesando);
      },
    );
  }

  Widget _buildSolicitudCard(SolicitudGrupoModel solicitud, bool estaProcesando) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Avatar + Info
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: solicitud.fotoPerfilUrl != null
                      ? NetworkImage(solicitud.fotoPerfilUrl!)
                      : null,
                  child: solicitud.fotoPerfilUrl == null
                      ? Text(
                          solicitud.nombreMostrar.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre con chip ex-miembro
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              solicitud.nombreMostrar,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (solicitud.fueBloqueadoAntes) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                'Ex',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Fecha
                      Text(
                        'Solicitó ${_formatFecha(solicitud.fechaSolicitud)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Fila inferior: Botones alineados a la derecha
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (estaProcesando)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  // Botón rechazar
                  TextButton.icon(
                    onPressed: () => _rechazarSolicitud(solicitud),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rechazar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón aprobar
                  FilledButton.icon(
                    onPressed: () => _aprobarSolicitud(solicitud),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprobar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 0) {
      return 'hace ${diferencia.inDays} días';
    } else if (diferencia.inHours > 0) {
      return 'hace ${diferencia.inHours} horas';
    } else if (diferencia.inMinutes > 0) {
      return 'hace ${diferencia.inMinutes} min';
    } else {
      return 'ahora';
    }
  }
}
