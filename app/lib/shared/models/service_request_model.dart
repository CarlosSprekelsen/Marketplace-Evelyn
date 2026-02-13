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
    required this.addressDetail,
    required this.hoursRequested,
    required this.priceTotal,
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
    this.provider,
    this.district,
  });

  final String id;
  final String clientId;
  final String? providerId;
  final String districtId;
  final String addressDetail;
  final int hoursRequested;
  final double priceTotal;
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
  final User? provider;
  final District? district;

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      providerId: json['provider_id'] as String?,
      districtId: json['district_id'] as String,
      addressDetail: json['address_detail'] as String,
      hoursRequested: json['hours_requested'] as int,
      priceTotal: _toDouble(json['price_total']),
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
      provider: json['provider'] != null ? User.fromJson(json['provider'] as Map<String, dynamic>) : null,
      district:
          json['district'] != null ? District.fromJson(json['district'] as Map<String, dynamic>) : null,
    );
  }
}

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
