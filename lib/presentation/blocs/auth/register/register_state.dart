part of 'register_bloc.dart';

/// Estados posibles del proceso de registro
enum RegisterStatus {
  /// Estado inicial
  initial,

  /// Procesando registro
  loading,

  /// Registro exitoso
  success,

  /// Registro fallido
  failure,
}

/// Estado del RegisterBloc
///
/// Contiene todo el estado necesario para la pantalla de registro.
class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.initial,
    this.nombre = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.errorMessage,
    this.registeredNombre,
  });

  /// Estado actual del proceso de registro
  final RegisterStatus status;

  /// Nombre ingresado
  final String nombre;

  /// Email ingresado
  final String email;

  /// Password ingresado
  final String password;

  /// Confirmación de password
  final String confirmPassword;

  /// Visibilidad del password
  final bool isPasswordVisible;

  /// Visibilidad del confirmar password
  final bool isConfirmPasswordVisible;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Nombre del usuario registrado (para el mensaje de éxito)
  final String? registeredNombre;

  /// Crea una copia del estado con los campos modificados
  RegisterState copyWith({
    RegisterStatus? status,
    String? nombre,
    String? email,
    String? password,
    String? confirmPassword,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    String? errorMessage,
    String? registeredNombre,
    bool clearError = false,
  }) {
    return RegisterState(
      status: status ?? this.status,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      registeredNombre: registeredNombre ?? this.registeredNombre,
    );
  }

  @override
  List<Object?> get props => [
        status,
        nombre,
        email,
        password,
        confirmPassword,
        isPasswordVisible,
        isConfirmPasswordVisible,
        errorMessage,
        registeredNombre,
      ];
}
