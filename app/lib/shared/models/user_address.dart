import 'district.dart';

enum AddressLabel {
  casa('CASA'),
  oficina('OFICINA'),
  otro('OTRO');

  const AddressLabel(this.value);
  final String value;

  static AddressLabel fromString(String value) {
    return AddressLabel.values.firstWhere(
      (label) => label.value == value,
      orElse: () => AddressLabel.otro,
    );
  }
}

class UserAddress {
  UserAddress({
    required this.id,
    required this.userId,
    required this.label,
    this.labelCustom,
    required this.districtId,
    required this.addressStreet,
    required this.addressNumber,
    this.addressFloorApt,
    this.addressReference,
    this.latitude,
    this.longitude,
    required this.isDefault,
    required this.createdAt,
    this.district,
  });

  final String id;
  final String userId;
  final AddressLabel label;
  final String? labelCustom;
  final String districtId;
  final String addressStreet;
  final String addressNumber;
  final String? addressFloorApt;
  final String? addressReference;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;
  final District? district;

  String get displayLabel {
    switch (label) {
      case AddressLabel.casa:
        return 'Casa';
      case AddressLabel.oficina:
        return 'Oficina';
      case AddressLabel.otro:
        return labelCustom ?? 'Otro';
    }
  }

  String get fullAddress {
    final parts = <String>[addressStreet, addressNumber];
    if (addressFloorApt != null && addressFloorApt!.isNotEmpty) {
      parts.add(addressFloorApt!);
    }
    if (addressReference != null && addressReference!.isNotEmpty) {
      parts.add(addressReference!);
    }
    return parts.join(', ');
  }

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: AddressLabel.fromString(json['label'] as String),
      labelCustom: json['label_custom'] as String?,
      districtId: json['district_id'] as String,
      addressStreet: json['address_street'] as String,
      addressNumber: json['address_number'] as String,
      addressFloorApt: json['address_floor_apt'] as String?,
      addressReference: json['address_reference'] as String?,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      district: json['district'] != null
          ? District.fromJson(json['district'] as Map<String, dynamic>)
          : null,
    );
  }
}
