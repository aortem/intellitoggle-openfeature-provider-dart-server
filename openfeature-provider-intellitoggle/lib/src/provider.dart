import 'dart:async';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/telemetry.dart';
import 'options.dart';
import 'utils.dart';
import 'context.dart';
import 'events.dart';

/// New IntelliToggle provider implementation with corrected API endpoints
class IntelliToggleProvider implements FeatureProvider {
  final String _clientId;
  final String _clientSecret;
  final String _tenantId;
  final IntelliToggleOptions _options;
  final http.Client _httpClient;
  late final IntelliToggleUtils _utils;
  late final IntelliToggleContextProcessor _contextProcessor;
  late final IntelliToggleEventEmitter _eventEmitter;
  ProviderState _state = ProviderState.NOT_READY;
  Timer? _pollingTimer;
  final Completer<void> _initCompleter = Completer<void>();

  // Local cache for flags
  Map<String, dynamic> _localFlags = {};

  /// Creates a new IntelliToggle provider instance with corrected endpoints
  IntelliToggleProvider({
    required String clientId,
    required String clientSecret,
    required String tenantId,
    IntelliToggleOptions? options,
    http.Client? httpClient,
  }) : _clientId = clientId,
       _clientSecret = clientSecret,
       _tenantId = tenantId,
       _options = options ?? IntelliToggleOptions(),
       _httpClient = httpClient ?? http.Client() {
    _utils = IntelliToggleUtils(
      _httpClient,
      _options,
      clientId: _clientId,
      clientSecret: _clientSecret,
      tenantId: _tenantId,
    );
    _contextProcessor = IntelliToggleContextProcessor();
    _eventEmitter = IntelliToggleEventEmitter();
  }

  @override
  ProviderMetadata get metadata => ProviderMetadata(
    name: 'IntelliToggle',
    version: '1.0.0',
    attributes: const {'platform': 'dart', 'endpoint-version': 'corrected'},
  );

  @override
  ProviderState get state => _state;

  @override
  ProviderConfig get config => ProviderConfig();

  @override
  Future<void> initialize([Map<String, dynamic>? context]) async {
    if (_initCompleter.isCompleted) return _initCompleter.future;
    if (_state == ProviderState.READY || _state == ProviderState.ERROR) {
      return _initCompleter.future;
    }

    _state = ProviderState.NOT_READY;
    try {
      _eventEmitter.emit(IntelliToggleEvent.initializing());
      // Test connection to ensure API is reachable
      await _testConnection();

      // Just verify OAuth connection works by getting a token
      await _utils.buildHeaders();

      if (_options.enableLogging) {
        print('[IntelliToggle] Provider initialized successfully');
      }

      _state = ProviderState.READY;
      _eventEmitter.emit(IntelliToggleEvent.ready());

      _initCompleter.complete();
    } catch (error) {
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

  @override
  Future<void> connect() async {}

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

  @override
  Future<FlagEvaluationResult<bool>> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<bool>(flagKey, defaultValue, context, 'boolean');
  }

  @override
  Future<FlagEvaluationResult<String>> getStringFlag(
    String flagKey,
    String defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<String>(flagKey, defaultValue, context, 'string');
  }

  @override
  Future<FlagEvaluationResult<int>> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<int>(flagKey, defaultValue, context, 'integer');
  }

  @override
  Future<FlagEvaluationResult<double>> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    Map<String, dynamic>? context,
  }) async {
    return _evaluateFlag<double>(flagKey, defaultValue, context, 'double');
  }

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

  /// Core flag evaluation logic using corrected endpoints
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
        flagKey,
        processedContext,
        valueType,
      );

      final now = DateTime.now();
      ErrorCode? errorCode;

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

      final dynamic rawValue = response['value'];
      T value;

      try {
        switch (valueType) {
          case 'boolean':
            value = (rawValue is bool ? rawValue : (rawValue == true)) as T;
            break;
          case 'string':
            value = (rawValue?.toString() ?? '') as T;
            break;
          case 'integer':
            if (rawValue is int) {
              value = rawValue as T;
            } else if (rawValue is num) {
              value = rawValue.toInt() as T;
            } else {
              throw TypeMismatchException('Expected integer');
            }
            break;
          case 'double':
            if (rawValue is double) {
              value = rawValue as T;
            } else if (rawValue is num) {
              value = rawValue.toDouble() as T;
            } else {
              throw TypeMismatchException('Expected double');
            }
            break;
          case 'object':
            if (rawValue is Map<String, dynamic>) {
              value = rawValue as T;
            } else if (rawValue is Map) {
              value = Map<String, dynamic>.from(rawValue as Map) as T;
            } else {
              throw TypeMismatchException('Expected object');
            }
            break;
          default:
            value = (rawValue as T?) ?? defaultValue;
        }
      } catch (_) {
        value = defaultValue;
      }

      // Telemetry: success count + latency
      Telemetry.metrics.increment('feature_flag.evaluation_success_count');
      Telemetry.recordLatency(flagKey, DateTime.now().difference(start));

      final result = FlagEvaluationResult<T>(
        flagKey: flagKey,
        value: value,
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
    } on FlagNotFoundException catch (error) {
      return FlagEvaluationResult<T>(
        flagKey: flagKey,
        value: defaultValue,
        reason: 'ERROR',
        errorCode: ErrorCode.FLAG_NOT_FOUND,
        errorMessage: _sanitizeError(error),
        evaluatedAt: DateTime.now(),
        evaluatorId: 'IntelliToggle',
      );
    } on TypeMismatchException catch (error) {
      return FlagEvaluationResult<T>(
        flagKey: flagKey,
        value: defaultValue,
        reason: 'ERROR',
        errorCode: ErrorCode.TYPE_MISMATCH,
        errorMessage: _sanitizeError(error),
        evaluatedAt: DateTime.now(),
        evaluatorId: 'IntelliToggle',
      );
    } catch (error) {
      // Telemetry: error count + latency
      Telemetry.metrics.increment('feature_flag.evaluation_error_count');
      Telemetry.recordLatency(flagKey, DateTime.now().difference(start));

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
  Future<dynamic> _testConnection() async {
    final response = await _httpClient
        .get(
          _options.baseUri.resolve('/health'),
          headers: await _utils.buildHeaders(),
        )
        .timeout(_options.timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to connect to IntelliToggle API: ${response.statusCode}',
      );
    } else {
      if (_options.enableLogging) {
        print('[IntelliToggle] Test Connection to route /health successful');
      }
      return response;
    }
  }

  /// Get event stream for listening to provider lifecycle events
  Stream<IntelliToggleEvent> get events => _eventEmitter.stream;

  /// Manually update local flags (for testing or manual refresh)
  void updateLocalFlags(Map<String, dynamic> newFlags) {
    _localFlags = Map<String, dynamic>.from(newFlags);
    _eventEmitter.emit(IntelliToggleEvent.configurationChanged());
  }

  /// Get current local flags (for debugging)
  Map<String, dynamic> get localFlags => Map<String, dynamic>.from(_localFlags);

  String _sanitizeError(dynamic error) {
    final msg = error?.toString() ?? 'Unknown error';
    if (msg.contains(_clientId) || msg.contains(_clientSecret)) {
      return 'An error occurred (details hidden for security)';
    }
    return msg
        .replaceAll(_clientId, '[REDACTED]')
        .replaceAll(_clientSecret, '[REDACTED]')
        .replaceAll(RegExp(r'Bearer [^\s]+'), '[REDACTED]');
  }

  @override
  String get name => 'IntelliToggle';
}
