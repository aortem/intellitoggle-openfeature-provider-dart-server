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
class IntelliToggleClient {
  /// The underlying OpenFeature client
  final FeatureClient _client;

  /// Creates a new IntelliToggle client wrapper
  ///
  /// [_client] - The OpenFeature FeatureClient to wrap
  IntelliToggleClient(this._client);

  /// Evaluate a boolean flag with enhanced context processing
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
    return await _client.getBooleanFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );
  }

  /// Evaluate a string flag with enhanced context processing
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
    return await _client.getStringFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );
  }

  /// Evaluate an integer flag with enhanced context processing
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
    return await _client.getIntegerFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );
  }

  /// Evaluate a double flag with enhanced context processing
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
    return await _client.getDoubleFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );
  }

  /// Evaluate an object flag with enhanced context processing
  ///
  /// Returns a Map<String, dynamic> object based on flag configuration
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
    return await _client.getObjectFlag(
      flagKey,
      context: context,
      defaultValue: defaultValue,
    );
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

    // Add direct parameters, overriding base context if provided
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

    // Validate and add each context kind
    for (final entry in contexts.entries) {
      final contextKind = entry.key;
      final contextData = entry.value;

      // Ensure each context has a targetingKey
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

    // Add optional standard attributes
    if (anonymous != null) contextMap['anonymous'] = anonymous;
    if (name != null) contextMap['name'] = name;
    if (privateAttributes != null && privateAttributes.isNotEmpty) {
      contextMap['privateAttributes'] = privateAttributes;
    }

    // Add custom attributes
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
}
