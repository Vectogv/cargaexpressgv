class LocationModel {
  final double lat;
  final double lng;
  final String direccion;

  LocationModel({required this.lat, required this.lng, required this.direccion});

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    lat: double.parse(json['lat'].toString()),
    lng: double.parse(json['lng'].toString()),
    direccion: json['direccion'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'direccion': direccion};

  LocationModel copyWith({double? lat, double? lng, String? direccion}) => LocationModel(
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    direccion: direccion ?? this.direccion,
  );
}
