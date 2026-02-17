import 'package:dio/dio.dart';

import '../../shared/models/price_quote.dart';
import '../../shared/models/provider_ratings_summary.dart';
import '../../shared/models/recurring_request.dart';
import '../../shared/models/service_request_model.dart';

class ClientRequestsRepository {
  ClientRequestsRepository(this._dio);

  final Dio _dio;

  Future<PriceQuote> getQuote({
    required String districtId,
    required int hours,
  }) async {
    final response = await _dio.get(
      '/pricing/quote',
      queryParameters: {
        'district_id': districtId,
        'hours': hours,
      },
    );
    return PriceQuote.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> createRequest({
    required String districtId,
    required String addressDetail,
    required int hoursRequested,
    required DateTime scheduledAtLocal,
  }) async {
    final response = await _dio.post(
      '/service-requests',
      data: {
        'district_id': districtId,
        'address_detail': addressDetail,
        'hours_requested': hoursRequested,
        'scheduled_at': scheduledAtLocal.toUtc().toIso8601String(),
      },
    );
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ServiceRequestModel>> getMyRequests({String? status}) async {
    final queryParameters = <String, dynamic>{
      'status': status,
    }..removeWhere((_, value) => value == null);

    final response = await _dio.get(
      '/service-requests/mine',
      queryParameters: queryParameters,
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServiceRequestModel> getRequestById(String id) async {
    final response = await _dio.get('/service-requests/$id');
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServiceRequestModel> cancelRequest({
    required String requestId,
    required String reason,
  }) async {
    final response = await _dio.put(
      '/service-requests/$requestId/cancel',
      data: {'cancellation_reason': reason},
    );
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitRating({
    required String requestId,
    required int stars,
    String? comment,
  }) async {
    await _dio.post(
      '/service-requests/$requestId/rating',
      data: {
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  Future<ProviderRatingsSummary> getProviderRatings(String providerId) async {
    final response = await _dio.get('/providers/$providerId/ratings');
    return ProviderRatingsSummary.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Recurring requests ---

  Future<RecurringRequest> createRecurringRequest({
    required String districtId,
    required String addressDetail,
    required int hoursRequested,
    required int dayOfWeek,
    required String timeOfDay,
  }) async {
    final response = await _dio.post(
      '/recurring-requests',
      data: {
        'district_id': districtId,
        'address_detail': addressDetail,
        'hours_requested': hoursRequested,
        'day_of_week': dayOfWeek,
        'time_of_day': timeOfDay,
      },
    );
    return RecurringRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RecurringRequest>> getMyRecurringRequests() async {
    final response = await _dio.get('/recurring-requests/mine');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => RecurringRequest.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> cancelRecurringRequest(String id) async {
    await _dio.delete('/recurring-requests/$id');
  }
}
