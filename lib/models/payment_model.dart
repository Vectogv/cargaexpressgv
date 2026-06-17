class PaymentModel {
  final dynamic id;
  final String? tripId;
  final double? amount;
  final String? method;
  final String? status;
  final String? reference;
  final String? createdAt;

  PaymentModel({
    this.id,
    this.tripId,
    this.amount,
    this.method,
    this.status,
    this.reference,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: json['id'],
    tripId: json['tripId']?.toString(),
    amount: double.tryParse(json['amount']?.toString() ?? ''),
    method: json['method'] as String?,
    status: json['status'] as String?,
    reference: json['reference'] as String?,
    createdAt: json['createdAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'tripId': tripId,
    'amount': amount,
    'method': method,
    'status': status,
    'reference': reference,
    'createdAt': createdAt,
  };

  PaymentModel copyWith({
    dynamic id, String? tripId, double? amount, String? method,
    String? status, String? reference, String? createdAt,
  }) => PaymentModel(
    id: id ?? this.id, tripId: tripId ?? this.tripId, amount: amount ?? this.amount,
    method: method ?? this.method, status: status ?? this.status,
    reference: reference ?? this.reference, createdAt: createdAt ?? this.createdAt,
  );
}
