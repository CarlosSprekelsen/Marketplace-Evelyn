class District {
  final String id;
  final String name;
  final bool isActive;
  final bool hasActiveProviders;

  District({
    required this.id,
    required this.name,
    required this.isActive,
    required this.hasActiveProviders,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      hasActiveProviders: json['has_active_providers'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'has_active_providers': hasActiveProviders,
    };
  }
}
