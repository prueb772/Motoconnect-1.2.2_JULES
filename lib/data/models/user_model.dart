/// Modelo de Usuario
///
/// Representa los datos de un usuario en la aplicación
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
library;

class UserModel {
  /// ID único del usuario (UUID de Supabase)
  final String id;

  /// Correo electrónico
  final String email;

  /// Nombre completo
  final String nombre;

  /// Modelo de moto (opcional)
  final String? modeloMoto;

  /// URL de foto de perfil (opcional)
  final String? fotoPerfil;

  /// Apodo del usuario que se muestra en el mapa durante rutas grupales (opcional)
  final String? apodo;

  /// Constructor
  const UserModel({
    required this.id,
    required this.email,
    required this.nombre,
    this.modeloMoto,
    this.fotoPerfil,
    this.apodo,
  });

  /// Crea una instancia desde JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? json['correo'] as String? ?? '',
      nombre: json['nombre'] as String,
      modeloMoto: json['modelo_moto'] as String?,
      fotoPerfil: json['foto_perfil_url'] as String?,
      apodo: json['apodo'] as String?,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'correo': email,
      'nombre': nombre,
      'modelo_moto': modeloMoto,
      'foto_perfil_url': fotoPerfil,
      'apodo': apodo,
    };
  }

  /// Crea una copia con campos modificados
  UserModel copyWith({
    String? id,
    String? email,
    String? nombre,
    String? modeloMoto,
    String? fotoPerfil,
    String? apodo,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      modeloMoto: modeloMoto ?? this.modeloMoto,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      apodo: apodo ?? this.apodo,
    );
  }
}
