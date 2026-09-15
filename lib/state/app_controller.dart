import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/demo_parking_data.dart';
import '../models/auth_session.dart';
import '../models/geo_point.dart';
import '../models/parking_location.dart';
import '../models/parking_reservation.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/google_services.dart';
import '../services/location_service.dart';
import '../services/offline_store.dart';
import '../services/parking_service.dart';
import '../services/push_device_service.dart';
import '../services/realtime_service.dart';
import '../services/reservation_service.dart';
import '../services/token_storage.dart';

enum AppStatus { initializing, unauthenticated, authenticated }

class AppController extends ChangeNotifier {
  AppController({
    required AuthService authService,
    required ParkingService parkingService,
    required LocationService locationService,
    required RealtimeService realtimeService,
    required ReservationService reservationService,
    required TokenStorage tokenStorage,
    required GoogleServices googleServices,
    required PushDeviceService pushDeviceService,
    required OfflineStore offlineStore,
  })  : _authService = authService,
        _parkingService = parkingService,
        _locationService = locationService,
        _realtimeService = realtimeService,
        _reservationService = reservationService,
        _tokenStorage = tokenStorage,
        _googleServices = googleServices,
        _pushDeviceService = pushDeviceService,
        _offlineStore = offlineStore {
    _pushMessageSubscription = _googleServices.messages.listen(_handlePushMessage);
    _tokenRefreshSubscription = _googleServices.tokenRefreshes.listen(
      (token) => unawaited(_registerPushToken(token)),
    );
  }

  final AuthService _authService;
  final ParkingService _parkingService;
  final LocationService _locationService;
  final RealtimeService _realtimeService;
  final ReservationService _reservationService;
  final TokenStorage _tokenStorage;
  final GoogleServices _googleServices;
  final PushDeviceService _pushDeviceService;
  final OfflineStore _offlineStore;
  late final StreamSubscription<PushMessage> _pushMessageSubscription;
  late final StreamSubscription<String> _tokenRefreshSubscription;
  String? _registeredPushToken;

  AppStatus status = AppStatus.initializing;
  AuthSession? session;
  List<ParkingLocation> parkingLocations = [];
  ParkingLocation? selectedParking;
  ParkingLocation? nearestParking;
  GeoPoint? currentLocation;
  ParkingReservation? activeReservation;
  String? errorMessage;
  bool isAuthenticating = false;
  bool isLoadingParking = false;
  bool isFindingNearest = false;
  bool isRealtimeConnected = false;
  bool isReserving = false;
  bool isPushEnabled = false;
  bool isOfflineMode = false;
  bool isSyncing = false;
  int pendingSyncCount = 0;
  PushMessage? foregroundNotification;
  int? _requestedHomeTab;

  bool get isDemoMode => session?.isDemo == true;
  bool get isAdmin => session?.isAdmin == true;
  bool get isFirebaseEnabled => _googleServices.isEnabled;
  NavigatorObserver? get analyticsObserver => _googleServices.analyticsObserver;

  Future<void> initialize() async {
    await _offlineStore.initialize();
    session = await _tokenStorage.read();
    if (session == null) {
      status = AppStatus.unauthenticated;
      notifyListeners();
      return;
    }

    parkingLocations = isDemoMode
        ? List.of(demoParkingLocations)
        : await _offlineStore.loadParking();
    activeReservation = await _offlineStore.loadReservation(_userKey);
    pendingSyncCount = await _offlineStore.pendingCount(_userKey);
    selectedParking ??= parkingLocations.cast<ParkingLocation?>().firstOrNull;
    status = AppStatus.authenticated;
    notifyListeners();

    if (isDemoMode) return;
    try {
      await refreshParking();
      await _loadActiveReservation();
      await _connectRealtime();
      await _configurePush();
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        await _tokenStorage.clear();
        session = null;
        status = AppStatus.unauthenticated;
      } else {
        isOfflineMode = true;
        errorMessage = 'Çevrimdışı mod: kayıtlı veriler gösteriliyor.';
      }
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    return _authenticate(() => _authService.login(email: email, password: password));
  }

  Future<bool> loginWithGoogle() async {
    return _authenticate(() async {
      final googleUser = await _googleServices.signInWithGoogle();
      return _authService.firebaseLogin(
        idToken: googleUser.idToken,
        email: googleUser.email,
        fullName: googleUser.fullName,
      );
    });
  }

