import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/models/user_model.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// ProfileBloc - Gestiona el estado de la pantalla de Perfil
///
/// Este BLoC reemplaza a ProfileViewModel.
/// Es responsable de:
/// - Cargar datos del perfil del usuario
/// - Validar y guardar cambios
/// - Gestionar la foto de perfil (subir/eliminar)
/// - Gestionar estados de carga y errores
///
/// Nota: Los TextEditingControllers permanecen en la Vista
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required ProfileRepository profileRepository,
  })  : _profileRepository = profileRepository,
        super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileNameChanged>(_onNameChanged);
    on<ProfileMotoModelChanged>(_onMotoModelChanged);
    on<ProfileNicknameChanged>(_onNicknameChanged);
    on<ProfileSaveRequested>(_onSaveRequested);
    on<ProfileErrorCleared>(_onErrorCleared);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
    on<ProfileAvatarDeleteRequested>(_onAvatarDeleteRequested);
  }

  final ProfileRepository _profileRepository;

  /// Carga los datos del perfil
  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      final userId = _profileRepository.getCurrentUserId();

      if (userId == null) {
        emit(state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Usuario no autenticado',
        ));
        return;
      }

      final correo = _profileRepository.getCurrentUserEmail() ?? 'No disponible';

      // Obtener datos adicionales de la tabla usuarios
      final userModel = await _profileRepository.getProfile(userId);

      if (userModel == null) {
        // Si el perfil no existe, crear uno nuevo
        await _crearPerfilInicial(userId, correo, emit);
      } else {
        emit(state.copyWith(
          status: ProfileStatus.loaded,
          userId: userId,
          correo: correo,
          nombre: userModel.nombre,
          modeloMoto: userModel.modeloMoto ?? '',
          apodo: userModel.apodo ?? '',
          avatarUrl: userModel.fotoPerfil,
          clearError: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'No se pudieron cargar los datos del perfil: ${e.toString()}',
      ));
      debugPrint('Error en ProfileBloc._onLoadRequested: $e');
    }
  }

  /// Crea un perfil inicial para el usuario
  Future<void> _crearPerfilInicial(
    String userId,
    String correo,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final metadata = _profileRepository.getCurrentUserMetadata();
      // Extraer nombre de los metadatos o del email
      final nombre = metadata?.resolvedName ??
          correo.split('@')[0];

      final newUser = UserModel(
        id: userId,
        email: correo,
        nombre: nombre,
      );

      // Crear el perfil en la base de datos
      await _profileRepository.createProfile(newUser);

      emit(state.copyWith(
        status: ProfileStatus.loaded,
        userId: userId,
        correo: correo,
        nombre: nombre,
        modeloMoto: '',
        apodo: '',
        clearError: true,
      ));

      debugPrint('Perfil inicial creado exitosamente');
    } catch (e) {
      debugPrint('Error al crear perfil inicial: $e');
      final metadata = _profileRepository.getCurrentUserMetadata();
      // Si falla, usar valores por defecto
      emit(state.copyWith(
        status: ProfileStatus.loaded,
        userId: userId,
        correo: correo,
        nombre: metadata?.resolvedName ?? 'Usuario',
        modeloMoto: '',
        apodo: '',
      ));
    }
  }

  /// Maneja cambio de nombre
  void _onNameChanged(
    ProfileNameChanged event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(
      nombre: event.name,
      clearError: true,
    ));
  }

  /// Maneja cambio de modelo de moto
  void _onMotoModelChanged(
    ProfileMotoModelChanged event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(
      modeloMoto: event.motoModel,
      clearError: true,
    ));
  }

  /// Maneja cambio de apodo
  void _onNicknameChanged(
    ProfileNicknameChanged event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(
      apodo: event.nickname,
      clearError: true,
    ));
  }

  /// Guarda los cambios del perfil
  Future<void> _onSaveRequested(
    ProfileSaveRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // Validación
    if (state.nombre.trim().isEmpty) {
      emit(state.copyWith(
        errorMessage: 'El nombre es obligatorio',
      ));
      return;
    }

    if (state.userId == null) {
      emit(state.copyWith(
        errorMessage: 'Error: No se pudo identificar al usuario',
      ));
      return;
    }

    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      final updatedUser = UserModel(
        id: state.userId!,
        email: state.correo.trim(),
        nombre: state.nombre.trim(),
        modeloMoto: state.modeloMoto.trim().isEmpty ? null : state.modeloMoto.trim(),
        apodo: state.apodo.trim().isEmpty ? null : state.apodo.trim(),
        fotoPerfil: state.avatarUrl,
      );

      await _profileRepository.updateProfile(updatedUser);

      emit(state.copyWith(
        status: ProfileStatus.saved,
        clearError: true,
      ));

      // Después de un breve delay, volver al estado loaded
      await Future.delayed(const Duration(milliseconds: 500));
      emit(state.copyWith(status: ProfileStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Error al guardar perfil: ${e.toString()}',
      ));
      debugPrint('Error en ProfileBloc._onSaveRequested: $e');
    }
  }

  /// Sube una foto de perfil
  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.userId == null) return;

    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      final url = await _profileRepository.uploadAvatar(
        imageFile: event.imageFile,
        userId: state.userId!,
      );

      emit(state.copyWith(
        status: ProfileStatus.loaded,
        avatarUrl: url,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Error al subir imagen: ${e.toString()}',
      ));
      debugPrint('Error en ProfileBloc._onAvatarUploadRequested: $e');
    }
  }

  /// Elimina la foto de perfil
  Future<void> _onAvatarDeleteRequested(
    ProfileAvatarDeleteRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.userId == null) return;

    emit(state.copyWith(status: ProfileStatus.saving));

    try {
      await _profileRepository.deleteAvatar(state.userId!);

      emit(state.copyWith(
        status: ProfileStatus.loaded,
        clearAvatarUrl: true,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Error al eliminar imagen: ${e.toString()}',
      ));
      debugPrint('Error en ProfileBloc._onAvatarDeleteRequested: $e');
    }
  }

  /// Limpia el mensaje de error
  void _onErrorCleared(
    ProfileErrorCleared event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
