class ChatMessageModel {
  final dynamic id;
  final dynamic tripId;
  final String? senderId;
  final String? text;
  final String? timestamp;
  final bool? isSent;
  final String? status;

  ChatMessageModel({
    required this.id,
    this.tripId,
    this.senderId,
    this.text,
    this.timestamp,
    this.isSent,
    this.status,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
    id: json['_id'] ?? json['id'],
    tripId: json['tripId'] ?? json['viaje'],
    senderId: json['senderId'] as String?,
    text: json['text'] as String?,
    timestamp: json['timestamp'] as String?,
    isSent: json['isSent'] as bool?,
    status: json['status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    if (tripId != null) 'tripId': tripId,
    if (senderId != null) 'senderId': senderId,
    if (text != null) 'text': text,
    if (timestamp != null) 'timestamp': timestamp,
    if (isSent != null) 'isSent': isSent,
    if (status != null) 'status': status,
  };

  ChatMessageModel copyWith({
    dynamic id,
    dynamic tripId,
    String? senderId,
    String? text,
    String? timestamp,
    bool? isSent,
    String? status,
  }) => ChatMessageModel(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    senderId: senderId ?? this.senderId,
    text: text ?? this.text,
    timestamp: timestamp ?? this.timestamp,
    isSent: isSent ?? this.isSent,
    status: status ?? this.status,
  );
}
