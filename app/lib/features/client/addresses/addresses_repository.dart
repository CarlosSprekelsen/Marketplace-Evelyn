import 'package:dio/dio.dart';

import '../../../shared/models/user_address.dart';

class AddressesRepository {
  AddressesRepository(this._dio);

  final Dio _dio;

  Future<List<UserAddress>> getMyAddresses() async {
    final response = await _dio.get('/user-addresses');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => UserAddress.fromJson(item as Map<String, dynamic>))
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
    final response = await _dio.post(
      '/user-addresses',
      data: {
        'label': label,
        if (labelCustom != null) 'label_custom': labelCustom,
        'district_id': districtId,
        'address_street': addressStreet,
        'address_number': addressNumber,
        if (addressFloorApt != null) 'address_floor_apt': addressFloorApt,
        if (addressReference != null) 'address_reference': addressReference,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'is_default': isDefault,
      },
    );
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
    bool? isDefault,
  }) async {
    final response = await _dio.put(
      '/user-addresses/$id',
      data: {
        if (label != null) 'label': label,
        if (labelCustom != null) 'label_custom': labelCustom,
        if (districtId != null) 'district_id': districtId,
        if (addressStreet != null) 'address_street': addressStreet,
        if (addressNumber != null) 'address_number': addressNumber,
        if (addressFloorApt != null) 'address_floor_apt': addressFloorApt,
        if (addressReference != null) 'address_reference': addressReference,
        if (isDefault != null) 'is_default': isDefault,
      },
    );
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
