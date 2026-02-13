import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/storage/token_storage.dart';
import '../../../shared/models/auth_response.dart';
import '../../../config/environment.dart';
import '../../../features/auth/state/auth_event_bus.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required AuthEventBus eventBus,
  })  : _tokenStorage = tokenStorage,
        _eventBus = eventBus,
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: Environment.apiBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  final TokenStorage _tokenStorage;
  final AuthEventBus _eventBus;
  final Dio _refreshDio;
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = request.extra['retried'] == true;
    final isRefreshRequest = request.path.endsWith('/auth/refresh');

    if (!isUnauthorized || alreadyRetried || isRefreshRequest) {
      handler.next(err);
      return;
    }

    final newAccessToken = await _refreshAccessToken();
    if (newAccessToken == null) {
      handler.next(err);
      return;
    }

    final retryRequest = request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer $newAccessToken',
      },
      extra: {
        ...request.extra,
        'retried': true,
      },
    );

    try {
      final retryResponse = await _refreshDio.fetch(retryRequest);
      handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _handleSessionExpired();
        _refreshCompleter!.complete(null);
        return _refreshCompleter!.future;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final refreshed = RefreshResponse.fromJson(response.data as Map<String, dynamic>);
      await _tokenStorage.saveTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
      );

      _refreshCompleter!.complete(refreshed.accessToken);
      return _refreshCompleter!.future;
    } catch (_) {
      await _handleSessionExpired();
      _refreshCompleter!.complete(null);
      return _refreshCompleter!.future;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clearTokens();
    _eventBus.emit(AuthEvent.sessionExpired);
  }
}
