class ParkingSession {
  const ParkingSession({
    required this.id,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.vehiclePlate,
    required this.startedAt,
    required this.paymentStatus,
    this.parkingSpaceCode,
    this.endedAt,
    this.totalAmount,
  });

  final String id;
  final String parkingLotId;
  final String parkingLotName;
  final String? parkingSpaceCode;
  final String vehiclePlate;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double? totalAmount;
  final String paymentStatus;

  bool get isActive => endedAt == null;

  factory ParkingSession.fromJson(Map<String, dynamic> json) => ParkingSession(
        id: json['id']?.toString() ?? '',
        parkingLotId: json['parkingLotId']?.toString() ?? '',
        parkingLotName: json['parkingLotName']?.toString() ?? '',
        parkingSpaceCode: json['parkingSpaceCode']?.toString(),
        vehiclePlate: json['vehiclePlate']?.toString() ?? '',
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
        endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
        totalAmount: _nullableDouble(json['totalAmount']),
        paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      );
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
