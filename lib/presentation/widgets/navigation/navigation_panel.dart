/// Panel de Navegación Turn-by-Turn - Estilo Google Maps
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/navigation/navigation_bloc.dart';
import '../../../data/models/navigation_session.dart';

class NavigationPanel extends StatelessWidget {
  final Future<void> Function()? onCenterLocation;
  final bool isCameraFollowing;

  const NavigationPanel({
    super.key,
    this.onCenterLocation,
    this.isCameraFollowing = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
        if (state.currentStep == null) return const SizedBox.shrink();

        return Stack(
          children: [
            _buildTopPanel(context, state),
            _buildBottomPanel(context, state),
          ],
        );
      },
    );
  }

  Widget _buildTopPanel(BuildContext context, NavigationState state) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 80,
      child: Card(
        color: Colors.teal[700],
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instrucción actual
              Row(
                children: [
                  Icon(state.currentStep!.maneuverIcon,
                      size: 32, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.currentStep!.displayInstruction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Phase 4: Distancia al próximo giro (en tiempo real)
              if (state.distanceToNextStepMeters != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(width: 44), // Alineado con el texto
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'en ${_formatDistance(state.distanceToNextStepMeters!)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Siguiente paso
              if (state.nextStep != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(state.nextStep!.maneuverIcon,
                        size: 20, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Luego ${state.nextStep!.displayInstruction}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, NavigationState state) {
    final session = state.currentSession;
    if (session == null) return const SizedBox.shrink();

    final etaAmPm = _formatEtaWithAmPm(session);
    // Mostrar el botón "Ya llegué" cuando el usuario está a ≤ 150 m del
    // destino (último paso). Es el escape hatch para edificios y complejos
    // donde la auto-detección puede no dispararse de inmediato.
    final nearDestination = state.distanceToDestinationMeters != null &&
        state.distanceToDestinationMeters! <= 150;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Botón "Ya llegué" ────────────────────────────────────────
            // Aparece cuando el usuario está a ≤ 150 m del destino.
            // Permite al usuario confirmar la llegada sin esperar
            // a que la detección automática se dispare (útil en
            // edificios, centros comerciales, entradas con GPS impreciso).
            if (nearDestination) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<NavigationBloc>().add(
                          const NavigationEndRequested(completed: true),
                        );
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    'Ya llegué  •  ${_formatDistance(state.distanceToDestinationMeters!)} al destino',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                // Botón opciones de viaje
                GestureDetector(
                  onTap: () => _showTripOptionsDialog(context),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[500]!, width: 2),
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ),

                const SizedBox(width: 20),

                // Tiempo + distancia restante
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        session.remainingDurationText,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF93),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.remainingDistanceText}  •  $etaAmPm',
                        style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),

                // Botón centrar / seguir
                if (onCenterLocation != null)
                  GestureDetector(
                    onTap: onCenterLocation,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCameraFollowing
                            ? Colors.teal[700]
                            : Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCameraFollowing
                            ? Icons.navigation
                            : Icons.my_location,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatEtaWithAmPm(NavigationSession session) {
    final eta = session.estimatedArrivalTime;
    final hour = eta.hour;
    final minute = eta.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'p.m.' : 'a.m.';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _showTripOptionsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: const Text(
          'Opciones de viaje',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TripOptionTile(
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              title: 'Finalizar viaje',
              subtitle: 'Ver resumen de la ruta recorrida',
              onTap: () {
                Navigator.pop(dialogContext);
                context.read<NavigationBloc>().add(
                      const NavigationEndRequested(completed: true),
                    );
              },
            ),
            Divider(color: Colors.white.withOpacity(0.12), height: 1),
            _TripOptionTile(
              icon: Icons.cancel_outlined,
              iconColor: Colors.redAccent,
              title: 'Cancelar viaje',
              subtitle: 'Salir de la navegación sin guardar',
              onTap: () {
                Navigator.pop(dialogContext);
                context.read<NavigationBloc>().add(
                      const NavigationEndRequested(completed: false),
                    );
              },
            ),
            Divider(color: Colors.white.withOpacity(0.12), height: 1),
            _TripOptionTile(
              icon: Icons.play_circle_outline,
              iconColor: const Color(0xFF4CAF93),
              title: 'Continuar viaje',
              subtitle: 'Cerrar este menú y seguir navegando',
              onTap: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TripOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}
