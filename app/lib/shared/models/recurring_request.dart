class RecurringRequest {
  final String id;
  final String districtId;
  final String? districtName;
  final String addressDetail;
  final int hoursRequested;
  final int dayOfWeek; // 1=Mon..7=Sun
  final String timeOfDay; // "10:00"
  final bool isActive;
  final DateTime nextScheduledAt;
  final DateTime createdAt;

  RecurringRequest({
    required this.id,
    required this.districtId,
    this.districtName,
    required this.addressDetail,
    required this.hoursRequested,
    required this.dayOfWeek,
    required this.timeOfDay,
    required this.isActive,
    required this.nextScheduledAt,
    required this.createdAt,
  });

  factory RecurringRequest.fromJson(Map<String, dynamic> json) {
    final district = json['district'] as Map<String, dynamic>?;
    return RecurringRequest(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      districtName: district?['name'] as String?,
      addressDetail: json['address_detail'] as String,
      hoursRequested: json['hours_requested'] as int,
      dayOfWeek: json['day_of_week'] as int,
      timeOfDay: json['time_of_day'] as String,
      isActive: json['is_active'] as bool? ?? true,
      nextScheduledAt: DateTime.parse(json['next_scheduled_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static const dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  String get dayName => dayNames[dayOfWeek - 1];

  String get summary => 'Cada $dayName a las $timeOfDay';
}
