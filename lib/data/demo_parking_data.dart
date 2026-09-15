import 'dart:math' as math;

import '../models/parking_location.dart';

final demoParkingLocations = List<ParkingLocation>.unmodifiable(
  _provinceSeeds.map((province) {
    final capacity = 48 + (province.plateCode % 5) * 12;
    final occupied = 10 + (province.plateCode * 7) % (capacity - 16);
    return ParkingLocation(
      id: province.plateCode == 5
          ? 'merkez-katli'
          : 'tr-${province.plateCode.toString().padLeft(2, '0')}',
      name: '${province.name} Merkez Akıllı Otoparkı',
      address: '${province.name} Merkez, Türkiye',
      latitude: province.latitude,
      longitude: province.longitude,
      totalCapacity: capacity,
      availableCapacity: capacity - occupied,
      zone: province.name,
      hourlyRate: (30 + (province.plateCode % 6) * 5).toDouble(),
      hasElectricCharging: province.plateCode % 3 == 0,
      hasAccessibleSpaces: true,
      isCovered: province.plateCode.isEven,
    );
  }),
);

const _provinceSeeds = <_ProvinceSeed>[
  _ProvinceSeed(1, 'Adana', 37.0000, 35.3213),
  _ProvinceSeed(2, 'Adıyaman', 37.7648, 38.2786),
  _ProvinceSeed(3, 'Afyonkarahisar', 38.7507, 30.5567),
  _ProvinceSeed(4, 'Ağrı', 39.7191, 43.0503),
  _ProvinceSeed(5, 'Amasya', 40.6504, 35.8337),
  _ProvinceSeed(6, 'Ankara', 39.9334, 32.8597),
  _ProvinceSeed(7, 'Antalya', 36.8969, 30.7133),
  _ProvinceSeed(8, 'Artvin', 41.1828, 41.8183),
  _ProvinceSeed(9, 'Aydın', 37.8450, 27.8396),
  _ProvinceSeed(10, 'Balıkesir', 39.6484, 27.8826),
  _ProvinceSeed(11, 'Bilecik', 40.1501, 29.9831),
  _ProvinceSeed(12, 'Bingöl', 38.8854, 40.4980),
  _ProvinceSeed(13, 'Bitlis', 38.4006, 42.1095),
  _ProvinceSeed(14, 'Bolu', 40.7350, 31.6061),
  _ProvinceSeed(15, 'Burdur', 37.7203, 30.2908),
  _ProvinceSeed(16, 'Bursa', 40.1885, 29.0610),
  _ProvinceSeed(17, 'Çanakkale', 40.1553, 26.4142),
  _ProvinceSeed(18, 'Çankırı', 40.6013, 33.6134),
  _ProvinceSeed(19, 'Çorum', 40.5506, 34.9556),
  _ProvinceSeed(20, 'Denizli', 37.7765, 29.0864),
  _ProvinceSeed(21, 'Diyarbakır', 37.9144, 40.2306),
  _ProvinceSeed(22, 'Edirne', 41.6771, 26.5557),
  _ProvinceSeed(23, 'Elazığ', 38.6810, 39.2264),
  _ProvinceSeed(24, 'Erzincan', 39.7500, 39.5000),
  _ProvinceSeed(25, 'Erzurum', 39.9055, 41.2658),
  _ProvinceSeed(26, 'Eskişehir', 39.7667, 30.5256),
  _ProvinceSeed(27, 'Gaziantep', 37.0662, 37.3833),
  _ProvinceSeed(28, 'Giresun', 40.9128, 38.3895),
  _ProvinceSeed(29, 'Gümüşhane', 40.4603, 39.4814),
  _ProvinceSeed(30, 'Hakkari', 37.5744, 43.7408),
  _ProvinceSeed(31, 'Hatay', 36.2023, 36.1600),
  _ProvinceSeed(32, 'Isparta', 37.7648, 30.5566),
  _ProvinceSeed(33, 'Mersin', 36.8121, 34.6415),
  _ProvinceSeed(34, 'İstanbul', 41.0082, 28.9784),
  _ProvinceSeed(35, 'İzmir', 38.4237, 27.1428),
  _ProvinceSeed(36, 'Kars', 40.6013, 43.0975),
  _ProvinceSeed(37, 'Kastamonu', 41.3887, 33.7827),
  _ProvinceSeed(38, 'Kayseri', 38.7225, 35.4875),
  _ProvinceSeed(39, 'Kırklareli', 41.7355, 27.2244),
  _ProvinceSeed(40, 'Kırşehir', 39.1425, 34.1709),
  _ProvinceSeed(41, 'Kocaeli', 40.8533, 29.8815),
  _ProvinceSeed(42, 'Konya', 37.8746, 32.4932),
  _ProvinceSeed(43, 'Kütahya', 39.4192, 29.9857),
  _ProvinceSeed(44, 'Malatya', 38.3552, 38.3095),
  _ProvinceSeed(45, 'Manisa', 38.6191, 27.4289),
  _ProvinceSeed(46, 'Kahramanmaraş', 37.5753, 36.9228),
  _ProvinceSeed(47, 'Mardin', 37.3212, 40.7245),
  _ProvinceSeed(48, 'Muğla', 37.2153, 28.3636),
  _ProvinceSeed(49, 'Muş', 38.9462, 41.7539),
  _ProvinceSeed(50, 'Nevşehir', 38.6244, 34.7239),
  _ProvinceSeed(51, 'Niğde', 37.9698, 34.6766),
  _ProvinceSeed(52, 'Ordu', 40.9839, 37.8764),
  _ProvinceSeed(53, 'Rize', 41.0201, 40.5234),
  _ProvinceSeed(54, 'Sakarya', 40.7731, 30.3948),
  _ProvinceSeed(55, 'Samsun', 41.2867, 36.3300),
  _ProvinceSeed(56, 'Siirt', 37.9333, 41.9500),
  _ProvinceSeed(57, 'Sinop', 42.0231, 35.1531),
  _ProvinceSeed(58, 'Sivas', 39.7477, 37.0179),
  _ProvinceSeed(59, 'Tekirdağ', 40.9780, 27.5110),
  _ProvinceSeed(60, 'Tokat', 40.3167, 36.5500),
  _ProvinceSeed(61, 'Trabzon', 41.0015, 39.7178),
  _ProvinceSeed(62, 'Tunceli', 39.1079, 39.5401),
  _ProvinceSeed(63, 'Şanlıurfa', 37.1674, 38.7955),
  _ProvinceSeed(64, 'Uşak', 38.6823, 29.4082),
  _ProvinceSeed(65, 'Van', 38.5012, 43.3729),
  _ProvinceSeed(66, 'Yozgat', 39.8181, 34.8147),
  _ProvinceSeed(67, 'Zonguldak', 41.4564, 31.7987),
  _ProvinceSeed(68, 'Aksaray', 38.3687, 34.0370),
  _ProvinceSeed(69, 'Bayburt', 40.2552, 40.2249),
  _ProvinceSeed(70, 'Karaman', 37.1759, 33.2287),
  _ProvinceSeed(71, 'Kırıkkale', 39.8468, 33.5153),
  _ProvinceSeed(72, 'Batman', 37.8812, 41.1351),
  _ProvinceSeed(73, 'Şırnak', 37.4187, 42.4918),
  _ProvinceSeed(74, 'Bartın', 41.6344, 32.3375),
  _ProvinceSeed(75, 'Ardahan', 41.1105, 42.7022),
  _ProvinceSeed(76, 'Iğdır', 39.9201, 44.0436),
  _ProvinceSeed(77, 'Yalova', 40.6500, 29.2667),
  _ProvinceSeed(78, 'Karabük', 41.2061, 32.6204),
  _ProvinceSeed(79, 'Kilis', 36.7184, 37.1212),
  _ProvinceSeed(80, 'Osmaniye', 37.0742, 36.2478),
  _ProvinceSeed(81, 'Düzce', 40.8438, 31.1565),
];

ParkingLocation? nearestDemoParking({
  required double latitude,
  required double longitude,
}) {
  final available =
      demoParkingLocations
          .where((parking) => parking.hasAvailableSpace)
          .map(
            (parking) => parking.withDistance(
              _distanceInKm(
                latitude,
                longitude,
                parking.latitude,
                parking.longitude,
              ),
            ),
          )
          .toList()
        ..sort(
          (first, second) => first.distanceKm!.compareTo(second.distanceKm!),
        );

  return available.isEmpty ? null : available.first;
}

double _distanceInKm(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusKm = 6371.0;
  final latitudeDelta = _toRadians(latitude2 - latitude1);
  final longitudeDelta = _toRadians(longitude2 - longitude1);
  final firstLatitude = _toRadians(latitude1);
  final secondLatitude = _toRadians(latitude2);

  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);

  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

class _ProvinceSeed {
  const _ProvinceSeed(this.plateCode, this.name, this.latitude, this.longitude);

  final int plateCode;
  final String name;
  final double latitude;
  final double longitude;
}
