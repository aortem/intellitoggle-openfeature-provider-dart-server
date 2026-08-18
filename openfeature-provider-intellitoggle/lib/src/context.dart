/// Converts OpenFeature evaluation context into IntelliToggle's v1 evaluation
/// request body.
class IntelliToggleContextProcessor {
  /// Produces a JSON-compatible, top-level context map.
  ///
  /// IntelliToggle evaluates `environment`, `userId`, `sessionId`, `segments`,
  /// and custom attributes from the request body itself. Private attributes are
  /// removed before transmission. Empty contexts are valid and evaluate the
  /// flag's default value.
  Map<String, dynamic> processContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return <String, dynamic>{};

    final processed = _sanitizeMap(context);
    if (processed.containsKey('key') &&
        !processed.containsKey('targetingKey')) {
      processed['targetingKey'] = processed['key'];
    }
    processed.remove('key');

    final targetingKey = processed['targetingKey'];
    if (targetingKey != null &&
        (targetingKey is! String || targetingKey.trim().isEmpty)) {
      throw ArgumentError('targetingKey must be a non-empty string');
    }

    final privateAttributes = processed.remove('privateAttributes');
    if (privateAttributes != null) {
      if (privateAttributes is! List ||
          privateAttributes.any((attribute) => attribute is! String)) {
        throw ArgumentError('privateAttributes must be a list of strings');
      }
      for (final attribute in privateAttributes.cast<String>()) {
        processed.remove(attribute);
      }
    }

    return processed;
  }

  Map<String, dynamic> _sanitizeMap(Map<dynamic, dynamic> value) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (key.isEmpty || RegExp(r'[\x00-\x1F\x7F]').hasMatch(key)) {
        throw ArgumentError('Context attribute names must be non-empty');
      }
      result[key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is bool || value is num) return value;
    if (value is String) {
      return value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    }
    if (value is List) {
      return value.map<dynamic>(_sanitizeValue).toList(growable: false);
    }
    if (value is Map) return _sanitizeMap(value);
    throw ArgumentError(
      'Context values must be JSON-compatible; got ${value.runtimeType}',
    );
  }

  /// Validates a new provider context using the same wire rules.
  void onContextChanged(Map<String, dynamic> newContext) {
    processContext(newContext);
  }
}
