/// Modelo de Comentario/Publicación de Comunidad
///
/// Representa una publicación en la sección de comunidad.
/// Puede ser de tipo texto, imagen, video, ruta_compartida,
/// evento_compartido o taller_compartido.
///
/// Este modelo es inmutable (final fields) y tiene:
/// - Constructor
/// - fromJson para deserialización
/// - toJson para serialización
/// - copyWith para copias modificadas
library;

class ComentarioComunidadModel {
  /// ID único de la publicación (UUID de Supabase)
  final String id;

  /// ID del usuario autor de la publicación
  final String usuarioId;

  /// Contenido textual de la publicación (opcional)
  final String? contenido;

  /// Título de la publicación (opcional)
  final String? titulo;

  /// Tipo de publicación: texto, imagen, video, ruta_compartida,
  /// evento_compartido, taller_compartido
  final String tipo;

  /// Fecha de la publicación
  final DateTime fecha;

  /// URL de imagen asociada (opcional)
  final String? imagenUrl;

  /// URL de media (imagen o video) subida por el usuario (opcional)
  final String? mediaUrl;

  /// Categoría de la publicación (opcional)
  final String? categoria;

  /// ID de la ruta compartida (FK a rutas_realizadas, opcional)
  final String? referenciaRutaId;

  /// ID del evento compartido (FK a eventos, opcional)
  final String? referenciaEventoId;

  /// ID del taller compartido (FK a talleres, opcional)
  final String? referenciaTallerId;

  /// Cantidad de likes
  final int likesCount;

  /// Cantidad de comentarios
  final int comentariosCount;

  /// Fecha de creación del registro
  final DateTime createdAt;

  /// Fecha de última actualización del registro
  final DateTime updatedAt;

  /// Constructor
  const ComentarioComunidadModel({
    required this.id,
    required this.usuarioId,
    this.contenido,
    this.titulo,
    required this.tipo,
    required this.fecha,
    this.imagenUrl,
    this.mediaUrl,
    this.categoria,
    this.referenciaRutaId,
    this.referenciaEventoId,
    this.referenciaTallerId,
    this.likesCount = 0,
    this.comentariosCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una instancia desde JSON (respuesta de Supabase)
  factory ComentarioComunidadModel.fromJson(Map<String, dynamic> json) {
    return ComentarioComunidadModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      contenido: json['contenido'] as String?,
      titulo: json['titulo'] as String?,
      tipo: json['tipo'] as String? ?? 'texto',
      fecha: DateTime.parse(json['fecha'] as String),
      imagenUrl: json['imagen_url'] as String?,
      mediaUrl: json['media_url'] as String?,
      categoria: json['categoria'] as String?,
      referenciaRutaId: json['referencia_ruta_id'] as String?,
      referenciaEventoId: json['referencia_evento_id'] as String?,
      referenciaTallerId: json['referencia_taller_id'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      comentariosCount: json['comentarios_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'contenido': contenido,
      'titulo': titulo,
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'imagen_url': imagenUrl,
      'media_url': mediaUrl,
      'categoria': categoria,
      'referencia_ruta_id': referenciaRutaId,
      'referencia_evento_id': referenciaEventoId,
      'referencia_taller_id': referenciaTallerId,
      'likes_count': likesCount,
      'comentarios_count': comentariosCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  ComentarioComunidadModel copyWith({
    String? id,
    String? usuarioId,
    String? contenido,
    String? titulo,
    String? tipo,
    DateTime? fecha,
    String? imagenUrl,
    String? mediaUrl,
    String? categoria,
    String? referenciaRutaId,
    String? referenciaEventoId,
    String? referenciaTallerId,
    int? likesCount,
    int? comentariosCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComentarioComunidadModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      contenido: contenido ?? this.contenido,
      titulo: titulo ?? this.titulo,
      tipo: tipo ?? this.tipo,
      fecha: fecha ?? this.fecha,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      categoria: categoria ?? this.categoria,
      referenciaRutaId: referenciaRutaId ?? this.referenciaRutaId,
      referenciaEventoId: referenciaEventoId ?? this.referenciaEventoId,
      referenciaTallerId: referenciaTallerId ?? this.referenciaTallerId,
      likesCount: likesCount ?? this.likesCount,
      comentariosCount: comentariosCount ?? this.comentariosCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
