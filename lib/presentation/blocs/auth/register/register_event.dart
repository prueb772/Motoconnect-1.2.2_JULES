part of 'register_bloc.dart';

/// Eventos del RegisterBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de registro.
sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

/// Nombre cambió
class RegisterNombreChanged extends RegisterEvent {
  const RegisterNombreChanged(this.nombre);

  final String nombre;

  @override
  List<Object?> get props => [nombre];
}

/// Email cambió
class RegisterEmailChanged extends RegisterEvent {
  const RegisterEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Password cambió
class RegisterPasswordChanged extends RegisterEvent {
  const RegisterPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Confirmar password cambió
class RegisterConfirmPasswordChanged extends RegisterEvent {
  const RegisterConfirmPasswordChanged(this.confirmPassword);

  final String confirmPassword;

  @override
  List<Object?> get props => [confirmPassword];
}

/// Toggle visibilidad de password
class RegisterPasswordVisibilityToggled extends RegisterEvent {
  const RegisterPasswordVisibilityToggled();
}

/// Toggle visibilidad de confirmar password
class RegisterConfirmPasswordVisibilityToggled extends RegisterEvent {
  const RegisterConfirmPasswordVisibilityToggled();
}

/// Submit del formulario de registro
class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted();
}

/// Limpiar mensaje de error
class RegisterErrorCleared extends RegisterEvent {
  const RegisterErrorCleared();
}
