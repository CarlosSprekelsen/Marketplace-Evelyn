import 'district.dart';
import 'user.dart';

enum ServiceRequestStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  expired('EXPIRED');

  const ServiceRequestStatus(this.value);
  final String value;

  static ServiceRequestStatus fromString(String value) {
    return ServiceRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ServiceRequestStatus.pending,
    );
  }
}

class ServiceRequestModel {
  ServiceRequestModel({
    required this.id,
    required this.clientId,
    this.providerId,
    required this.districtId,
    required this.addressStreet,
    required this.addressNumber,
    this.addressFloorApt,
    this.addressReference,
    this.addressLatitude,
    this.addressLongitude,
    required this.hoursRequested,
    required this.priceTotal,
    required this.currency,
    required this.scheduledAt,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.client,
    this.provider,
    this.district,
  });

  final String id;
  final String clientId;
  final String? providerId;
  final String districtId;
  final String addressStreet;
  final String addressNumber;
  final String? addressFloorApt;
  final String? addressReference;
  final double? addressLatitude;
  final double? addressLongitude;
  final int hoursRequested;
  final double priceTotal;
  final String currency;
  final DateTime scheduledAt;
  final ServiceRequestStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final User? client;
  final User? provider;
  final District? district;

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

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      providerId: json['provider_id'] as String?,
      districtId: json['district_id'] as String,
      addressStreet: json['address_street'] as String? ?? '',
      addressNumber: json['address_number'] as String? ?? '',
      addressFloorApt: json['address_floor_apt'] as String?,
      addressReference: json['address_reference'] as String?,
      addressLatitude: json['address_latitude'] != null
          ? double.tryParse(json['address_latitude'].toString())
          : null,
      addressLongitude: json['address_longitude'] != null
          ? double.tryParse(json['address_longitude'].toString())
          : null,
      hoursRequested: json['hours_requested'] as int,
      priceTotal: _toDouble(json['price_total']),
      currency: json['currency'] as String? ?? 'AED',
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: ServiceRequestStatus.fromString(json['status'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      acceptedAt: _parseDateTime(json['accepted_at']),
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      client: json['client'] != null
          ? User.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      provider: json['provider'] != null
          ? User.fromJson(json['provider'] as Map<String, dynamic>)
          : null,
      district: json['district'] != null
          ? District.fromJson(json['district'] as Map<String, dynamic>)
          : null,
    );
  }
}

String formatPrice(double amount, [String currency = 'AED']) =>
    '$currency ${amount.toStringAsFixed(2)}';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}