  Future<bool> register(String fullName, String email, String password) async {
    return _authenticate(
      () => _authService.register(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> continueInDemoMode() async {
    isAuthenticating = true;
    errorMessage = null;
    notifyListeners();

    try {
      session = AuthSession.demo();
      await _tokenStorage.save(session!);
      parkingLocations = List.of(demoParkingLocations);
      activeReservation = await _offlineStore.loadReservation(_userKey);
      selectedParking = parkingLocations.first;
      isRealtimeConnected = false;
      isOfflineMode = true;
      pendingSyncCount = 0;
      status = AppStatus.authenticated;
    } catch (error) {
      session = null;
      errorMessage = _messageFor(error);
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> _authenticate(Future<AuthSession> Function() action) async {
    isAuthenticating = true;
    errorMessage = null;
    notifyListeners();

    try {
      session = await action();
      await _tokenStorage.save(session!);
      status = AppStatus.authenticated;
      isAuthenticating = false;
      notifyListeners();
      await refreshParking();
      await _loadActiveReservation();
      await _connectRealtime();
      await _configurePush();
      await _googleServices.logEvent('login_completed');
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      isAuthenticating = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshParking({bool silent = false}) async {
    if (!silent) {
      isLoadingParking = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      if (isDemoMode) {
        parkingLocations = List.of(demoParkingLocations);
        selectedParking ??= parkingLocations.first;
        return;
      }

      final token = await _accessToken();
      parkingLocations = await _parkingService.getAll(token);
      await _offlineStore.cacheParking(parkingLocations);
      isOfflineMode = false;
      selectedParking ??= parkingLocations.cast<ParkingLocation?>().firstOrNull;
      await _syncPendingActions(token);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await _tokenStorage.clear();
        session = null;
        status = AppStatus.unauthenticated;
        errorMessage = 'Oturum süresi doldu. Lütfen yeniden giriş yapın.';
        return;
      }
      if (error is ApiException && error.statusCode == null) {
        isOfflineMode = true;
      }
      final cached = await _offlineStore.loadParking();
      if (cached.isNotEmpty) {
        parkingLocations = cached;
        selectedParking ??= cached.first;
        isOfflineMode = true;
        errorMessage = 'İnternet bağlantısı yok; son kayıtlı otopark verileri gösteriliyor.';
      } else {
        errorMessage = _messageFor(error);
      }
    } finally {
      if (!silent) isLoadingParking = false;
      notifyListeners();
    }
  }

  Future<bool> findNearestParking() async {
    isFindingNearest = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentLocation = await _locationService.getCurrentLocation();
      if (isDemoMode) {
        nearestParking = nearestDemoParking(
          latitude: currentLocation!.latitude,
          longitude: currentLocation!.longitude,
        );
        if (nearestParking == null) {
          throw const ApiException('Uygun boş park yeri bulunamadı.');
        }
      } else {
        final token = await _accessToken();
        nearestParking = await _parkingService.getNearest(
          accessToken: token,
          latitude: currentLocation!.latitude,
          longitude: currentLocation!.longitude,
        );
      }
      selectedParking = nearestParking;
      await _googleServices.logEvent(
        'nearest_parking_found',
        parameters: {
          'available_spaces': nearestParking!.availableCapacity,
          'distance_km': nearestParking!.distanceKm ?? 0,
        },
      );
      isFindingNearest = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      isFindingNearest = false;
      notifyListeners();
      return false;
    }
  }

  void selectParking(ParkingLocation parking) {
    selectedParking = parking;
    unawaited(
      _googleServices.logEvent(
        'parking_selected',
        parameters: {'available_spaces': parking.availableCapacity},
      ),
    );
    notifyListeners();
  }

  Future<void> trackDirectionsOpened(ParkingLocation parking) {
    return _googleServices.logEvent(
      'directions_opened',
      parameters: {
        'available_spaces': parking.availableCapacity,
        'distance_km': parking.distanceKm ?? 0,
      },
    );
  }

  Future<bool> createReservation({
    required ParkingLocation parking,
    required String vehiclePlate,
    required int durationMinutes,
    bool requireElectric = false,
    bool requireAccessible = false,
  }) async {
    isReserving = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (isDemoMode) {
        final now = DateTime.now().toUtc();
        activeReservation = ParkingReservation(
          id: 'demo-${now.millisecondsSinceEpoch}',
          parkingLotId: parking.id,
          parkingLotName: parking.name,
          address: parking.address,
          latitude: parking.latitude,
          longitude: parking.longitude,
          parkingSpaceCode: 'DEMO-01',
          vehiclePlate: vehiclePlate.toUpperCase(),
          startTime: now,
          endTime: now.add(Duration(minutes: durationMinutes)),
          isActive: true,
          qrToken: 'demo-${parking.id}-${now.millisecondsSinceEpoch}',
          estimatedAmount: parking.hourlyRate * durationMinutes / 60,
        );
      } else {
        try {
          activeReservation = await _reservationService.create(
            accessToken: await _accessToken(),
            parkingLotId: parking.id,
            vehiclePlate: vehiclePlate,
            durationMinutes: durationMinutes,
            requireElectric: requireElectric,
            requireAccessible: requireAccessible,
          );
          isOfflineMode = false;
        } on ApiException catch (error) {
          if (error.statusCode != null) rethrow;
          final now = DateTime.now().toUtc();
          final localId = 'offline-${now.microsecondsSinceEpoch}';
          activeReservation = ParkingReservation(
            id: localId,
            parkingLotId: parking.id,
            parkingLotName: parking.name,
            address: parking.address,
            latitude: parking.latitude,
            longitude: parking.longitude,
            parkingSpaceCode: 'ONAY BEKLİYOR',
            vehiclePlate: vehiclePlate.toUpperCase(),
            startTime: now,
            endTime: now.add(Duration(minutes: durationMinutes)),
            isActive: true,
            qrToken: '',
            estimatedAmount: parking.hourlyRate * durationMinutes / 60,
            isPendingSync: true,
          );
          await _offlineStore.enqueue(_userKey, 'create_reservation', {
            'localId': localId,
            'parkingLotId': parking.id,
            'vehiclePlate': vehiclePlate,
            'durationMinutes': durationMinutes,
            'requireElectric': requireElectric,
            'requireAccessible': requireAccessible,
          });
          isOfflineMode = true;
          errorMessage = 'Rezervasyon isteği kuyruğa alındı; bağlantı gelince kesinleşecek.';
        }
      }
      await _offlineStore.cacheReservation(_userKey, activeReservation!);
      pendingSyncCount = await _offlineStore.pendingCount(_userKey);
      selectedParking = parking;
      await _googleServices.logEvent(
        'reservation_created',
        parameters: {
          'duration_minutes': durationMinutes,
          'requires_electric': requireElectric ? 1 : 0,
          'requires_accessible': requireAccessible ? 1 : 0,
        },
      );
      isReserving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      isReserving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelReservation() async {
    final reservation = activeReservation;
    if (reservation == null) return true;
    isReserving = true;
    notifyListeners();
    try {
      if (isDemoMode) {
        await _offlineStore.clearReservation(_userKey);
      } else if (reservation.isPendingSync) {
        await _offlineStore.removePendingCreate(_userKey, reservation.id);
        await _offlineStore.clearReservation(_userKey);
      } else {
        try {
          await _reservationService.cancel(await _accessToken(), reservation.id);
          isOfflineMode = false;
        } on ApiException catch (error) {
          if (error.statusCode != null) rethrow;
          await _offlineStore.enqueue(
            _userKey,
            'cancel_reservation',
            {'reservationId': reservation.id},
          );
          isOfflineMode = true;
          errorMessage = 'İptal isteği kuyruğa alındı ve bağlantı gelince gönderilecek.';
        }
        await _offlineStore.clearReservation(_userKey);
      }
      activeReservation = null;
      pendingSyncCount = await _offlineStore.pendingCount(_userKey);
      await _googleServices.logEvent('reservation_cancelled');
      isReserving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      isReserving = false;
      notifyListeners();
      return false;
    }
  }

  ParkingLocation? findParkingById(String id) {
    for (final parking in parkingLocations) {
      if (parking.id.toLowerCase() == id.toLowerCase()) return parking;
    }
    return null;
  }

  Future<void> logout() async {
    await _realtimeService.stop();
    final currentSession = session;
    final currentToken = _registeredPushToken;
    if (currentSession != null && !currentSession.isDemo && currentToken != null) {
      try {
        await _pushDeviceService.unregister(
          accessToken: await _accessToken(),
          token: currentToken,
        );
      } catch (_) {
        // Oturum kapatma, ağdaki token temizliği başarısız olsa da tamamlanır.
      }
    }
    await _googleServices.signOut();
    if (currentSession != null) {
      await _offlineStore.clearUserData(currentSession.email);
    }
    await _tokenStorage.clear();
    session = null;
    parkingLocations = [];
    selectedParking = null;
    nearestParking = null;
    currentLocation = null;
    activeReservation = null;
    isRealtimeConnected = false;
    isPushEnabled = false;
    isOfflineMode = false;
    pendingSyncCount = 0;
    _registeredPushToken = null;
    foregroundNotification = null;
    status = AppStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void dismissForegroundNotification() {
    foregroundNotification = null;
    notifyListeners();
  }

  int? takeRequestedHomeTab() {
    final requested = _requestedHomeTab;
    _requestedHomeTab = null;
    return requested;
  }

  Future<String> getAccessToken() => _accessToken();

  Future<void> syncNow() async {
    if (isDemoMode || isSyncing) return;
    isSyncing = true;
    notifyListeners();
    try {
      final token = await _accessToken();
      await _syncPendingActions(token);
      await refreshParking(silent: true);
      await _loadActiveReservation();
      isOfflineMode = false;
      errorMessage = null;
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        await _tokenStorage.clear();
        session = null;
        status = AppStatus.unauthenticated;
        errorMessage = 'Oturum süresi doldu. Lütfen yeniden giriş yapın.';
        return;
      }
      isOfflineMode = true;
      errorMessage = _messageFor(error);
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _configurePush() async {
    if (!_googleServices.isEnabled || isDemoMode || session == null) return;
    try {
      final token = await _googleServices.requestPushToken();
      if (token != null && token.isNotEmpty) await _registerPushToken(token);
      final initialMessage = _googleServices.initialPushMessage;
      if (initialMessage != null) {
        _googleServices.initialPushMessage = null;
        _handlePushMessage(initialMessage);
      }
    } catch (error, stack) {
      isPushEnabled = false;
      await _googleServices.recordError(error, stack);
      notifyListeners();
    }
  }

  Future<void> _registerPushToken(String token) async {
    if (status != AppStatus.authenticated || isDemoMode || token.isEmpty) return;
    try {
      await _pushDeviceService.register(
        accessToken: await _accessToken(),
        token: token,
      );
      _registeredPushToken = token;
      isPushEnabled = true;
      notifyListeners();
    } catch (error, stack) {
      isPushEnabled = false;
      await _googleServices.recordError(error, stack);
      notifyListeners();
    }
  }

  void _handlePushMessage(PushMessage message) {
    foregroundNotification = message;
    if (message.openedFromNotification) {
      final screen = message.data['screen']?.toString().toLowerCase();
      _requestedHomeTab = switch (screen) {
        'map' => 1,
        'parking' || 'parkings' => 2,
        'qr' || 'reservation' => 3,
        'profile' => 4,
        _ => 0,
      };
    }
    notifyListeners();
  }

  Future<String> _accessToken() async {
    final current = session;
    if (current == null) throw const ApiException('Oturum bulunamadı.');
    if (current.isDemo) return current.accessToken;
    if (!current.expiresSoon) return current.accessToken;

    session = await _authService.refresh(current);
    await _tokenStorage.save(session!);
    return session!.accessToken;
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtimeService.start(
        accessToken: await _accessToken(),
        onParkingUpdated: () => refreshParking(silent: true),
      );
      isRealtimeConnected = true;
    } catch (_) {
      isRealtimeConnected = false;
    }
    notifyListeners();
  }

  Future<void> _loadActiveReservation() async {
    try {
      activeReservation = await _reservationService.getActive(await _accessToken());
      if (activeReservation == null) {
        await _offlineStore.clearReservation(_userKey);
      } else {
        await _offlineStore.cacheReservation(_userKey, activeReservation!);
      }
    } catch (_) {
      activeReservation = await _offlineStore.loadReservation(_userKey);
    }
    notifyListeners();
  }

  Future<void> _syncPendingActions(String accessToken) async {
    if (isDemoMode) return;
    final actions = await _offlineStore.pendingActions(_userKey);
    for (final action in actions) {
      try {
        if (action.action == 'create_reservation') {
          final payload = action.payload;
          final reservation = await _reservationService.create(
            accessToken: accessToken,
            parkingLotId: payload['parkingLotId']?.toString() ?? '',
            vehiclePlate: payload['vehiclePlate']?.toString() ?? '',
            durationMinutes: _asInt(payload['durationMinutes'], 15),
            requireElectric: payload['requireElectric'] == true,
            requireAccessible: payload['requireAccessible'] == true,
          );
          activeReservation = reservation;
          await _offlineStore.cacheReservation(_userKey, reservation);
        } else if (action.action == 'cancel_reservation') {
          await _reservationService.cancel(
            accessToken,
            action.payload['reservationId']?.toString() ?? '',
          );
          await _offlineStore.clearReservation(_userKey);
          activeReservation = null;
        }
        await _offlineStore.removeAction(action.id);
      } on ApiException catch (error) {
        if (error.statusCode == null
            || error.statusCode == 401
            || error.statusCode == 429
            || (error.statusCode ?? 0) >= 500) {
          rethrow;
        }
        await _offlineStore.removeAction(action.id);
        if (action.action == 'create_reservation'
            && activeReservation?.id == action.payload['localId']?.toString()) {
          activeReservation = null;
          await _offlineStore.clearReservation(_userKey);
        }
        errorMessage = 'Bekleyen işlem sunucu tarafından reddedildi: ${error.message}';
      }
    }
    pendingSyncCount = await _offlineStore.pendingCount(_userKey);
  }

  int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String get _userKey => session?.email ?? 'anonymous';

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;
    if (error is StateError) return error.message.toString();
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  @override
  void dispose() {
    _pushMessageSubscription.cancel();
    _tokenRefreshSubscription.cancel();
    _realtimeService.stop();
    _authService.dispose();
    _parkingService.dispose();
    _reservationService.dispose();
    _pushDeviceService.dispose();
    _googleServices.dispose();
    _offlineStore.close();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
