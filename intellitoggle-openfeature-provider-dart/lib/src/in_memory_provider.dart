import 'dart:async';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'events.dart';

/// An in-memory feature flag provider for testing and local development.
///
/// This provider allows you to set, update, and remove feature flags at runtime,
/// storing them in a simple in-memory map. It is useful for unit tests and local
/// development scenarios where you want to quickly change flag values without
/// external dependencies.
///
/// Whenever the flag configuration changes, a PROVIDER_CONFIGURATION_CHANGED event
/// is emitted via the [events] stream.
class InMemoryProvider implements FeatureProvider {
  /// Internal map storing flag keys and their values.
  final Map<String, dynamic> _flags = {};

  /// Stream controller for emitting provider events.
  final StreamController<IntelliToggleEvent> _eventController =
      StreamController<IntelliToggleEvent>.broadcast();

  /// Current state of the provider.
  ProviderState _state = ProviderState.NOT_READY;

  @override
  String get name => 'InMemoryProvider';

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => ProviderConfig();

  /// Set or update a flag value.
  ///
  /// [key] is the flag key, [value] is the flag value (any type).
  /// Emits a configuration changed event.
  void setFlag(String key, dynamic value) {
    _flags[key] = value;
    _emitConfigChanged();
  }

  /// Remove a flag by key.
  ///
  /// Emits a configuration changed event.
  void removeFlag(String key) {
    _flags.remove(key);
    _emitConfigChanged();
  }

  /// Clear all flags.
  ///
  /// Emits a configuration changed event.
  void clearFlags() {
    _flags.clear();
    _emitConfigChanged();
  }

  /// Emit a PROVIDER_CONFIGURATION_CHANGED event to listeners.
  void _emitConfigChanged() {
    _eventController.add(IntelliToggleEvent.configurationChanged(_flags.keys.toList()));
  }

  /// Listen to provider events (e.g., configuration changed).
  Stream<IntelliToggleEvent> get events => _eventController.stream;

  @override
  Future<void> initialize([Map<String, dynamic>? context]) async {
    _state = ProviderState.READY;
    print('[InMemoryProvider] Initialized, state = $_state');
    await Future.delayed(Duration.zero);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {
    _state = ProviderState.NOT_READY;
    await _eventController.close();
  }

  /// Resolve a boolean flag.
  ///
  /// Returns the flag value if present and a bool, otherwise returns [defaultValue].
  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = _flags[flagKey];
    return FlagEvaluationResult<bool>(
      flagKey: flagKey,
      value: value is bool ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: value != null ? 'STATIC' : 'DEFAULT',
    );
  }

  /// Resolve a string flag.
  ///
  /// Returns the flag value if present and a string, otherwise returns [defaultValue].
  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = _flags[flagKey];
    return FlagEvaluationResult<String>(
      flagKey: flagKey,
      value: value is String ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: value != null ? 'STATIC' : 'DEFAULT',
    );
  }

  /// Resolve an integer flag.
  ///
  /// Returns the flag value if present and an int, otherwise returns [defaultValue].
  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = _flags[flagKey];
    return FlagEvaluationResult<int>(
      flagKey: flagKey,
      value: value is int ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: value != null ? 'STATIC' : 'DEFAULT',
    );
  }

  /// Resolve a double flag.
  ///
  /// Returns the flag value if present and a double, otherwise returns [defaultValue].
  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = _flags[flagKey];
    return FlagEvaluationResult<double>(
      flagKey: flagKey,
      value: value is double ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: value != null ? 'STATIC' : 'DEFAULT',
    );
  }

  /// Resolve an object flag (Map).
  ///
  /// Returns the flag value if present and a Map<String, dynamic>, otherwise returns [defaultValue].
  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    final value = _flags[flagKey];
    return FlagEvaluationResult<Map<String, dynamic>>(
      flagKey: flagKey,
      value: value is Map<String, dynamic> ? value : defaultValue,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: value != null ? 'STATIC' : 'DEFAULT',
    );
  }
}