import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/google_services.dart';
import 'services/location_service.dart';
import 'services/offline_store.dart';
import 'services/parking_service.dart';
import 'services/push_device_service.dart';
import 'services/realtime_service.dart';
import 'services/reservation_service.dart';
import 'services/token_storage.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final googleServices = GoogleServices();
  await googleServices.initialize();

  final controller = AppController(
    authService: AuthService(),
    parkingService: ParkingService(),
    locationService: LocationService(),
    realtimeService: RealtimeService(),
    reservationService: ReservationService(),
    tokenStorage: TokenStorage(),
    googleServices: googleServices,
    pushDeviceService: PushDeviceService(),
    offlineStore: OfflineStore(),
  );

  runApp(SmartParkingApp(controller: controller));
  controller.initialize();
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartParking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorObservers: [
        if (controller.analyticsObserver case final observer?) observer,
      ],
      home: _AppGate(controller: controller),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return switch (controller.status) {
          AppStatus.initializing => const SplashScreen(),
          AppStatus.unauthenticated => LoginScreen(controller: controller),
          AppStatus.authenticated => HomeScreen(controller: controller),
        };
      },
    );
  }
}
