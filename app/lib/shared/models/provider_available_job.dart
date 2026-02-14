class ProviderAvailableJob {
  ProviderAvailableJob({
    required this.id,
    required this.districtName,
    required this.hoursRequested,
    required this.priceTotal,
    required this.scheduledAt,
    required this.expiresAt,
    required this.timeRemainingSeconds,
  });

  final String id;
  final String districtName;
  final int hoursRequested;
  final double priceTotal;
  final DateTime scheduledAt;
  final DateTime expiresAt;
  final int timeRemainingSeconds;

  factory ProviderAvailableJob.fromJson(Map<String, dynamic> json) {
    return ProviderAvailableJob(
      id: json['id'] as String,
      districtName: json['district_name'] as String,
      hoursRequested: json['hours_requested'] as int,
      priceTotal: _toDouble(json['price_total']),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      timeRemainingSeconds: json['time_remaining_seconds'] as int,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}
