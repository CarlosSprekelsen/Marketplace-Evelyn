import 'package:dio/dio.dart';

import '../../../shared/models/user_address.dart';

class AddressesRepository {
  AddressesRepository(this._dio);

  final Dio _dio;

  Future<List<UserAddress>> getMyAddresses() async {
    final response = await _dio.get('/user-addresses');
    final raw = response.data;

    final list = switch (raw) {
      List<dynamic> values => values,
      Map<String, dynamic> values when values['data'] is List<dynamic> =>
        values['data'] as List<dynamic>,
      _ => const <dynamic>[],
    };

    return list
        .whereType<Map<String, dynamic>>()
        .map(UserAddress.fromJson)
        .toList(growable: false);
  }

  Future<UserAddress> createAddress({
    required String label,
    String? labelCustom,
    required String districtId,
    required String addressStreet,
    required String addressNumber,
    String? addressFloorApt,
    String? addressReference,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final payload = <String, dynamic>{
      'label': label,
      'label_custom': labelCustom,
      'district_id': districtId,
      'address_street': addressStreet,
      'address_number': addressNumber,
      'address_floor_apt': addressFloorApt,
      'address_reference': addressReference,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    }..removeWhere((key, value) => value == null);

    final response = await _dio.post('/user-addresses', data: payload);
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserAddress> updateAddress({
    required String id,
    String? label,
    String? labelCustom,
    String? districtId,
    String? addressStreet,
    String? addressNumber,
    String? addressFloorApt,
    String? addressReference,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final payload = <String, dynamic>{
      'label': label,
      'label_custom': labelCustom,
      'district_id': districtId,
      'address_street': addressStreet,
      'address_number': addressNumber,
      'address_floor_apt': addressFloorApt,
      'address_reference': addressReference,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    }..removeWhere((key, value) => value == null);

    final response = await _dio.put('/user-addresses/$id', data: payload);
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete('/user-addresses/$id');
  }

  Future<UserAddress> setDefault(String id) async {
    final response = await _dio.patch('/user-addresses/$id/default');
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }
}
