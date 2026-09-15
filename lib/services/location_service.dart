import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import 'api_exception.dart';

class LocationService {
  Future<GeoPoint> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('Konum servisi kapalı. Telefon ayarlarından GPS’i açın.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const ApiException('En yakın otopark için konum izni gereklidir.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Konum izni kalıcı olarak reddedildi. Uygulama ayarlarından izin verin.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(position.latitude, position.longitude);
  }
}
