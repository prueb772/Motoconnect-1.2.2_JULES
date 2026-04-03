part of 'grupos_bloc.dart';

sealed class GruposEvent extends Equatable {
  const GruposEvent();
  @override
  List<Object?> get props => [];
}

/// Solicita cargar/recargar la lista de grupos
class GruposLoadRequested extends GruposEvent {
  const GruposLoadRequested();
}
