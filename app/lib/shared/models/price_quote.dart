class PriceQuote {
  PriceQuote({
    required this.districtId,
    required this.districtName,
    required this.hours,
    required this.pricePerHour,
    required this.priceTotal,
    required this.currency,
  });

  final String districtId;
  final String districtName;
  final int hours;
  final double pricePerHour;
  final double priceTotal;
  final String currency;

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    final district = json['district'] as Map<String, dynamic>;
    return PriceQuote(
      districtId: district['id'] as String,
      districtName: district['name'] as String,
      hours: json['hours'] as int,
      pricePerHour: _toDouble(json['price_per_hour']),
      priceTotal: _toDouble(json['price_total']),
      currency: json['currency'] as String? ?? 'AED',
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}
