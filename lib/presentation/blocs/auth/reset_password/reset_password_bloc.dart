import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/auth_repository.dart';

part 'reset_password_event.dart';
part 'reset_password_state.dart';

/// ResetPasswordBloc - Gestiona el estado de la pantalla de reset de contraseña
///
/// Este BLoC se provee localmente en ResetPasswordScreen.
/// Es responsable de:
/// - Manejar cambios en los campos del formulario
/// - Ejecutar la actualización de contraseña
/// - Gestionar estados de carga y errores
class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const ResetPasswordState()) {
    on<ResetPasswordPasswordChanged>(_onPasswordChanged);
    on<ResetPasswordConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<ResetPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<ResetPasswordConfirmVisibilityToggled>(
        _onConfirmVisibilityToggled);
    on<ResetPasswordSubmitted>(_onSubmitted);
    on<ResetPasswordErrorCleared>(_onErrorCleared);
  }

  final AuthRepository _authRepository;

  /// Maneja cambio de password
  void _onPasswordChanged(
    ResetPasswordPasswordChanged event,
    Emitter<ResetPasswordState> emit,
  ) {
    emit(state.copyWith(
      password: event.password,
      clearError: true,
    ));
  }

  /// Maneja cambio de confirmación de password
  void _onConfirmPasswordChanged(
    ResetPasswordConfirmPasswordChanged event,
    Emitter<ResetPasswordState> emit,
  ) {
    emit(state.copyWith(
      confirmPassword: event.confirmPassword,
      clearError: true,
    ));
  }

  /// Toggle visibilidad del password
  void _onPasswordVisibilityToggled(
    ResetPasswordVisibilityToggled event,
    Emitter<ResetPasswordState> emit,
  ) {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  /// Toggle visibilidad de confirmar password
  void _onConfirmVisibilityToggled(
    ResetPasswordConfirmVisibilityToggled event,
    Emitter<ResetPasswordState> emit,
  ) {
    emit(state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    ));
  }

  /// Ejecuta la actualización de contraseña
  Future<void> _onSubmitted(
    ResetPasswordSubmitted event,
    Emitter<ResetPasswordState> emit,
  ) async {
    // Validaciones
    if (state.password.trim().isEmpty) {
      emit(state.copyWith(
        status: ResetPasswordStatus.failure,
        errorMessage: 'Ingresa una contraseña.',
      ));
      return;
    }

    if (state.password.trim().length < 6) {
      emit(state.copyWith(
        status: ResetPasswordStatus.failure,
        errorMessage: 'Mínimo 6 caracteres.',
      ));
      return;
    }

    if (state.password.trim() != state.confirmPassword.trim()) {
      emit(state.copyWith(
        status: ResetPasswordStatus.failure,
        errorMessage: 'Las contraseñas no coinciden.',
      ));
      return;
    }

    emit(state.copyWith(
      status: ResetPasswordStatus.loading,
      clearError: true,
    ));

    try {
      await _authRepository.updatePassword(state.password.trim());
      emit(state.copyWith(status: ResetPasswordStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: ResetPasswordStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    ResetPasswordErrorCleared event,
    Emitter<ResetPasswordState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
