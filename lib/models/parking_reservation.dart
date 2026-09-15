class ParkingReservation {
  const ParkingReservation({
    required this.id,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.parkingSpaceCode,
    required this.vehiclePlate,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.qrToken,
    required this.estimatedAmount,
    this.isPendingSync = false,
  });

  final String id;
  final String parkingLotId;
  final String parkingLotName;
  final String address;
  final double latitude;
  final double longitude;
  final String parkingSpaceCode;
  final String vehiclePlate;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final String qrToken;
  final double estimatedAmount;
  final bool isPendingSync;

  Duration get remaining => endTime.difference(DateTime.now().toUtc());

  factory ParkingReservation.fromJson(Map<String, dynamic> json) {
    dynamic value(String key) {
      final pascal = '${key[0].toUpperCase()}${key.substring(1)}';
      return json[key] ?? json[pascal];
    }

    double number(String key) {
      final item = value(key);
      return item is num ? item.toDouble() : double.tryParse('$item') ?? 0;
    }

    bool boolean(String key) {
      final item = value(key);
      return item is bool ? item : '$item'.toLowerCase() == 'true';
    }

    return ParkingReservation(
      id: '${value('id') ?? ''}',
      parkingLotId: '${value('parkingLotId') ?? ''}',
      parkingLotName: '${value('parkingLotName') ?? ''}',
      address: '${value('address') ?? ''}',
      latitude: number('latitude'),
      longitude: number('longitude'),
      parkingSpaceCode: '${value('parkingSpaceCode') ?? ''}',
      vehiclePlate: '${value('vehiclePlate') ?? ''}',
      startTime: DateTime.tryParse('${value('startTime') ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
      endTime: DateTime.tryParse('${value('endTime') ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
      isActive: boolean('isActive'),
      qrToken: '${value('qrToken') ?? ''}',
      estimatedAmount: number('estimatedAmount'),
      isPendingSync: boolean('isPendingSync'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parkingLotId': parkingLotId,
        'parkingLotName': parkingLotName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'parkingSpaceCode': parkingSpaceCode,
        'vehiclePlate': vehiclePlate,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'isActive': isActive,
        'qrToken': qrToken,
        'estimatedAmount': estimatedAmount,
        'isPendingSync': isPendingSync,
      };
}
