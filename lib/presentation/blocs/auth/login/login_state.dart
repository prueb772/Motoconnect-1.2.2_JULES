part of 'login_bloc.dart';

/// Estados posibles del proceso de login
enum LoginStatus {
  /// Estado inicial
  initial,

  /// Procesando login
  loading,

  /// Login exitoso
  success,

  /// Login fallido
  failure,
}

/// Estado del LoginBloc
///
/// Contiene todo el estado necesario para la pantalla de login.
class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.errorMessage,
    this.resetPasswordMessage,
  });

  /// Estado actual del proceso de login
  final LoginStatus status;

  /// Email ingresado
  final String email;

  /// Password ingresado
  final String password;

  /// Visibilidad del password
  final bool isPasswordVisible;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Mensaje de reset password (si existe)
  final String? resetPasswordMessage;

  /// Crea una copia del estado con los campos modificados
  LoginState copyWith({
    LoginStatus? status,
    String? email,
    String? password,
    bool? isPasswordVisible,
    String? errorMessage,
    String? resetPasswordMessage,
    bool clearError = false,
    bool clearResetMessage = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resetPasswordMessage: clearResetMessage
          ? null
          : (resetPasswordMessage ?? this.resetPasswordMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        email,
        password,
        isPasswordVisible,
        errorMessage,
        resetPasswordMessage,
      ];
}
