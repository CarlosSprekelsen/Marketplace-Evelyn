import 'package:dio/dio.dart';

import '../../shared/models/price_quote.dart';
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

  Future<List<ServiceRequestModel>> getMyRequests() async {
    final response = await _dio.get('/service-requests/mine');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServiceRequestModel> getRequestById(String id) async {
    final response = await _dio.get('/service-requests/$id');
    return ServiceRequestModel.fromJson(response.data as Map<String, dynamic>);
  }
}
