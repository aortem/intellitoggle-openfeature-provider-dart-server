import 'dart:async';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/telemetry.dart';

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
  ProviderState _state = ProviderState.NOT_READY;
  Timer? _pollingTimer;
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

  /// Provider metadata (OpenFeature spec)
  @override
  ProviderMetadata get metadata => ProviderMetadata(
    name: 'IntelliToggle',
    version: '1.0.0',
    attributes: const {'platform': 'dart'},
  );

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
    // Prevent multiple initializations (thread-safe)
    if (_initCompleter.isCompleted) return _initCompleter.future;
    // Synchronize initialization
    if (_state == ProviderState.READY || _state == ProviderState.ERROR) {
      return _initCompleter.future;
    }
    _state = ProviderState.NOT_READY;
    try {
      _eventEmitter.emit(IntelliToggleEvent.initializing());
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
      final sanitized = _sanitizeError(error);
      _eventEmitter.emit(IntelliToggleEvent.error(sanitized));
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(sanitized);
      }
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
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _state = ProviderState.SHUTDOWN;
    _eventEmitter.emit(IntelliToggleEvent.shutdown());
    _eventEmitter.dispose();
    _httpClient.close();
    if (!_initCompleter.isCompleted) {
      _initCompleter.completeError('Shutdown before initialization completed');
    }
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
  // Start time for latency measurement
  final start = DateTime.now();

  try {
    if (_state != ProviderState.READY) {
      await _initCompleter.future;
    }

    final processedContext = _contextProcessor.processContext(context ?? {});

    final response = await _utils.evaluateFlag(
      _sdkKey,
      flagKey,
      processedContext,
      valueType,
    );

    final now = DateTime.now();
    ErrorCode? errorCode;

    // Parse errorCode if present
    if (response['errorCode'] != null) {
      switch (response['errorCode'].toString()) {
        case 'FLAG_NOT_FOUND':
          errorCode = ErrorCode.FLAG_NOT_FOUND;
          break;
        case 'TYPE_MISMATCH':
          errorCode = ErrorCode.TYPE_MISMATCH;
          break;
        case 'GENERAL':
          errorCode = ErrorCode.GENERAL;
          break;
        default:
          errorCode = null;
      }
    }

    // Telemetry: success count + latency
<<<<<<< HEAD
    Telemetry.metrics.increment('feature_flag.evaluation_success_count');
=======
    Telemetry.metrics.increment('provider.evaluation.success');
>>>>>>> 0a03ce4f10af37a12030b6886bc114a1e3aa7f12
    Telemetry.recordLatency(
      flagKey,
      DateTime.now().difference(start),
    );

    final result = FlagEvaluationResult<T>(
      flagKey: flagKey,
      value: response['value'] as T? ?? defaultValue,
      reason: response['reason']?.toString() ?? 'DEFAULT',
      variant: response['variant']?.toString(),
      errorCode: errorCode,
      errorMessage: _sanitizeError(response['errorMessage']),
      evaluatedAt: now,
      evaluatorId: 'IntelliToggle',
    );

    _eventEmitter.emit(
      IntelliToggleEvent.flagEvaluated(
        flagKey,
        result.value,
        result.reason,
        variant: result.variant,
        context: processedContext,
      ),
    );

    return result;

  } catch (error) {
    // Telemetry: error count + latency
    Telemetry.metrics.increment('feature_flag.evaluation_error_count');
    Telemetry.recordLatency(
      flagKey,
      DateTime.now().difference(start),
    );

    // Rebuild the appropriate error result
    return FlagEvaluationResult<T>(
      flagKey: flagKey,
      value: defaultValue,
      reason: 'ERROR',
      errorCode: ErrorCode.GENERAL,
      errorMessage: _sanitizeError(error),
      evaluatedAt: DateTime.now(),
      evaluatorId: 'IntelliToggle',
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

  String _sanitizeError(dynamic error) {
    // Remove sensitive info and format error message
    final msg = error?.toString() ?? 'Unknown error';
    if (msg.contains(_sdkKey)) {
      return 'An error occurred (details hidden for security)';
    }
    // Remove Bearer tokens and other secrets
    return msg.replaceAll(_sdkKey, '[REDACTED]').replaceAll(RegExp(r'Bearer [^\s]+'), '[REDACTED]');
  }

  @override
  String get name => 'IntelliToggle';
}
