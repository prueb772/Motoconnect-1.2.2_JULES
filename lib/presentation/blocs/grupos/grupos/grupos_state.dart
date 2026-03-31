part of 'grupos_bloc.dart';

enum GruposStatus { initial, loading, loaded, error }

class GruposState extends Equatable {
  const GruposState({
    this.status = GruposStatus.initial,
    this.grupos = const [],
    this.errorMessage,
  });

  final GruposStatus status;
  final List<GrupoRutaModel> grupos;
  final String? errorMessage;

  GruposState copyWith({
    GruposStatus? status,
    List<GrupoRutaModel>? grupos,
    String? errorMessage,
  }) {
    return GruposState(
      status: status ?? this.status,
      grupos: grupos ?? this.grupos,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, grupos, errorMessage];
}
