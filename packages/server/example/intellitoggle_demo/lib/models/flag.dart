class Flag {
  final String key;
  final String name;
  final String? description;
  final String type;
  final bool enabled;
  final dynamic defaultValue;
  final List<FlagVariation> variations;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Flag({
    required this.key,
    required this.name,
    this.description,
    required this.type,
    this.enabled = true,
    this.defaultValue,
    this.variations = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Flag.fromJson(Map<String, dynamic> json) {
    // Handle both 'variations' and 'flag_variations' field names
    final variationsJson = json['flag_variations'] ?? json['variations'];

    return Flag(
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      enabled: json['enabled'] as bool? ?? true,
      defaultValue: json['defaultValue'],
      variations:
          (variationsJson as List?)
              ?.map((v) => FlagVariation.fromJson(v))
              .toList() ??
          [],
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(
        json['createdAt'] ??
            json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ??
            json['updated_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'description': description,
      'type': type,
      'enabled': enabled,
      'defaultValue': defaultValue,
      'flag_variations': variations.map((v) => v.toJson()).toList(),
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Flag{key: $key, name: $name, type: $type, enabled: $enabled}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flag && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

class FlagVariation {
  final String id;
  final String name;
  final dynamic value;

  FlagVariation({required this.id, required this.name, required this.value});

  factory FlagVariation.fromJson(Map<String, dynamic> json) {
    return FlagVariation(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'value': value};
  }

  @override
  String toString() {
    return 'FlagVariation{id: $id, name: $name, value: $value}';
  }
}
