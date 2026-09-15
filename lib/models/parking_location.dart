class ParkingLocation {
  const ParkingLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalCapacity,
    required this.availableCapacity,
    this.distanceKm,
    this.zone = '',
    this.hourlyRate = 0,
    this.hasElectricCharging = false,
    this.hasAccessibleSpaces = false,
    this.isCovered = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int totalCapacity;
  final int availableCapacity;
  final double? distanceKm;
  final String zone;
  final double hourlyRate;
  final bool hasElectricCharging;
  final bool hasAccessibleSpaces;
  final bool isCovered;
  final DateTime? updatedAt;

  bool get hasAvailableSpace => availableCapacity > 0;

  ParkingLocation withDistance(double distanceKm) {
    return ParkingLocation(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      totalCapacity: totalCapacity,
      availableCapacity: availableCapacity,
      distanceKm: distanceKm,
      zone: zone,
      hourlyRate: hourlyRate,
      hasElectricCharging: hasElectricCharging,
      hasAccessibleSpaces: hasAccessibleSpaces,
      isCovered: isCovered,
      updatedAt: updatedAt,
    );
  }

  double get occupancyRatio {
    if (totalCapacity <= 0) return 0;
    return ((totalCapacity - availableCapacity) / totalCapacity)
        .clamp(0, 1)
        .toDouble();
  }

  factory ParkingLocation.fromJson(Map<String, dynamic> json) {
    return ParkingLocation(
      id: _value(json, 'id').toString(),
      name: _value(json, 'name').toString(),
      address: _value(json, 'address').toString(),
      latitude: _asDouble(_value(json, 'latitude')),
      longitude: _asDouble(_value(json, 'longitude')),
      totalCapacity: _asInt(_value(json, 'totalCapacity')),
      availableCapacity: _asInt(_value(json, 'availableCapacity')),
      distanceKm: _nullableDouble(_value(json, 'distanceKm')),
      zone: (_value(json, 'zone') ?? '').toString(),
      hourlyRate: _asDouble(_value(json, 'hourlyRate')),
      hasElectricCharging: _asBool(_value(json, 'hasElectricCharging')),
      hasAccessibleSpaces: _asBool(_value(json, 'hasAccessibleSpaces')),
      isCovered: _asBool(_value(json, 'isCovered')),
      updatedAt: DateTime.tryParse((_value(json, 'updatedAt') ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'totalCapacity': totalCapacity,
        'availableCapacity': availableCapacity,
        'distanceKm': distanceKm,
        'zone': zone,
        'hourlyRate': hourlyRate,
        'hasElectricCharging': hasElectricCharging,
        'hasAccessibleSpaces': hasAccessibleSpaces,
        'isCovered': isCovered,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static dynamic _value(Map<String, dynamic> json, String key) {
    final pascalCase = '${key[0].toUpperCase()}${key.substring(1)}';
    return json[key] ?? json[pascalCase];
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}
