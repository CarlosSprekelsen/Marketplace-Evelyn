import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/auth/auth_repository.dart';

/// Top-level handler required for background messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint('FCM background message: ${message.messageId}');
}

class PushNotificationsService {
  PushNotificationsService(this._authRepository);

  static const AndroidNotificationChannel _foregroundChannel = AndroidNotificationChannel(
    'homely_foreground_channel',
    'Homely Foreground Notifications',
    description: 'Visible alerts while the app is open.',
    importance: Importance.high,
  );

  final AuthRepository _authRepository;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _lastRegisteredToken;
  bool _localNotificationsInitialized = false;

  bool get _isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> syncTokenForCurrentUser() async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await _ensureLocalNotificationsInitialized();

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty && token != _lastRegisteredToken) {
        await _authRepository.setFcmToken(token);
        _lastRegisteredToken = token;
      }

      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty || newToken == _lastRegisteredToken) {
          return;
        }
        try {
          await _authRepository.setFcmToken(newToken);
          _lastRegisteredToken = newToken;
        } catch (error) {
          debugPrint('FCM token refresh sync failed: $error');
        }
      });

      // Register background message handler (idempotent — safe to call multiple times).
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for foreground messages so the app can react while open.
      _foregroundMessageSubscription ??=
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps that open the app from background/terminated state.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if the app was opened from a terminated state via a notification.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (error) {
      debugPrint('Push notifications setup skipped: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    debugPrint('FCM foreground: $title — $body');

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title.isEmpty ? 'Homely' : title,
      body.isEmpty ? 'Nueva notificacion disponible.' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _foregroundChannel.id,
          _foregroundChannel.name,
          channelDescription: _foregroundChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Future: navigate to the relevant screen based on message.data.
    debugPrint('FCM tap: ${message.data}');
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tap payload: ${response.payload}');
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_foregroundChannel);
      await androidPlugin?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      final iosPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _localNotificationsInitialized = true;
  }

  Future<void> clearToken() async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      await _authRepository.clearFcmToken();
      _lastRegisteredToken = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Failed to clear FCM token: $error');
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
  }
}
