import 'dart:async';
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';

/// Convenience wrapper over OpenFeature client with IntelliToggle-specific methods
///
/// This client provides idiomatic Dart methods for flag evaluation with built-in
/// context processing and IntelliToggle-specific features like multi-context support.
///
/// Example usage:
/// ```dart
/// final client = IntelliToggleClient(featureClient);
/// final enabled = await client.getBooleanValue(
///   'my-flag',
///   false,
///   targetingKey: 'user-123',
///   evaluationContext: {'role': 'admin'},
/// );
/// ```

/// New IntelliToggle client with enhanced error handling and timeout support
class IntelliToggleClient {
  /// The underlying OpenFeature client
  final FeatureClient _client;

  /// Default timeout for flag evaluations
  Duration _timeout;

  /// Creates a new IntelliToggle client wrapper with corrected endpoints
  IntelliToggleClient(
    this._client, {
    Duration timeout = const Duration(seconds: 10),
  }) : _timeout = timeout;

  /// Evaluate a boolean flag with enhanced context processing and timeout
  ///
  /// [flagKey] - The feature flag key to evaluate
  /// [defaultValue] - Default value to return if evaluation fails
  /// [evaluationContext] - Base evaluation context map
  /// [targetingKey] - User/entity identifier for targeting (required)
  /// [kind] - Context kind (user, organization, device, etc.)
  /// [anonymous] - Whether the context is anonymous
  /// [name] - Human-readable name for the context
  /// [privateAttributes] - List of attribute names to keep private
  Future<bool> getBooleanValue(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? evaluationContext,
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) async {
    final context = _buildContext(
      evaluationContext,
      targetingKey: targetingKey,
      kind: kind,
      anonymous: anonymous,
      name: name,
      privateAttributes: privateAttributes,
    );

    final result = await _client
        .getBooleanFlag(flagKey, context: context, defaultValue: defaultValue)
        .timeout(_timeout);

    return result;
  }

  /// Evaluate a string flag with enhanced context processing and timeout
  Future<String> getStringValue(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? evaluationContext,
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) async {
    final context = _buildContext(
      evaluationContext,
      targetingKey: targetingKey,
      kind: kind,
      anonymous: anonymous,
      name: name,
      privateAttributes: privateAttributes,
    );

    final result = await _client
        .getStringFlag(flagKey, context: context, defaultValue: defaultValue)
        .timeout(_timeout);

    return result;
  }

  /// Evaluate an integer flag with enhanced context processing and timeout
  Future<int> getIntegerValue(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? evaluationContext,
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) async {
    final context = _buildContext(
      evaluationContext,
      targetingKey: targetingKey,
      kind: kind,
      anonymous: anonymous,
      name: name,
      privateAttributes: privateAttributes,
    );

    final result = await _client
        .getIntegerFlag(flagKey, context: context, defaultValue: defaultValue)
        .timeout(_timeout);

    return result;
  }

  /// Evaluate a double flag with enhanced context processing and timeout
  Future<double> getDoubleValue(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? evaluationContext,
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) async {
    final context = _buildContext(
      evaluationContext,
      targetingKey: targetingKey,
      kind: kind,
      anonymous: anonymous,
      name: name,
      privateAttributes: privateAttributes,
    );

    final result = await _client
        .getDoubleFlag(flagKey, context: context, defaultValue: defaultValue)
        .timeout(_timeout);

    return result;
  }

  /// Evaluate an object flag with enhanced context processing and timeout
  Future<Map<String, dynamic>> getObjectValue(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? evaluationContext,
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) async {
    final context = _buildContext(
      evaluationContext,
      targetingKey: targetingKey,
      kind: kind,
      anonymous: anonymous,
      name: name,
      privateAttributes: privateAttributes,
    );

    final result = await _client
        .getObjectFlag(flagKey, context: context, defaultValue: defaultValue)
        .timeout(_timeout);

    return result;
  }

  /// Build evaluation context from various sources
  ///
  /// Combines base context with additional parameters and handles IntelliToggle-specific
  /// context processing requirements.
  ///
  /// [baseContext] - Base context attributes
  /// [targetingKey] - Primary targeting identifier
  /// [kind] - Context type (user, org, device, etc.)
  /// [anonymous] - Whether context is anonymous
  /// [name] - Human-readable context name
  /// [privateAttributes] - Attributes to keep private
  EvaluationContext _buildContext(
    Map<String, dynamic>? baseContext, {
    String? targetingKey,
    String? kind,
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
  }) {
    final contextMap = Map<String, dynamic>.from(baseContext ?? {});

    if (targetingKey != null) contextMap['targetingKey'] = targetingKey;
    if (kind != null) contextMap['kind'] = kind;
    if (anonymous != null) contextMap['anonymous'] = anonymous;
    if (name != null) contextMap['name'] = name;
    if (privateAttributes != null && privateAttributes.isNotEmpty) {
      contextMap['privateAttributes'] = privateAttributes;
    }

    return EvaluationContext(attributes: contextMap);
  }

  /// Create a multi-context evaluation context
  ///
  /// Enables targeting based on multiple context kinds simultaneously
  /// (e.g., user + organization + device)
  ///
  /// [contexts] - Map of context kind to context data
  ///
  /// Example:
  /// ```dart
  /// final multiContext = client.createMultiContext({
  ///   'user': {'targetingKey': 'user-123', 'role': 'admin'},
  ///   'organization': {'targetingKey': 'org-456', 'plan': 'enterprise'},
  /// });
  /// ```
  EvaluationContext createMultiContext(
    Map<String, Map<String, dynamic>> contexts,
  ) {
    final multiContext = <String, dynamic>{'kind': 'multi'};

    for (final entry in contexts.entries) {
      final contextKind = entry.key;
      final contextData = entry.value;

      if (!contextData.containsKey('targetingKey')) {
        throw ArgumentError(
          'Context "$contextKind" must contain a targetingKey',
        );
      }

      multiContext[contextKind] = contextData;
    }

    return EvaluationContext(attributes: multiContext);
  }

  /// Create a single context of a specific kind
  ///
  /// Useful for non-user contexts like organizations, devices, etc.
  ///
  /// [targetingKey] - Required targeting identifier
  /// [kind] - Context type (defaults to 'user')
  /// [anonymous] - Whether the context is anonymous
  /// [name] - Human-readable name
  /// [privateAttributes] - Attributes to keep private
  /// [customAttributes] - Additional custom attributes
  EvaluationContext createContext({
    required String targetingKey,
    String kind = 'user',
    bool? anonymous,
    String? name,
    List<String>? privateAttributes,
    Map<String, dynamic>? customAttributes,
  }) {
    final contextMap = <String, dynamic>{
      'targetingKey': targetingKey,
      'kind': kind,
    };

    if (anonymous != null) contextMap['anonymous'] = anonymous;
    if (name != null) contextMap['name'] = name;
    if (privateAttributes != null && privateAttributes.isNotEmpty) {
      contextMap['privateAttributes'] = privateAttributes;
    }
    if (customAttributes != null) {
      contextMap.addAll(customAttributes);
    }

    return EvaluationContext(attributes: contextMap);
  }

  /// Get the underlying OpenFeature client for advanced usage
  ///
  /// Use this if you need direct access to OpenFeature client methods
  /// that aren't wrapped by IntelliToggleClient
  FeatureClient get underlyingClient => _client;

  /// Set custom timeout for evaluations
  set timeout(Duration timeout) {
    _timeout = timeout;
  }

  /// Get current timeout duration
  Duration get timeout => _timeout;
}
