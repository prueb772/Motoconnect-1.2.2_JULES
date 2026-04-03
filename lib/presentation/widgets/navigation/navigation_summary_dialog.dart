/// Widget de Resumen de Fin de Ruta
///
/// Bottom Sheet que se muestra cuando el usuario llega al destino
/// Muestra:
/// - Tiempo total en ruta
/// - Distancia total recorrida
/// - Botón para cerrar (volver a pantalla anterior)
/// - Botón para guardar la ruta recorrida
library;

import 'package:flutter/material.dart';
import '../../../data/models/navigation_session.dart';

class NavigationSummaryBottomSheet extends StatelessWidget {
  final NavigationSession session;

  /// Distancia real recorrida en metros (incluye todos los desvíos).
  /// Proviene de NavigationState.realizedDistanceMeters, no de session.totalDistanceMeters.
  final double realizedDistanceMeters;

  final VoidCallback onClose;
  final VoidCallback onSave;

  const NavigationSummaryBottomSheet({
    super.key,
    required this.session,
    required this.realizedDistanceMeters,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de arrastre
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // Icono de check grande
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 50,
            ),
          ),

          const SizedBox(height: 16),

          // Título principal
          Text(
            '¡Has llegado a tu destino!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtítulo
          Text(
            'Fin de ruta',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          // Cards de métricas
          Row(
            children: [
              // Card de tiempo
              Expanded(
                child: _MetricCard(
                  icon: Icons.timer,
                  label: 'Tiempo en ruta',
                  value: _formatElapsedTime(session.elapsedTime),
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 16),

              // Card de distancia
              Expanded(
                child: _MetricCard(
                  icon: Icons.route,
                  label: 'Distancia recorrida',
                  value: _formatDistance(realizedDistanceMeters),
                  color: Colors.teal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Botones
          Row(
            children: [
              // Botón Cerrar
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cerrar ruta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Botón Guardar
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Guardar ruta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Formatea el tiempo transcurrido
  String _formatElapsedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Formatea la distancia en kilómetros
  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    if (km >= 1.0) {
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${meters.toInt()} m';
    }
  }
}

/// Widget de card de métrica
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icono
          Icon(
            icon,
            color: color,
            size: 32,
          ),

          const SizedBox(height: 8),

          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Valor
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
