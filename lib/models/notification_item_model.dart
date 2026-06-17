class NotificationItemModel {
  final dynamic id;
  final String? title;
  final String? body;
  final String? type;
  final bool? read;
  final Map<String, dynamic>? data;
  final String? createdAt;

  NotificationItemModel({
    required this.id,
    this.title,
    this.body,
    this.type,
    this.read,
    this.data,
    this.createdAt,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) => NotificationItemModel(
    id: json['_id'] ?? json['id'],
    title: json['title'] as String?,
    body: json['body'] as String?,
    type: json['type'] as String?,
    read: json['read'] as bool?,
    data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
    createdAt: json['createdAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (type != null) 'type': type,
    if (read != null) 'read': read,
    if (data != null) 'data': data,
    if (createdAt != null) 'createdAt': createdAt,
  };

  NotificationItemModel copyWith({
    dynamic id,
    String? title,
    String? body,
    String? type,
    bool? read,
    Map<String, dynamic>? data,
    String? createdAt,
  }) => NotificationItemModel(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    read: read ?? this.read,
    data: data ?? this.data,
    createdAt: createdAt ?? this.createdAt,
  );
}
