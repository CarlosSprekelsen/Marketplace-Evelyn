class District {
  final String id;
  final String name;
  final bool isActive;

  District({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
    };
  }
}
