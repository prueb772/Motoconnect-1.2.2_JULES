part of 'reset_password_bloc.dart';

/// Estados posibles del proceso de reset de contraseña
enum ResetPasswordStatus {
  /// Estado inicial
  initial,

  /// Procesando actualización
  loading,

  /// Actualización exitosa
  success,

  /// Actualización fallida
  failure,
}

/// Estado del ResetPasswordBloc
///
/// Contiene todo el estado necesario para la pantalla de reset de contraseña.
class ResetPasswordState extends Equatable {
  const ResetPasswordState({
    this.status = ResetPasswordStatus.initial,
    this.password = '',
    this.confirmPassword = '',
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.errorMessage,
  });

  /// Estado actual del proceso
  final ResetPasswordStatus status;

  /// Nueva contraseña ingresada
  final String password;

  /// Confirmación de contraseña
  final String confirmPassword;

  /// Visibilidad de la contraseña
  final bool isPasswordVisible;

  /// Visibilidad de la confirmación
  final bool isConfirmPasswordVisible;

  /// Mensaje de error (si existe)
  final String? errorMessage;

  /// Crea una copia del estado con los campos modificados
  ResetPasswordState copyWith({
    ResetPasswordStatus? status,
    String? password,
    String? confirmPassword,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ResetPasswordState(
      status: status ?? this.status,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        password,
        confirmPassword,
        isPasswordVisible,
        isConfirmPasswordVisible,
        errorMessage,
      ];
}
