/// Context processing and validation for IntelliToggle evaluations.
///
/// Handles single-context, multi-context, and custom context kinds with
/// proper validation and transformation for the IntelliToggle API.
class IntelliToggleContextProcessor {
  /// Process evaluation context for IntelliToggle API
  ///
  /// Transforms OpenFeature context into IntelliToggle-compatible format
  /// supporting single, multi, and custom context kinds.
  ///
  /// [context] - Raw context map from OpenFeature
  /// Returns processed context ready for API transmission
  /// Throws [ArgumentError] for invalid context data
  Map<String, dynamic> processContext(Map<String, dynamic>? context) {
    // Allow null or empty context
    if (context == null || context.isEmpty) {
      return {
        'kind': 'single',
        'contextKind': 'user',
        'attributes': {'targetingKey': 'anonymous', 'anonymous': true},
        'targetingKey': 'anonymous',
        'anonymous': true,
        'privateAttributes': [],
      };
    }

    // Existing logic for normal context
    final processedContext = Map<String, dynamic>.from(context);
    _validateTargetingKey(processedContext);

    final kind = processedContext['kind'] as String? ?? 'user';
    processedContext['kind'] = kind;

    if (kind == 'multi') {
      return _processMultiContext(processedContext);
    } else {
      return _processSingleContext(processedContext, kind);
    }
  }

  /// Process single context (user, organization, device, etc.)
  ///
  /// Transforms a single context into the format expected by IntelliToggle API.
  ///
  /// [context] - The context data
  /// [kind] - The context kind (user, org, device, etc.)
  /// Returns processed single context
  Map<String, dynamic> _processSingleContext(
    Map<String, dynamic> context,
    String kind,
  ) {
    final attributes = _extractContextAttributes(context);
    return {
      'kind': 'single',
      'contextKind': kind,
      'attributes': attributes,
      'targetingKey': attributes['targetingKey'],
      'anonymous': attributes['anonymous'] ?? false,
      'privateAttributes': attributes['privateAttributes'] ?? [],
    };
  }

  /// Process multi-context (multiple entities in one evaluation)
  ///
  /// Handles cases where evaluation should consider multiple context types
  /// simultaneously (e.g., user + organization + device).
  ///
  /// [context] - The multi-context data
  /// Returns processed multi-context
  Map<String, dynamic> _processMultiContext(Map<String, dynamic> context) {
    final contexts = <String, Map<String, dynamic>>{};
    context.forEach((key, value) {
      if (key != 'kind' && value is Map<String, dynamic>) {
        final contextData = Map<String, dynamic>.from(value);
        if (!contextData.containsKey('targetingKey')) {
          throw ArgumentError('Multi-context "$key" must contain targetingKey');
        }
        contexts[key] = _extractContextAttributes(contextData);
      }
    });
    if (contexts.isEmpty) {
      throw ArgumentError('Multi-context must contain at least one context');
    }
    return {'kind': 'multi', 'contexts': contexts};
  }

  /// Extract and validate context attributes
  ///
  /// Cleans up context data, validates required fields, and ensures
  /// proper formatting for API consumption.
  ///
  /// [context] - Raw context data
  /// Returns cleaned and validated attributes
  Map<String, dynamic> _extractContextAttributes(Map<String, dynamic> context) {
    final attributes = Map<String, dynamic>.from(context);
    if (attributes.containsKey('key') &&
        !attributes.containsKey('targetingKey')) {
      attributes['targetingKey'] = attributes['key'];
    }
    attributes.remove('key');
    final privateAttrs = attributes['privateAttributes'];
    if (privateAttrs != null && privateAttrs is! List<String>) {
      throw ArgumentError('privateAttributes must be a List<String>');
    }
    final anonymous = attributes['anonymous'];
    if (anonymous != null && anonymous is! bool) {
      throw ArgumentError('anonymous must be a boolean');
    }
    final name = attributes['name'];
    if (name != null && name is! String) {
      throw ArgumentError('name must be a string');
    }
    final sanitized = <String, dynamic>{};
    attributes.forEach((key, value) {
      final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      if (value is String) {
        sanitized[safeKey] = value.trim().replaceAll(
          RegExp(r'[\x00-\x1F\x7F]'),
          '',
        );
      } else if (value is num || value is bool || value == null) {
        sanitized[safeKey] = value;
      }
    });
    return sanitized;
  }

  /// Validate that context contains required targeting key
  ///
  /// Ensures that the context has either 'targetingKey' or 'key' field
  /// and that the value is a non-empty string.
  ///
  /// [context] - Context to validate
  /// Throws [ArgumentError] if targeting key is missing or invalid
  void _validateTargetingKey(Map<String, dynamic> context) {
    final hasTargetingKey = context.containsKey('targetingKey');
    final hasKey = context.containsKey('key');
    if (!hasTargetingKey && !hasKey) {
      throw ArgumentError('Context must contain a targetingKey or key');
    }
    final targetingKey = context['targetingKey'] ?? context['key'];
    if (targetingKey is! String || targetingKey.isEmpty) {
      throw ArgumentError('targetingKey must be a non-empty string');
    }
  }

  /// Called when the evaluation context changes (per spec)
  void onContextChanged(Map<String, dynamic> newContext) {
    // Per spec, process and validate new context
    processContext(newContext);
  }
}
