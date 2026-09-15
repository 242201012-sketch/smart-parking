import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class GoogleLoginResult {
  const GoogleLoginResult({
    required this.idToken,
    required this.email,
    required this.fullName,
  });

  final String idToken;
  final String email;
  final String fullName;
}

class PushMessage {
  const PushMessage({
    required this.title,
    required this.body,
    required this.data,
    this.openedFromNotification = false,
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool openedFromNotification;

  factory PushMessage.fromRemoteMessage(
    RemoteMessage message, {
    bool openedFromNotification = false,
  }) {
    return PushMessage(
      title:
          message.notification?.title ??
          message.data['title']?.toString() ??
          'SmartParking',
      body:
          message.notification?.body ??
          message.data['body']?.toString() ??
          'Yeni bir bildiriminiz var.',
      data: Map<String, dynamic>.from(message.data),
      openedFromNotification: openedFromNotification,
    );
  }
}

class GoogleServices {
  final StreamController<PushMessage> _messages =
      StreamController<PushMessage>.broadcast();
  final StreamController<String> _tokenRefreshes =
      StreamController<String>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _googleSignInInitialized = false;

  bool isEnabled = false;
  PushMessage? initialPushMessage;

  Stream<PushMessage> get messages => _messages.stream;
  Stream<String> get tokenRefreshes => _tokenRefreshes.stream;

  FirebaseAnalyticsObserver? get analyticsObserver =>
      isEnabled && !AppConfig.familyLinkMode
      ? FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)
      : null;

  Future<void> initialize() async {
    isEnabled = await initializeFirebaseCore();
    if (!isEnabled) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final automaticCollectionEnabled = !AppConfig.familyLinkMode;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      automaticCollectionEnabled,
    );
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      automaticCollectionEnabled,
    );
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      automaticCollectionEnabled,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(
      automaticCollectionEnabled,
    );

    if (automaticCollectionEnabled) {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(
        logEvent(
          'push_received_foreground',
          parameters: {
            'has_notification': message.notification == null ? 0 : 1,
          },
        ),
      );
      _messages.add(PushMessage.fromRemoteMessage(message));
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(
        logEvent(
          'push_opened',
          parameters: {'screen': message.data['screen']?.toString() ?? 'home'},
        ),
      );
      _messages.add(
        PushMessage.fromRemoteMessage(message, openedFromNotification: true),
      );
    });
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      _tokenRefreshes.add,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      initialPushMessage = PushMessage.fromRemoteMessage(
        initialMessage,
        openedFromNotification: true,
      );
      await logEvent(
        'push_opened',
        parameters: {
          'screen': initialMessage.data['screen']?.toString() ?? 'home',
        },
      );
    }
  }

  Future<GoogleLoginResult> signInWithGoogle() async {
    if (!isEnabled) {
      throw StateError(
        'Firebase yapılandırılmadı. google-services.json dosyasını ekleyin.',
      );
    }

    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId.isEmpty
            ? null
            : AppConfig.googleWebClientId,
      );
      _googleSignInInitialized = true;
    }

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuthentication = googleUser.authentication;
      final idToken = googleAuthentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google kimlik belirteci alınamadı.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      final firebaseIdToken = await firebaseUser?.getIdToken(true);
      if (firebaseUser == null || firebaseIdToken == null) {
        throw StateError('Firebase oturumu oluşturulamadı.');
      }

      return GoogleLoginResult(
        idToken: firebaseIdToken,
        email: firebaseUser.email ?? googleUser.email,
        fullName: firebaseUser.displayName ?? googleUser.displayName ?? '',
      );
    } catch (_) {
      if (AppConfig.familyLinkMode) {
        throw StateError(
          'Google hesabı Family Link tarafından kısıtlanmış olabilir. '
          'Ebeveyn onayı verin veya e-posta/şifre ile devam edin.',
        );
      }
      rethrow;
    }
  }

  Future<String?> requestPushToken() async {
    if (!isEnabled) return null;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    if (AppConfig.familyLinkMode) {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!isEnabled || AppConfig.familyLinkMode) return;
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  Future<void> signOut() async {
    if (!isEnabled) return;
    await FirebaseAuth.instance.signOut();
    if (_googleSignInInitialized) await GoogleSignIn.instance.signOut();
  }

  Future<void> recordError(Object error, StackTrace stack) async {
    if (!isEnabled || AppConfig.familyLinkMode) return;
    await FirebaseCrashlytics.instance.recordError(error, stack);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messages.close();
    await _tokenRefreshes.close();
  }

  static Future<bool> initializeFirebaseCore() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      if (!AppConfig.hasDartFirebaseConfiguration) return false;
    }

    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final initialized = await GoogleServices.initializeFirebaseCore();
  if (!initialized || AppConfig.familyLinkMode) return;
  await FirebaseCrashlytics.instance.log(
    'Arka plan FCM mesajı alındı: ${message.messageId ?? 'kimliksiz'}',
  );
}
