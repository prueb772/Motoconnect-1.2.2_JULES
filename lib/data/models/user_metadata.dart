/// Modelo de metadatos del usuario autenticado
///
/// Reemplaza Map<String, dynamic>? como retorno de getCurrentUserMetadata
/// en ProfileRepository. Contiene campos de metadatos que Supabase Auth
/// proporciona, como nombre y full_name.
library;

class UserMetadata {
  /// Nombre del usuario (de auth metadata)
  final String? nombre;

  /// Nombre completo del usuario (e.g., de Google Sign-In)
  final String? fullName;

  /// Nombre del proveedor de auth (e.g., 'email', 'google')
  final String? name;

  const UserMetadata({
    this.nombre,
    this.fullName,
    this.name,
  });

  /// Crea una instancia desde los metadatos de Supabase Auth
  factory UserMetadata.fromJson(Map<String, dynamic> json) {
    return UserMetadata(
      nombre: json['nombre'] as String?,
      fullName: json['full_name'] as String?,
      name: json['name'] as String?,
    );
  }

  /// Nombre resuelto: intenta nombre, luego fullName, luego name
  String? get resolvedName => nombre ?? fullName ?? name;
}
