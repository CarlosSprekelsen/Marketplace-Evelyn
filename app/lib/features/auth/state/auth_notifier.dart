import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/api/interceptors/auth_interceptor.dart';
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

final districtsProvider = FutureProvider<List<District>>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return repository.getDistricts();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.read(authRepositoryProvider),
    tokenStorage: ref.read(tokenStorageProvider),
    eventBus: ref.read(authEventBusProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthRepository repository,
    required TokenStorage tokenStorage,
    required AuthEventBus eventBus,
  })  : _repository = repository,
        _tokenStorage = tokenStorage,
        _eventBus = eventBus,
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
        return;
      } catch (_) {
        await _repository.refresh();
        final user = await _repository.getProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
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
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: auth.user,
      );
    } catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        message: _mapAuthError(error),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState.unauthenticated;
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getProfile();
      state = AuthState(status: AuthStatus.authenticated, user: user);
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
        return data['message'] as String;
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
