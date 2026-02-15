import 'package:dio/dio.dart';

import '../../shared/models/provider_available_job.dart';
import '../../shared/models/service_request_model.dart';
import '../../shared/models/user.dart';

class ProviderJobsRepository {
  ProviderJobsRepository(this._dio);

  final Dio _dio;

  Future<User> setAvailability(bool isAvailable) async {
    final response = await _dio.put(
      '/auth/availability',
      data: {'is_available': isAvailable},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ProviderAvailableJob>> getAvailableJobs() async {
    final response = await _dio.get('/service-requests/available');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => ProviderAvailableJob.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServiceRequestModel> acceptJob(String requestId) async {
    final response = await _dio.post('/service-requests/$requestId/accept');
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ServiceRequestModel>> getAssignedJobs() async {
    final response = await _dio.get('/service-requests/assigned');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServiceRequestModel> startJob(String requestId) async {
    final response = await _dio.put('/service-requests/$requestId/start');
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> completeJob(String requestId) async {
    final response = await _dio.put('/service-requests/$requestId/complete');
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> cancelJob({
    required String requestId,
    required String reason,
  }) async {
    final response = await _dio.put(
      '/service-requests/$requestId/cancel',
      data: {'cancellation_reason': reason},
    );
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }
}
