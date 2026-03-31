import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/auth_repository.dart';

part 'register_event.dart';
part 'register_state.dart';

/// RegisterBloc - Gestiona el estado de la pantalla de registro
///
/// Este BLoC se provee localmente en RegistroScreen.
/// Es responsable de:
/// - Manejar cambios en los campos del formulario
/// - Ejecutar el proceso de registro
/// - Gestionar estados de carga y errores
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const RegisterState()) {
    on<RegisterNombreChanged>(_onNombreChanged);
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<RegisterPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<RegisterConfirmPasswordVisibilityToggled>(
        _onConfirmPasswordVisibilityToggled);
    on<RegisterSubmitted>(_onSubmitted);
    on<RegisterErrorCleared>(_onErrorCleared);
  }

  final AuthRepository _authRepository;

  /// Maneja cambio de nombre
  void _onNombreChanged(
    RegisterNombreChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      nombre: event.nombre,
      clearError: true,
    ));
  }

  /// Maneja cambio de email
  void _onEmailChanged(
    RegisterEmailChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      email: event.email,
      clearError: true,
    ));
  }

  /// Maneja cambio de password
  void _onPasswordChanged(
    RegisterPasswordChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      password: event.password,
      clearError: true,
    ));
  }

  /// Maneja cambio de confirmación de password
  void _onConfirmPasswordChanged(
    RegisterConfirmPasswordChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      confirmPassword: event.confirmPassword,
      clearError: true,
    ));
  }

  /// Toggle visibilidad del password
  void _onPasswordVisibilityToggled(
    RegisterPasswordVisibilityToggled event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    ));
  }

  /// Toggle visibilidad del confirmar password
  void _onConfirmPasswordVisibilityToggled(
    RegisterConfirmPasswordVisibilityToggled event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    ));
  }

  /// Ejecuta el registro
  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    // Validaciones
    if (state.nombre.trim().isEmpty) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: 'Por favor ingresa tu nombre.',
      ));
      return;
    }

    if (state.nombre.trim().length < 3) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: 'El nombre debe tener al menos 3 caracteres.',
      ));
      return;
    }

    if (state.email.trim().isEmpty || !state.email.contains('@')) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: 'Por favor ingresa un correo válido.',
      ));
      return;
    }

    if (state.password.length < 6) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: 'La contraseña debe tener al menos 6 caracteres.',
      ));
      return;
    }

    if (state.password != state.confirmPassword) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: 'Las contraseñas no coinciden.',
      ));
      return;
    }

    emit(state.copyWith(
      status: RegisterStatus.loading,
      clearError: true,
    ));

    try {
      await _authRepository.signUp(
        email: state.email.trim(),
        password: state.password,
        nombre: state.nombre.trim(),
      );
      emit(state.copyWith(
        status: RegisterStatus.success,
        registeredNombre: state.nombre.trim(),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    RegisterErrorCleared event,
    Emitter<RegisterState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
