/// Context processing and validation for IntelliToggle evaluations
///
/// Handles single-context, multi-context, and custom context kinds with
/// proper validation and transformation for the IntelliToggle API.
///
/// The processor transforms OpenFeature context into IntelliToggle-compatible
/// format, validating required fields and handling different context types.
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
    if (context == null || context.isEmpty) {
      throw ArgumentError('Context cannot be null or empty');
    }

    final processedContext = Map<String, dynamic>.from(context);

    // Validate that required targeting key exists
    _validateTargetingKey(processedContext);

    // Determine context kind (defaults to 'user')
    final kind = processedContext['kind'] as String? ?? 'user';
    processedContext['kind'] = kind;

    // Process based on context type
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

    // Extract each context kind from the multi-context
    context.forEach((key, value) {
      if (key != 'kind' && value is Map<String, dynamic>) {
        final contextData = Map<String, dynamic>.from(value);

        // Validate each context has required targetingKey
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

    // Prefer 'targetingKey' over legacy 'key' field
    if (attributes.containsKey('key') &&
        !attributes.containsKey('targetingKey')) {
      attributes['targetingKey'] = attributes['key'];
    }
    attributes.remove('key'); // Remove legacy field

    // Validate private attributes format
    final privateAttrs = attributes['privateAttributes'];
    if (privateAttrs != null && privateAttrs is! List<String>) {
      throw ArgumentError('privateAttributes must be a List<String>');
    }

    // Validate anonymous flag format
    final anonymous = attributes['anonymous'];
    if (anonymous != null && anonymous is! bool) {
      throw ArgumentError('anonymous must be a boolean');
    }

    // Validate name field format
    final name = attributes['name'];
    if (name != null && name is! String) {
      throw ArgumentError('name must be a string');
    }

    return attributes;
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
}
