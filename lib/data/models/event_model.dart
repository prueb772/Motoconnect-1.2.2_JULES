/// Representa el modelo de datos para un evento.
///
/// Encapsula toda la información relacionada con un evento,
/// como su título, descripción, fecha y ubicaciones (punto de encuentro y destino).
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;

  // Punto de Encuentro (opcional)
  final String? puntoEncuentro;
  final double? puntoEncuentroLat;
  final double? puntoEncuentroLng;

  // Destino
  final String? destino;
  final double? destinoLat;
  final double? destinoLng;

  final String? organizerId;
  final String? createdBy;
  final List<String>? participants;
  final String? fotoUrl;
  final int? maxParticipants;
  final DateTime? createdAt;
  final String? status;
  final bool? requiresApproval;
  final bool isPublic; // true = público, false = privado (solo grupo)
  final String? creatorId;
  final int? participantsCount;
  final bool? isUserRegistered;
  final String? grupoNombre;
  final List<String> gruposIds; // IDs de grupos asociados (many-to-many)

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.puntoEncuentro,
    this.puntoEncuentroLat,
    this.puntoEncuentroLng,
    this.destino,
    this.destinoLat,
    this.destinoLng,
    this.organizerId,
    this.createdBy,
    this.participants,
    this.fotoUrl,
    this.maxParticipants,
    this.createdAt,
    this.status,
    this.requiresApproval,
    this.isPublic = true, // Por defecto los eventos son públicos
    this.creatorId,
    this.participantsCount,
    this.isUserRegistered,
    this.grupoNombre,
    this.gruposIds = const [],
  });

  /// Factory constructor para crear una instancia de Event desde un mapa (JSON).
  /// Esto es útil cuando se decodifican datos de una API.
  factory Event.fromJson(Map<String, dynamic> json) {
    // Parsear fecha desde diferentes formatos posibles
    DateTime eventDate = DateTime.now();
    try {
      if (json['fecha_hora'] != null) {
        eventDate = DateTime.parse(json['fecha_hora'] as String).toLocal();
      } else if (json['fecha'] != null) {
        eventDate = DateTime.parse(json['fecha'] as String).toLocal();
      } else if (json['date'] != null) {
        if (json['date'] is String) {
          eventDate = DateTime.parse(json['date'] as String).toLocal();
        } else if (json['date'] is DateTime) {
          eventDate = (json['date'] as DateTime).toLocal();
        }
      }
    } catch (e) {
      // Si falla el parseo, usar fecha actual
      eventDate = DateTime.now();
    }

    return Event(
      id: json['id'] as String? ?? json['eventId'] as String? ?? '',
      title: json['titulo'] as String? ?? json['title'] as String? ?? '',
      description: json['descripcion'] as String? ?? json['description'] as String? ?? '',
      date: eventDate,
      // Punto de Encuentro (opcional)
      puntoEncuentro: json['punto_encuentro'] as String? ??
                      json['puntoEncuentro'] as String? ??
                      json['ubicacion'] as String? ??
                      json['location'] as String?,
      puntoEncuentroLat: (json['punto_encuentro_lat'] as num?)?.toDouble() ??
                         (json['puntoEncuentroLat'] as num?)?.toDouble() ??
                         (json['latitud'] as num?)?.toDouble() ??
                         (json['latitude'] as num?)?.toDouble(),
      puntoEncuentroLng: (json['punto_encuentro_lng'] as num?)?.toDouble() ??
                         (json['puntoEncuentroLng'] as num?)?.toDouble() ??
                         (json['longitud'] as num?)?.toDouble() ??
                         (json['longitude'] as num?)?.toDouble(),
      // Destino
      destino: json['destino'] as String?,
      destinoLat: (json['destino_lat'] as num?)?.toDouble() ??
                  (json['destinoLat'] as num?)?.toDouble(),
      destinoLng: (json['destino_lng'] as num?)?.toDouble() ??
                  (json['destinoLng'] as num?)?.toDouble(),
      organizerId: json['organizer_id'] as String? ?? json['organizerId'] as String?,
      createdBy: json['creado_por'] as String? ?? json['created_by'] as String? ?? json['createdBy'] as String?,
      participants: json['participants'] != null
          ? List<String>.from(json['participants'] as List)
          : null,
      fotoUrl: json['foto_url'] as String? ??
               json['fotoUrl'] as String? ??
               json['image_url'] as String? ??
               json['imageUrl'] as String?,
      maxParticipants: json['max_participants'] as int? ?? json['maxParticipants'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : null,
      status: json['estado'] as String? ?? json['status'] as String?,
      requiresApproval: json['requires_approval'] as bool? ?? json['requiresApproval'] as bool?,
      isPublic: json['is_public'] as bool? ?? json['isPublic'] as bool? ?? true,
      creatorId: json['creado_por'] as String? ?? json['created_by'] as String? ?? json['creator_id'] as String? ?? json['creatorId'] as String?,
      participantsCount: json['participants_count'] as int? ?? json['participantsCount'] as int? ?? (json['participants'] as List?)?.length,
      isUserRegistered: json['is_user_registered'] as bool? ?? json['isUserRegistered'] as bool?,
      grupoNombre: json['grupo_nombre'] as String? ?? json['grupoNombre'] as String?,
      gruposIds: List<String>.from(json['grupos_ids'] as List? ?? []),
    );
  }

  /// Convierte el modelo a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': title,
      'descripcion': description,
      'fecha_hora': date.toIso8601String(),
      // Punto de Encuentro
      'punto_encuentro': puntoEncuentro,
      'punto_encuentro_lat': puntoEncuentroLat,
      'punto_encuentro_lng': puntoEncuentroLng,
      // Destino
      'destino': destino,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'organizer_id': organizerId,
      'creado_por': createdBy,
      'participants': participants,
      'foto_url': fotoUrl,
      'max_participants': maxParticipants,
      'created_at': createdAt?.toIso8601String(),
      'estado': status,
      'requires_approval': requiresApproval,
      'is_public': isPublic,
      'creator_id': creatorId,
      'participants_count': participantsCount,
      'is_user_registered': isUserRegistered,
      'grupo_nombre': grupoNombre,
      'grupos_ids': gruposIds,
    };
  }

  /// Copia el modelo con campos modificados
  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? puntoEncuentro,
    double? puntoEncuentroLat,
    double? puntoEncuentroLng,
    String? destino,
    double? destinoLat,
    double? destinoLng,
    String? organizerId,
    String? createdBy,
    List<String>? participants,
    String? fotoUrl,
    int? maxParticipants,
    DateTime? createdAt,
    String? status,
    bool? requiresApproval,
    bool? isPublic,
    String? creatorId,
    int? participantsCount,
    bool? isUserRegistered,
    String? grupoNombre,
    List<String>? gruposIds,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      puntoEncuentro: puntoEncuentro ?? this.puntoEncuentro,
      puntoEncuentroLat: puntoEncuentroLat ?? this.puntoEncuentroLat,
      puntoEncuentroLng: puntoEncuentroLng ?? this.puntoEncuentroLng,
      destino: destino ?? this.destino,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      organizerId: organizerId ?? this.organizerId,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isPublic: isPublic ?? this.isPublic,
      creatorId: creatorId ?? this.creatorId,
      participantsCount: participantsCount ?? this.participantsCount,
      isUserRegistered: isUserRegistered ?? this.isUserRegistered,
      grupoNombre: grupoNombre ?? this.grupoNombre,
      gruposIds: gruposIds ?? this.gruposIds,
    );
  }
}

/// Alias para mantener compatibilidad
typedef EventModel = Event;