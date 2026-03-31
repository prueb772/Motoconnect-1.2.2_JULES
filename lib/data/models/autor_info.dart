/// Modelo de información de autor
///
/// Reemplaza Map<String, String?> como retorno de getDatosUsuario
/// en CommunityRepository y el cache de CommunityBloc.
library;

class AutorInfo {
  /// Nombre del autor
  final String? nombre;

  /// URL de la foto de perfil del autor
  final String? fotoPerfilUrl;

  const AutorInfo({
    this.nombre,
    this.fotoPerfilUrl,
  });

  /// Crea una instancia desde JSON (respuesta de Supabase)
  factory AutorInfo.fromJson(Map<String, dynamic> json) {
    return AutorInfo(
      nombre: json['nombre'] as String?,
      fotoPerfilUrl: json['foto_perfil_url'] as String?,
    );
  }
}
