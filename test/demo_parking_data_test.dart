import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_mobile/data/demo_parking_data.dart';

void main() {
  test('81 il demo verileri mobil uygulamada kullanılabilir', () {
    expect(demoParkingLocations, hasLength(81));
    expect(
      demoParkingLocations.map((parking) => parking.zone).toSet(),
      hasLength(81),
    );
    expect(
      demoParkingLocations.every((parking) => parking.totalCapacity > 0),
      isTrue,
    );
  });

  test('En yakın demo otoparkı mesafesiyle döner', () {
    final nearest = nearestDemoParking(latitude: 40.6504, longitude: 35.8337);

    expect(nearest, isNotNull);
    expect(nearest!.id, 'merkez-katli');
    expect(nearest.distanceKm, closeTo(0, 0.001));
  });
}
