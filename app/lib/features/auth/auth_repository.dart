import 'package:dio/dio.dart';

import '../../core/storage/token_storage.dart';
import '../../shared/models/auth_response.dart';
import '../../shared/models/district.dart';
import '../../shared/models/user.dart';

class AuthRepository {
  AuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    required String districtId,
    bool acceptedTerms = true,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role.value,
        'district_id': districtId,
        'accepted_terms': acceptedTerms,
      },
    );

    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _tokenStorage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth;
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await _dio.post(
      '/auth/forgot-password',
      data: {
        'email': email,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/forgot-password'),
        message: 'Unexpected forgot-password response format',
      );
    }

    return data.cast<String, dynamic>();
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _dio.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'reset_token': resetToken,
        'new_password': newPassword,
      },
    );
  }

  Future<RefreshResponse> refresh({String? refreshToken}) async {
    final token = refreshToken ?? await _tokenStorage.getRefreshToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        message: 'No refresh token found',
      );
    }

    final response = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': token},
    );

    final refreshed = RefreshResponse.fromJson(response.data as Map<String, dynamic>);
    await _tokenStorage.saveTokens(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
    );
    return refreshed;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  Future<User> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setFcmToken(String token) async {
    await _dio.put(
      '/auth/fcm-token',
      data: {'fcm_token': token},
    );
  }

  Future<void> clearFcmToken() async {
    await _dio.delete('/auth/fcm-token');
  }

  Future<List<District>> getDistricts() async {
    final response = await _dio.get('/districts');
    final data = response.data;
    if (data is! List) {
      throw DioException(
        requestOptions: RequestOptions(path: '/districts'),
        message: 'Unexpected districts response format',
      );
    }

    return data
        .map((item) => District.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
