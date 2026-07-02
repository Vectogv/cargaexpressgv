// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['_id'] as String,
  tripId: json['tripId'] as String?,
  senderId: json['senderId'] as String?,
  text: json['text'] as String?,
  timestamp: json['timestamp'] as String?,
  isSent: json['isSent'] as bool?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  '_id': instance.id,
  'tripId': instance.tripId,
  'senderId': instance.senderId,
  'text': instance.text,
  'timestamp': instance.timestamp,
  'isSent': instance.isSent,
  'status': instance.status,
};
