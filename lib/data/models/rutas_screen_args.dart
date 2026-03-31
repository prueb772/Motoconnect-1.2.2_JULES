/// DTO para argumentos de navegación hacia RutasScreen
///
/// Reemplaza el uso de Map<String, dynamic> como argumento
/// de navegación entre pantallas.
///
/// Ejemplo de uso:
/// ```dart
/// Navigator.pushNamed(
///   context,
///   '/rutas',
///   arguments: RutasScreenArgs(rutaIdParaCargar: 'abc123'),
/// );
/// ```
class RutasScreenArgs {
  /// ID de la ruta a cargar automáticamente al abrir la pantalla
  final String rutaIdParaCargar;

  const RutasScreenArgs({required this.rutaIdParaCargar});
}
