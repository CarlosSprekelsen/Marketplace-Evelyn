import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/auth_repository.dart';

class PushNotificationsService {
  PushNotificationsService(this._authRepository);

  final AuthRepository _authRepository;
  StreamSubscription<String>? _tokenRefreshSubscription;
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
    } catch (error) {
      debugPrint('Push notifications setup skipped: $error');
    }
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
  }
}
