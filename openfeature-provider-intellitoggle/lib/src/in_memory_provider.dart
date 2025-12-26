import 'dart:async';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'events.dart';

// NO-OP change
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
  /// Values may be static or context-derived via callbacks.
  final Map<String, dynamic> _flags = {};

  /// Track all keys ever seen since initialization to satisfy
  /// union-of-all-previous-and-new-keys semantics in change events.
  Set<String> _seenKeys = <String>{};

  /// Optional constructor to pre-seed flags.
  ///
  /// [initialFlags] keys are the flag keys. Values can be concrete values or
  /// callbacks of the form `(Map<String, dynamic> context) => value` to support
  /// context-aware evaluation.
  InMemoryProvider({Map<String, dynamic>? initialFlags}) {
    if (initialFlags != null) {
      _flags.addAll(initialFlags);
      _seenKeys = Set<String>.from(_flags.keys);
    }
  }

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

  @override
  ProviderMetadata get metadata => ProviderMetadata(
    name: 'InMemoryProvider',
    version: '1.0.0',
    attributes: const {'platform': 'dart'},
  );

  /// Set or update a flag value.
  ///
  /// [key] is the flag key, [value] is the flag value (any type).
  /// Emits a configuration changed event.
  void setFlag(String key, dynamic value) {
    final previous = Set<String>.from(_flags.keys);
    _flags[key] = value;
    _emitConfigChanged(previous);
  }

  /// Remove a flag by key.
  ///
  /// Emits a configuration changed event.
  void removeFlag(String key) {
    final previous = Set<String>.from(_flags.keys);
    _flags.remove(key);
    _emitConfigChanged(previous);
  }

  /// Clear all flags.
  ///
  /// Emits a configuration changed event.
  void clearFlags() {
    final previous = Set<String>.from(_flags.keys);
    _flags.clear();
    _emitConfigChanged(previous);
  }

  /// Returns true if a flag with [key] exists in the provider.
  bool hasFlag(String key) => _flags.containsKey(key);

  /// Emit a PROVIDER_CONFIGURATION_CHANGED event to listeners.
  /// The event includes the union of the previous and new key sets.
  void _emitConfigChanged(Set<String> previousKeys) {
    final currentKeys = Set<String>.from(_flags.keys);
    // Maintain cumulative set of all keys seen to ensure the flagsChanged
    // field reflects a union of all previous and new keys, even across
    // multiple sequential updates.
    _seenKeys = <String>{..._seenKeys, ...previousKeys, ...currentKeys};
    _eventController.add(IntelliToggleEvent.configurationChanged(_seenKeys.toList()));
  }

  /// Listen to provider events (e.g., configuration changed).
  Stream<IntelliToggleEvent> get events => _eventController.stream;

  @override
  Future<void> initialize([Map<String, dynamic>? context]) async {
    try {
      _state = ProviderState.READY;
    } catch (e) {
      _state = ProviderState.ERROR;
      _eventController.add(IntelliToggleEvent.error(e.toString()));
    }
    print('[InMemoryProvider] Initialized, state = $_state');
    await Future.delayed(Duration.zero);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> shutdown() async {
    try {
      _state = ProviderState.NOT_READY;
      await _eventController.close();
    } catch (e) {
      _state = ProviderState.ERROR;
      _eventController.add(IntelliToggleEvent.error(e.toString()));
    }
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
    final value = _evaluateValue(_flags[flagKey], context);
    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult<bool>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        // Treat missing flag as an error to satisfy hooks.feature expectations
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
      );
    }
    if (value is! bool) {
      return FlagEvaluationResult<bool>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult<bool>(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: 'STATIC',
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
    final value = _evaluateValue(_flags[flagKey], context);
    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult<String>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
      );
    }
    if (value is! String) {
      return FlagEvaluationResult<String>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult<String>(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: 'STATIC',
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
    final value = _evaluateValue(_flags[flagKey], context);
    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult<int>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
      );
    }
    if (value is! int) {
      return FlagEvaluationResult<int>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult<int>(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: 'STATIC',
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
    final value = _evaluateValue(_flags[flagKey], context);
    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult<double>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
      );
    }
    if (value is! double) {
      return FlagEvaluationResult<double>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult<double>(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: 'STATIC',
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
    final value = _evaluateValue(_flags[flagKey], context);
    if (!_flags.containsKey(flagKey)) {
      return FlagEvaluationResult<Map<String, dynamic>>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
      );
    }
    if (value is! Map<String, dynamic>) {
      return FlagEvaluationResult<Map<String, dynamic>>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
      );
    }
    return FlagEvaluationResult<Map<String, dynamic>>(
      flagKey: flagKey,
      value: value,
      evaluatedAt: DateTime.now(),
      evaluatorId: name,
      reason: 'STATIC',
    );
  }
  /// Evaluate a stored value which may be either static or a callback
  /// receiving the evaluation context and returning the value.
  dynamic _evaluateValue(dynamic raw, Map<String, dynamic>? context) {
    if (raw is Function) {
      try {
        final ctx = context ?? const <String, dynamic>{};
        // Try calling with one positional argument (context)
        return Function.apply(raw, [ctx]);
      } catch (_) {
        // If function arity/type mismatch, fall through; callers will type-check
        return null;
      }
    }
    return raw;
  }
}
