class ReportModel {
  final dynamic id;
  final String? tipo;
  final String? descripcion;
  final String? tripId;
  final String? userId;
  final String? targetId;
  final String? status;
  final List<String>? fotos;
  final String? createdAt;

  ReportModel({
    this.id,
    this.tipo,
    this.descripcion,
    this.tripId,
    this.userId,
    this.targetId,
    this.status,
    this.fotos,
    this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
    id: json['id'],
    tipo: json['tipo'] as String?,
    descripcion: json['descripcion'] as String?,
    tripId: json['tripId']?.toString(),
    userId: json['userId']?.toString(),
    targetId: json['targetId']?.toString(),
    status: json['status'] as String?,
    fotos: (json['fotos'] as List?)?.cast<String>(),
    createdAt: json['createdAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'tipo': tipo,
    'descripcion': descripcion,
    'tripId': tripId,
    'userId': userId,
    'targetId': targetId,
    'status': status,
    'fotos': fotos,
    'createdAt': createdAt,
  };

  ReportModel copyWith({
    dynamic id, String? tipo, String? descripcion, String? tripId,
    String? userId, String? targetId, String? status, List<String>? fotos, String? createdAt,
  }) => ReportModel(
    id: id ?? this.id, tipo: tipo ?? this.tipo, descripcion: descripcion ?? this.descripcion,
    tripId: tripId ?? this.tripId, userId: userId ?? this.userId, targetId: targetId ?? this.targetId,
    status: status ?? this.status, fotos: fotos ?? this.fotos, createdAt: createdAt ?? this.createdAt,
  );
}
