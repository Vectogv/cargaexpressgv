import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  @JsonKey(name: '_id')
  final String id;
  final String? tripId;
  final String? senderId;
  final String? text;
  final String? timestamp;
  final bool? isSent;
  final String? status;

  Message({
    required this.id,
    this.tripId,
    this.senderId,
    this.text,
    this.timestamp,
    this.isSent,
    this.status,
  });

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
