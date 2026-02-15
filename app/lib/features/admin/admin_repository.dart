import 'package:dio/dio.dart';

import '../../shared/models/service_request_model.dart';
import '../../shared/models/user.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<List<User>> getUsers({UserRole? role}) async {
    final response = await _dio.get(
      '/admin/users',
      queryParameters: {
        if (role != null) 'role': role.value,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<User> setUserVerified(String userId, bool isVerified) async {
    final response = await _dio.patch(
      '/admin/users/$userId/verify',
      data: {'is_verified': isVerified},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> setUserBlocked(String userId, bool isBlocked) async {
    final response = await _dio.patch(
      '/admin/users/$userId/block',
      data: {'is_blocked': isBlocked},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ServiceRequestModel>> getServiceRequests() async {
    final response = await _dio.get('/admin/service-requests');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServiceRequestModel> setServiceRequestStatus(
    String requestId,
    ServiceRequestStatus status, {
    String? cancellationReason,
  }) async {
    final response = await _dio.patch(
      '/admin/service-requests/$requestId/status',
      data: {
        'status': status.value,
        if (cancellationReason != null && cancellationReason.isNotEmpty)
          'cancellation_reason': cancellationReason,
      },
    );
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }
}
