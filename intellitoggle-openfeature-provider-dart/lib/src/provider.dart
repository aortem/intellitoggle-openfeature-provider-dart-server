import 'dart:async';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:http/http.dart' as http;

import 'options.dart';
import 'utils.dart';
import 'context.dart';
import 'events.dart';

/// IntelliToggle provider implementation for OpenFeature Dart Server SDK
///
/// This provider enables integration with IntelliToggle's feature flag platform,
/// supporting single-context, multi-context, and custom context kinds with
/// real-time flag evaluation and lifecycle events.
///
/// Example usage:
/// ```dart
/// final provider = IntelliToggleProvider(
///   sdkKey: 'your-sdk-key',
///   options: IntelliToggleOptions.production(),
/// );
///
/// final api = OpenFeatureAPI();
/// await api.setProvider(provider);
/// ```
class IntelliToggleProvider implements FeatureProvider {
  final String _sdkKey;
  final IntelliToggleOptions _options;
  final http.Client _httpClient;
  late final IntelliToggleUtils _utils;
  late final IntelliToggleContextProcessor _contextProcessor;
  late final IntelliToggleEventEmitter _eventEmitter;

  /// Current provider state for lifecycle management
  ProviderState _state = ProviderState.NOT_READY;

  /// Timer for polling configuration changes
  Timer? _pollingTimer;

  /// Completer to track initialization status
  final Completer<void> _initCompleter = Completer<void>();

  /// Creates a new IntelliToggle provider instance
  ///
  /// [sdkKey] - Your IntelliToggle SDK key for authentication
  /// [options] - Configuration options (defaults to standard settings)
  /// [httpClient] - HTTP client for API calls (uses default if not provided)
  IntelliToggleProvider({
    required String sdkKey,
    IntelliToggleOptions? options,
    http.Client? httpClient,
  }) : _sdkKey = sdkKey,
       _options = options ?? IntelliToggleOptions(),
       _httpClient = httpClient ?? http.Client() {
    // Initialize utility components
    _utils = IntelliToggleUtils(_httpClient, _options);
    _contextProcessor = IntelliToggleContextProcessor();
    _eventEmitter = IntelliToggleEventEmitter();
  }

  /// Provider name identifier
  @override
  String get name => 'IntelliToggle';

  /// Current provider state (READY, ERROR, NOT_READY, etc.)
  @override
  ProviderState get state => _state;

  /// Provider configuration object
  @override
  ProviderConfig get config => ProviderConfig();

  /// Initialize the provider and establish connection to IntelliToggle API
  ///
  /// [context] - Optional initialization context (not used currently)
  /// Returns a Future that completes when initialization is done
  @override
  Future<void> initialize([Map<String, dynamic>? context]) async {
    // Prevent multiple initializations
    if (_initCompleter.isCompleted) return _initCompleter.future;

    try {
      _state = ProviderState.NOT_READY;

      // Test connection to ensure API is reachable
      await _testConnection();

      // Mark as ready and emit event
      _state = ProviderState.READY;
      _eventEmitter.emit(IntelliToggleEvent.ready());

      // Start polling for configuration changes if enabled
      if (_options.enablePolling) {
        _startPolling();
      }

      _initCompleter.complete();
    } catch (error) {
      // Handle initialization failure
      _state = ProviderState.ERROR;
      _eventEmitter.emit(IntelliToggleEvent.error(error.toString()));
      _initCompleter.completeError(error);
      rethrow;
    }

    return _initCompleter.future;
  }

  /// Connect to the provider (no-op - handled in initialize)
  @override
  Future<void> connect() async {}

  /// Shutdown the provider and cleanup resources
  @override
  Future<void> shutdown() async {
    // Cancel polling timer
    _pollingTimer?.cancel();

    // Update state and cleanup
    _state = ProviderState.NOT_READY;
    _eventEmitter.dispose();
    _httpClient.close();
  }

  /// Evaluate a boolean feature flag
  ///
  /// [flagKey] - The feature flag key to evaluate
  /// [defaultValue] - Default value if evaluation fails
  /// [context] - Evaluation context for targeting
  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<bool>(flagKey, defaultValue, context, 'boolean');
  }

  /// Evaluate a string feature flag
  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<String>(flagKey, defaultValue, context, 'string');
  }

  /// Evaluate an integer feature flag
  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<int>(flagKey, defaultValue, context, 'integer');
  }

  /// Evaluate a double feature flag
  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<double>(flagKey, defaultValue, context, 'double');
  }

  /// Evaluate an object feature flag
  @override
  Future<FlagEvaluationResult<Map<String, dynamic>>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<Map<String, dynamic>>(
      flagKey,
      defaultValue,
      context,
      'object',
    );
  }

  /// Core flag evaluation logic with error handling and context processing
  ///
  /// [flagKey] - The flag to evaluate
  /// [defaultValue] - Fallback value
  /// [context] - Evaluation context
  /// [valueType] - Expected value type for API call
  Future<FlagEvaluationResult<T>> _evaluateFlag<T>(
    String flagKey,
    T defaultValue,
    Map<String, dynamic>? context,
    String valueType,
  ) async {
    try {
      // Ensure provider is ready before evaluation
      if (_state != ProviderState.READY) {
        await _initCompleter.future;
      }

      // Process context according to IntelliToggle requirements
      final processedContext = _contextProcessor.processContext(context ?? {});

      // Call IntelliToggle API for flag evaluation
      final response = await _utils.evaluateFlag(
        _sdkKey,
        flagKey,
        processedContext,
        valueType,
      );

      // Create successful evaluation result
      final result = FlagEvaluationResult<T>(
        flagKey: flagKey,
        value: response['value'] as T,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: response['reason'] ?? 'UNKNOWN',
      );

      // Emit flag evaluation event for monitoring
      _eventEmitter.emit(
        IntelliToggleEvent.flagEvaluated(flagKey, result.value, result.reason),
      );

      return result;
    } catch (error) {
      // Emit error event
      _eventEmitter.emit(IntelliToggleEvent.error(error.toString()));

      // Return default value on any error
      return FlagEvaluationResult<T>(
        flagKey: flagKey,
        value: defaultValue,
        evaluatedAt: DateTime.now(),
        evaluatorId: name,
        reason: 'ERROR',
      );
    }
  }

  /// Test connection to IntelliToggle API health endpoint
  Future<void> _testConnection() async {
    final response = await _httpClient
        .get(
          _options.baseUri.resolve('/health'),
          headers: _utils.buildHeaders(_sdkKey),
        )
        .timeout(_options.timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to connect to IntelliToggle API: ${response.statusCode}',
      );
    }
  }

  /// Start polling for configuration changes using ETag
  void _startPolling() {
    _pollingTimer = Timer.periodic(_options.pollingInterval, (_) async {
      try {
        // Check if configuration has changed
        final hasChanges = await _utils.checkForChanges(_sdkKey);
        if (hasChanges) {
          // Emit configuration change event
          _eventEmitter.emit(IntelliToggleEvent.configurationChanged());
        }
      } catch (error) {
        // Log polling errors but don't crash
        _eventEmitter.emit(IntelliToggleEvent.error(error.toString()));
      }
    });
  }

  /// Get event stream for listening to provider lifecycle events
  Stream<IntelliToggleEvent> get events => _eventEmitter.stream;
}
