part of 'profile_bloc.dart';

/// Eventos del ProfileBloc
///
/// Define las acciones que pueden ocurrir en la pantalla de Perfil.
sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar datos del perfil
class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

/// Cambio de nombre
class ProfileNameChanged extends ProfileEvent {
  const ProfileNameChanged(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Cambio de modelo de moto
class ProfileMotoModelChanged extends ProfileEvent {
  const ProfileMotoModelChanged(this.motoModel);

  final String motoModel;

  @override
  List<Object?> get props => [motoModel];
}

/// Cambio de apodo
class ProfileNicknameChanged extends ProfileEvent {
  const ProfileNicknameChanged(this.nickname);

  final String nickname;

  @override
  List<Object?> get props => [nickname];
}

/// Guardar cambios del perfil
class ProfileSaveRequested extends ProfileEvent {
  const ProfileSaveRequested();
}

/// Limpiar mensaje de error
class ProfileErrorCleared extends ProfileEvent {
  const ProfileErrorCleared();
}

/// Subir foto de perfil
class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested(this.imageFile);

  final dynamic imageFile; // dart:io File

  @override
  List<Object?> get props => [imageFile];
}

/// Eliminar foto de perfil
class ProfileAvatarDeleteRequested extends ProfileEvent {
  const ProfileAvatarDeleteRequested();
}
