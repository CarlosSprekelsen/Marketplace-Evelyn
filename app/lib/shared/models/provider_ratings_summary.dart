class ProviderRating {
  ProviderRating({
    required this.id,
    required this.serviceRequestId,
    required this.clientId,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String serviceRequestId;
  final String clientId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  factory ProviderRating.fromJson(Map<String, dynamic> json) {
    return ProviderRating(
      id: json['id'] as String,
      serviceRequestId: json['service_request_id'] as String,
      clientId: json['client_id'] as String,
      stars: json['stars'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProviderRatingsSummary {
  ProviderRatingsSummary({
    required this.providerId,
    required this.averageStars,
    required this.totalRatings,
    required this.ratings,
  });

  final String providerId;
  final double averageStars;
  final int totalRatings;
  final List<ProviderRating> ratings;

  factory ProviderRatingsSummary.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'] as List<dynamic>? ?? const [];

    return ProviderRatingsSummary(
      providerId: json['provider_id'] as String,
      averageStars: _toDouble(json['average_stars']),
      totalRatings: json['total_ratings'] as int,
      ratings: rawRatings
          .map((item) => ProviderRating.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}
