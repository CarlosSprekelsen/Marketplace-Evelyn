import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/service_request_model.dart';
import '../../auth/state/auth_notifier.dart';
import '../provider_jobs_repository.dart';

final providerJobsRepositoryProvider = Provider<ProviderJobsRepository>((ref) {
  final dio = ref.read(dioProvider);
  return ProviderJobsRepository(dio);
});

final assignedJobsProvider = FutureProvider<List<ServiceRequestModel>>((ref) async {
  final repository = ref.read(providerJobsRepositoryProvider);
  return repository.getAssignedJobs();
});

String mapProviderError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'No se pudo conectar al servidor. Verifica tu conexion.';
      default:
        break;
    }
  }

  return 'Ocurrio un error inesperado. Intenta nuevamente.';
}
