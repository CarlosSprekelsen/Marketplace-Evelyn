import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/api/interceptors/auth_interceptor.dart';
import '../../../core/notifications/push_notifications_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/district.dart';
import '../../../shared/models/user.dart';
import '../auth_repository.dart';
import 'auth_event_bus.dart';
import 'auth_state.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.read(secureStorageProvider));
});

final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final eventBus = ref.read(authEventBusProvider);
  final authInterceptor = AuthInterceptor(
    tokenStorage: tokenStorage,
    eventBus: eventBus,
  );
  return DioClient(interceptors: [authInterceptor]).dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((ref) {
  final service = PushNotificationsService(ref.read(authRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

final districtsProvider = FutureProvider<List<District>>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return repository.getDistricts();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.read(authRepositoryProvider),
    tokenStorage: ref.read(tokenStorageProvider),
    eventBus: ref.read(authEventBusProvider),
    pushNotificationsService: ref.read(pushNotificationsServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthRepository repository,
    required TokenStorage tokenStorage,
    required AuthEventBus eventBus,
    required PushNotificationsService pushNotificationsService,
  })  : _repository = repository,
        _tokenStorage = tokenStorage,
        _eventBus = eventBus,
        _pushNotificationsService = pushNotificationsService,
        super(AuthState.loading) {
    _eventSub = _eventBus.stream.listen((event) async {
      if (event == AuthEvent.sessionExpired) {
        await _tokenStorage.clearTokens();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          message: 'Sesion expirada. Inicia sesion nuevamente.',
        );
      }
    });
    _initialize();
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;
  final AuthEventBus _eventBus;
  final PushNotificationsService _pushNotificationsService;
  StreamSubscription<AuthEvent>? _eventSub;

  Future<void> _initialize() async {
    try {
      final accessToken = await _tokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        state = AuthState.unauthenticated;
        return;
      }

      try {
        final user = await _repository.getProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        unawaited(_pushNotificationsService.syncTokenForCurrentUser());
        return;
      } catch (_) {
        await _repository.refresh();
        final user = await _repository.getProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        unawaited(_pushNotificationsService.syncTokenForCurrentUser());
      }
    } catch (_) {
      await _tokenStorage.clearTokens();
      state = AuthState.unauthenticated;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading;
    try {
      final auth = await _repository.login(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: auth.user,
      );
      unawaited(_pushNotificationsService.syncTokenForCurrentUser());
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        message: _mapAuthError(error),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    required String districtId,
    bool acceptedTerms = true,
  }) async {
    state = AuthState.loading;
    try {
      final auth = await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
        districtId: districtId,
        acceptedTerms: acceptedTerms,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: auth.user,
      );
      unawaited(_pushNotificationsService.syncTokenForCurrentUser());
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        message: _mapAuthError(error),
      );
    }
  }

  Future<void> logout() async {
    await _pushNotificationsService.clearToken();
    await _repository.logout();
    state = AuthState.unauthenticated;
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getProfile();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      unawaited(_pushNotificationsService.syncTokenForCurrentUser());
    } catch (_) {
      // Keep current state if profile refresh fails
    }
  }

  void clearError() {
    if (state.isError) {
      state = AuthState.unauthenticated;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  String _mapAuthError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        final message = data['message'] as String;
        if (message == 'Invalid credentials') {
          return 'Credenciales invalidas.';
        }
        if (message == 'User is blocked') {
          return 'Usuario bloqueado.';
        }
        if (message == 'Invalid or expired reset token') {
          return 'Token invalido o expirado.';
        }
        return message;
      }

      if (statusCode == 401) {
        return 'Credenciales invalidas o sesion expirada.';
      }
      if (statusCode == 409) {
        return 'Este email ya esta registrado.';
      }
      if (statusCode == 400) {
        return 'Datos invalidos. Revisa los campos e intenta nuevamente.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar al servidor. Verifica tu conexion.';
      }
    }

    return 'Ocurrio un error inesperado. Intenta nuevamente.';
  }
}
