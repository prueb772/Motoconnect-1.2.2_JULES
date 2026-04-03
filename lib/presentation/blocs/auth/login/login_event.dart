part of 'login_bloc.dart';

/// Eventos del LoginBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de login.
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Email cambió
class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Password cambió
class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Toggle visibilidad de password
class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled();
}

/// Submit del formulario de login
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}

/// Solicitud de login con Google
class LoginWithGoogleRequested extends LoginEvent {
  const LoginWithGoogleRequested();
}

/// Solicitud de reset de password
class LoginPasswordResetRequested extends LoginEvent {
  const LoginPasswordResetRequested();
}

/// Limpiar mensaje de error
class LoginErrorCleared extends LoginEvent {
  const LoginErrorCleared();
}
