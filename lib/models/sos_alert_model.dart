class SosAlertModel {
  final dynamic id;
  final String? driverId;
  final String? tripId;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final String? timestamp;
  final String? status;

  SosAlertModel({
    this.id,
    this.driverId,
    this.tripId,
    this.latitude,
    this.longitude,
    this.speed,
    this.timestamp,
    this.status,
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) => SosAlertModel(
    id: json['id'],
    driverId: json['driverId']?.toString(),
    tripId: json['tripId']?.toString(),
    latitude: double.tryParse(json['latitude']?.toString() ?? ''),
    longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    speed: double.tryParse(json['speed']?.toString() ?? ''),
    timestamp: json['timestamp'] as String?,
    status: json['status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'driverId': driverId,
    'tripId': tripId,
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'timestamp': timestamp,
    'status': status,
  };

  SosAlertModel copyWith({dynamic id, String? driverId, String? tripId, double? latitude, double? longitude, double? speed, String? timestamp, String? status}) => SosAlertModel(
    id: id ?? this.id,
    driverId: driverId ?? this.driverId,
    tripId: tripId ?? this.tripId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    speed: speed ?? this.speed,
    timestamp: timestamp ?? this.timestamp,
    status: status ?? this.status,
  );
}
