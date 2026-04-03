part of 'profile_bloc.dart';

/// Estados posibles del perfil
enum ProfileStatus {
  /// Estado inicial
  initial,

  /// Cargando datos
  loading,

  /// Datos cargados correctamente
  loaded,

  /// Guardando cambios
  saving,

  /// Cambios guardados exitosamente
  saved,

  /// Error
  error,
}

/// Estado del ProfileBloc
///
/// Representa el estado de la pantalla de Perfil.
class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.userId,
    this.nombre = '',
    this.correo = '',
    this.modeloMoto = '',
    this.apodo = '',
    this.avatarUrl,
    this.errorMessage,
  });

  /// Estado actual
  final ProfileStatus status;

  /// ID del usuario
  final String? userId;

  /// Nombre del usuario
  final String nombre;

  /// Correo del usuario
  final String correo;

  /// Modelo de moto
  final String modeloMoto;

  /// Apodo del usuario
  final String apodo;

  /// URL de la foto de perfil
  final String? avatarUrl;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Crea una copia del estado con los campos modificados
  ProfileState copyWith({
    ProfileStatus? status,
    String? userId,
    String? nombre,
    String? correo,
    String? modeloMoto,
    String? apodo,
    String? avatarUrl,
    String? errorMessage,
    bool clearError = false,
    bool clearAvatarUrl = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      modeloMoto: modeloMoto ?? this.modeloMoto,
      apodo: apodo ?? this.apodo,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        userId,
        nombre,
        correo,
        modeloMoto,
        apodo,
        avatarUrl,
        errorMessage,
      ];
}
