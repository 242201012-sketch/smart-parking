class AdminTotals {
  const AdminTotals({
    required this.users,
    required this.parkingLots,
    required this.spaces,
    required this.availableSpaces,
    required this.activeReservations,
    required this.activeSessions,
    required this.readingsLast24Hours,
    required this.sensorDevices,
    required this.onlineSensors,
  });

  final int users;
  final int parkingLots;
  final int spaces;
  final int availableSpaces;
  final int activeReservations;
  final int activeSessions;
  final int readingsLast24Hours;
  final int sensorDevices;
  final int onlineSensors;

  factory AdminTotals.fromJson(Map<String, dynamic> json) => AdminTotals(
        users: _asInt(json['users']),
        parkingLots: _asInt(json['parkingLots']),
        spaces: _asInt(json['spaces']),
        availableSpaces: _asInt(json['availableSpaces']),
        activeReservations: _asInt(json['activeReservations']),
        activeSessions: _asInt(json['activeSessions']),
        readingsLast24Hours: _asInt(json['readingsLast24Hours']),
        sensorDevices: _asInt(json['sensorDevices']),
        onlineSensors: _asInt(json['onlineSensors']),
      );
}

class AdminParkingLot {
  const AdminParkingLot({
    required this.id,
    required this.name,
    required this.totalCapacity,
    required this.availableCapacity,
    required this.occupancyPercent,
  });

  final String id;
  final String name;
  final int totalCapacity;
  final int availableCapacity;
  final double occupancyPercent;

  factory AdminParkingLot.fromJson(Map<String, dynamic> json) => AdminParkingLot(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        totalCapacity: _asInt(json['totalCapacity']),
        availableCapacity: _asInt(json['availableCapacity']),
        occupancyPercent: _asDouble(json['occupancyPercent']),
      );
}

class AdminDashboard {
  const AdminDashboard({
    required this.generatedAt,
    required this.totals,
    required this.lots,
  });

  final DateTime? generatedAt;
  final AdminTotals totals;
  final List<AdminParkingLot> lots;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    final totalsJson = json['totals'];
    final lotsJson = json['lots'];
    return AdminDashboard(
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      totals: AdminTotals.fromJson(
        totalsJson is Map<String, dynamic> ? totalsJson : const {},
      ),
      lots: lotsJson is List
          ? lotsJson
              .whereType<Map<String, dynamic>>()
              .map(AdminParkingLot.fromJson)
              .toList()
          : const [],
    );
  }
}

class AdminSensor {
  const AdminSensor({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.isActive,
    required this.isOnline,
    this.lastSeenAt,
    this.batteryPercent,
    this.firmwareVersion,
  });

  final String id;
  final String deviceId;
  final String name;
  final String parkingLotId;
  final String parkingLotName;
  final bool isActive;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int? batteryPercent;
  final String? firmwareVersion;

  factory AdminSensor.fromJson(Map<String, dynamic> json) => AdminSensor(
        id: json['id']?.toString() ?? '',
        deviceId: json['deviceId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        parkingLotId: json['parkingLotId']?.toString() ?? '',
        parkingLotName: json['parkingLotName']?.toString() ?? '',
        isActive: json['isActive'] == true,
        isOnline: json['isOnline'] == true,
        lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
        batteryPercent: json['batteryPercent'] == null
            ? null
            : _asInt(json['batteryPercent']),
        firmwareVersion: json['firmwareVersion']?.toString(),
      );
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
