import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_mobile/models/parking_location.dart';

void main() {
  test('ParkingLocation API JSON verisini dönüştürür', () {
    final parking = ParkingLocation.fromJson({
      'id': '4b69ec41-598d-4d83-9343-1bb16b9c6ea6',
      'name': 'Merkez Otoparkı',
      'address': 'Amasya',
      'latitude': 40.65,
      'longitude': 35.83,
      'totalCapacity': 20,
      'availableCapacity': 5,
      'distanceKm': 1.25,
    });

    expect(parking.name, 'Merkez Otoparkı');
    expect(parking.hasAvailableSpace, isTrue);
    expect(parking.occupancyRatio, 0.75);
    expect(parking.distanceKm, 1.25);
  });

  test('PascalCase API alanlarını da destekler', () {
    final parking = ParkingLocation.fromJson({
      'Id': 'id-1',
      'Name': 'Test',
      'Address': 'Merkez',
      'Latitude': 1,
      'Longitude': 2,
      'TotalCapacity': 10,
      'AvailableCapacity': 0,
    });

    expect(parking.id, 'id-1');
    expect(parking.hasAvailableSpace, isFalse);
  });
}
