class NotificationPayloadModel {
  final String? type;
  final String? id;
  final String? eventId;
  final String? sesionId;
  final String? grupoId;
  final String? title;
  final String? body;

  const NotificationPayloadModel({
    this.type,
    this.id,
    this.eventId,
    this.sesionId,
    this.grupoId,
    this.title,
    this.body,
  });

  factory NotificationPayloadModel.fromJson(Map<String, dynamic> json) {
    return NotificationPayloadModel(
      type: json['type']?.toString(),
      id: json['id']?.toString(),
      eventId: json['event_id']?.toString(),
      sesionId: json['sesion_id']?.toString(),
      grupoId: json['grupo_id']?.toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (sesionId != null) 'sesion_id': sesionId,
      if (grupoId != null) 'grupo_id': grupoId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    };
  }
}
