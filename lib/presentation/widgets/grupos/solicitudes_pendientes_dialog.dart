/// Diálogo de Solicitudes Pendientes
///
/// Muestra lista de usuarios que quieren unirse a la sesión
/// Solo visible para el líder
library;

import 'package:flutter/material.dart';
import '../../../data/models/participante_sesion_model.dart';

class SolicitudesPendientesDialog extends StatelessWidget {
  final List<ParticipanteSesionModel> solicitudes;
  final Function(String participanteId) onAprobar;
  final Function(String participanteId) onRechazar;

  const SolicitudesPendientesDialog({
    super.key,
    required this.solicitudes,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_add, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Solicitudes Pendientes (${solicitudes.length})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: solicitudes.isEmpty
          ? const SizedBox(
              height: 100,
              child: Center(
                child: Text('No hay solicitudes pendientes'),
              ),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: solicitudes.length,
                itemBuilder: (context, index) {
                  final solicitud = solicitudes[index];
                  return _buildSolicitudItem(context, solicitud);
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildSolicitudItem(
    BuildContext context,
    ParticipanteSesionModel solicitud,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          backgroundImage: solicitud.fotoPerfilUrl != null
              ? NetworkImage(solicitud.fotoPerfilUrl!)
              : null,
          child: solicitud.fotoPerfilUrl == null
              ? Text(
                  solicitud.nombreMostrar[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: _MarqueeText(
          text: solicitud.nombreMostrar,
        ),
        subtitle: Text(
          _formatFechaSolicitud(solicitud.fechaSolicitud),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón Rechazar
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                _confirmarRechazo(context, solicitud);
              },
            ),
            // Botón Aprobar
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () {
                onAprobar(solicitud.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${solicitud.nombreMostrar} aprobado',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarRechazo(
    BuildContext context,
    ParticipanteSesionModel solicitud,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: Text(
          '¿Seguro que quieres rechazar a ${solicitud.nombreMostrar}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRechazar(solicitud.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${solicitud.nombreMostrar} rechazado',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  String _formatFechaSolicitud(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else {
      return 'Hace ${diferencia.inDays} días';
    }
  }
}

/// Widget de texto con efecto marquee (scroll horizontal) para textos largos
///
/// Si el texto cabe en el ancho disponible, se muestra normal.
/// Si es muy largo, se anima con efecto marquee (scroll horizontal continuo).
class _MarqueeText extends StatefulWidget {
  final String text;

  const _MarqueeText({
    required this.text,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Esperar a que se construya el widget para verificar si necesita scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrollingIfNeeded();
    });
  }

  void _startScrollingIfNeeded() {
    if (!mounted) return;

    // Verificar si el contenido excede el ancho disponible
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _isScrolling = true;
      });
      _animate();
    }
  }

  void _animate() async {
    if (!mounted || !_isScrolling) return;

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted || !_scrollController.hasClients) return;

    // Scroll hacia la derecha
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: widget.text.length * 50),
      curve: Curves.linear,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || !_scrollController.hasClients) return;

    // Volver al inicio
    await _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: widget.text.length * 50),
      curve: Curves.linear,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    // Repetir
    _animate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        maxLines: 1,
      ),
    );
  }
}
