import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';

class RealtimeService {
  HubConnection? _connection;

  Future<void> start({
    required String accessToken,
    required void Function() onParkingUpdated,
  }) async {
    await stop();

    final options = HttpConnectionOptions(
      accessTokenFactory: () async => accessToken,
    );
    final connection = HubConnectionBuilder()
        .withUrl(AppConfig.parkingHubUrl, options: options)
        .withAutomaticReconnect()
        .build();

    connection.on('ParkingStatusUpdated', (_) => onParkingUpdated());
    connection.on('ParkingLotUpdated', (_) => onParkingUpdated());
    connection.on('ParkingSpaceUpdated', (_) => onParkingUpdated());
    connection.on('ParkingLotRefreshRequested', (_) => onParkingUpdated());
    await connection.start();
    _connection = connection;
  }

  Future<void> stop() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) await connection.stop();
  }
}
