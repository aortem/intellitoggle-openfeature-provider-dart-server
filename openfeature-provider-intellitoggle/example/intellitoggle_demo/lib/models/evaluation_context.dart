class EvaluationContext {
  final String? targetingKey;
  final String? kind;
  final Map<String, dynamic> attributes;

  EvaluationContext({
    this.targetingKey,
    this.kind,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};

  factory EvaluationContext.user({
    required String userId,
    String? email,
    String? role,
    String? plan,
    Map<String, dynamic>? customAttributes,
  }) {
    return EvaluationContext(
      targetingKey: userId,
      kind: 'user',
      attributes: {
        'email': email,
        'role': role,
        'plan': plan,
        ...?customAttributes,
      }..removeWhere((key, value) => value == null),
    );
  }

  factory EvaluationContext.organization({
    required String orgId,
    String? name,
    String? tier,
    String? industry,
    Map<String, dynamic>? customAttributes,
  }) {
    return EvaluationContext(
      targetingKey: orgId,
      kind: 'organization',
      attributes: {
        'name': name,
        'tier': tier,
        'industry': industry,
        ...?customAttributes,
      }..removeWhere((key, value) => value == null),
    );
  }

  factory EvaluationContext.device({
    required String deviceId,
    String? os,
    String? version,
    String? region,
    Map<String, dynamic>? customAttributes,
  }) {
    return EvaluationContext(
      targetingKey: deviceId,
      kind: 'device',
      attributes: {
        'os': os,
        'version': version,
        'region': region,
        ...?customAttributes,
      }..removeWhere((key, value) => value == null),
    );
  }

  factory EvaluationContext.multi({
    EvaluationContext? user,
    EvaluationContext? organization,
    EvaluationContext? device,
  }) {
    final attributes = <String, dynamic>{};

    if (user != null) {
      attributes['user'] = {
        'targetingKey': user.targetingKey,
        ...user.attributes,
      };
    }

    if (organization != null) {
      attributes['organization'] = {
        'targetingKey': organization.targetingKey,
        ...organization.attributes,
      };
    }

    if (device != null) {
      attributes['device'] = {
        'targetingKey': device.targetingKey,
        ...device.attributes,
      };
    }

    return EvaluationContext(kind: 'multi', attributes: attributes);
  }

  EvaluationContext copyWith({
    String? targetingKey,
    String? kind,
    Map<String, dynamic>? attributes,
  }) {
    return EvaluationContext(
      targetingKey: targetingKey ?? this.targetingKey,
      kind: kind ?? this.kind,
      attributes: attributes ?? Map.from(this.attributes),
    );
  }

  EvaluationContext addAttribute(String key, dynamic value) {
    return copyWith(attributes: {...attributes, key: value});
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (targetingKey != null) json['targetingKey'] = targetingKey;
    if (kind != null) json['kind'] = kind;
    json.addAll(attributes);

    return json;
  }

  factory EvaluationContext.fromJson(Map<String, dynamic> json) {
    final targetingKey = json['targetingKey'] as String?;
    final kind = json['kind'] as String?;

    final attributes = Map<String, dynamic>.from(json);
    attributes.remove('targetingKey');
    attributes.remove('kind');

    return EvaluationContext(
      targetingKey: targetingKey,
      kind: kind,
      attributes: attributes,
    );
  }

  @override
  String toString() {
    return 'EvaluationContext{targetingKey: $targetingKey, kind: $kind, attributes: $attributes}';
  }
}
