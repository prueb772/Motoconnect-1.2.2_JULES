import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/auth_repository.dart';

part 'login_event.dart';
part 'login_state.dart';

/// LoginBloc - Gestiona el estado de la pantalla de login
///
/// Este BLoC reemplaza a LoginViewModel y se provee localmente en LoginScreen.
/// Es responsable de:
/// - Manejar cambios en los campos del formulario
/// - Ejecutar el proceso de login (email/password y Google)
/// - Manejar el reset de password
/// - Gestionar estados de carga y errores
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginSubmitted>(_onSubmitted);
    on<LoginWithGoogleRequested>(_onGoogleLoginRequested);
    on<LoginPasswordResetRequested>(_onPasswordResetRequested);
    on<LoginErrorCleared>(_onErrorCleared);
  }

  final AuthRepository _authRepository;

  /// Maneja cambio de email
  void _onEmailChanged(
    LoginEmailChanged event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      email: event.email,
      clearError: true,
    ));
  }

  /// Maneja cambio de password
  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      password: event.password,
      clearError: true,
    ));
  }

  /// Toggle visibilidad del password
  void _onPasswordVisibilityToggled(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  /// Ejecuta el login con email/password
  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // Validación básica
    if (state.email.isEmpty || state.password.isEmpty) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: 'Por favor, ingresa correo y contraseña.',
      ));
      return;
    }

    emit(state.copyWith(
      status: LoginStatus.loading,
      clearError: true,
    ));

    try {
      await _authRepository.signIn(
        email: state.email.trim(),
        password: state.password.trim(),
      );
      emit(state.copyWith(status: LoginStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Ejecuta el login con Google
  Future<void> _onGoogleLoginRequested(
    LoginWithGoogleRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(
      status: LoginStatus.loading,
      clearError: true,
    ));

    try {
      await _authRepository.signInWithGoogle();
      emit(state.copyWith(status: LoginStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Maneja la solicitud de reset de password
  Future<void> _onPasswordResetRequested(
    LoginPasswordResetRequested event,
    Emitter<LoginState> emit,
  ) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(
        resetPasswordMessage:
            'Por favor, ingresa tu correo para restablecer la contraseña.',
      ));
      return;
    }

    emit(state.copyWith(status: LoginStatus.loading));

    try {
      await _authRepository.resetPassword(state.email.trim());
      emit(state.copyWith(
        status: LoginStatus.initial,
        resetPasswordMessage: 'Se ha enviado un correo de recuperación.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.initial,
        resetPasswordMessage: e.toString(),
      ));
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    LoginErrorCleared event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      clearError: true,
      clearResetMessage: true,
    ));
  }
}
