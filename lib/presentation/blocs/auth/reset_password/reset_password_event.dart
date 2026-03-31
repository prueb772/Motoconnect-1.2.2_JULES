part of 'reset_password_bloc.dart';

/// Eventos del ResetPasswordBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de reset de contraseña.
sealed class ResetPasswordEvent extends Equatable {
  const ResetPasswordEvent();

  @override
  List<Object?> get props => [];
}

/// Password cambió
class ResetPasswordPasswordChanged extends ResetPasswordEvent {
  const ResetPasswordPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Confirmar password cambió
class ResetPasswordConfirmPasswordChanged extends ResetPasswordEvent {
  const ResetPasswordConfirmPasswordChanged(this.confirmPassword);

  final String confirmPassword;

  @override
  List<Object?> get props => [confirmPassword];
}

/// Toggle visibilidad de password
class ResetPasswordVisibilityToggled extends ResetPasswordEvent {
  const ResetPasswordVisibilityToggled();
}

/// Toggle visibilidad de confirmar password
class ResetPasswordConfirmVisibilityToggled extends ResetPasswordEvent {
  const ResetPasswordConfirmVisibilityToggled();
}

/// Submit del formulario
class ResetPasswordSubmitted extends ResetPasswordEvent {
  const ResetPasswordSubmitted();
}

/// Limpiar mensaje de error
class ResetPasswordErrorCleared extends ResetPasswordEvent {
  const ResetPasswordErrorCleared();
}
