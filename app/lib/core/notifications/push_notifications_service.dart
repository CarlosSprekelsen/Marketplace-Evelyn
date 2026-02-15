import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

  final AuthRepository _authRepository;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _lastRegisteredToken;

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

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }
    // Log the foreground notification. In a production app you would show
    // a local notification via flutter_local_notifications here.
    debugPrint('FCM foreground: ${notification.title} — ${notification.body}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Future: navigate to the relevant screen based on message.data.
    debugPrint('FCM tap: ${message.data}');
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
