import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openfeature_dart_server_sdk/feature_provider.dart';

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
///   clientId: 'your-client-id',
///   clientSecret: 'client-secret',
///   tenantId: 'tenant-id',
///   options: IntelliToggleOptions.production(),
/// );
///
/// final api = OpenFeatureAPI();
/// await api.setProvider(provider);
/// ```
class IntelliToggleProvider implements FeatureProvider {
  final String _clientId;
  final String _clientSecret;
  final String _tenantId;
  final String _oauthScope;
  final IntelliToggleOptions _options;
  final http.Client _httpClient;
  late final IntelliToggleUtils _utils;
  late final IntelliToggleContextProcessor _contextProcessor;
  late final IntelliToggleEventEmitter _eventEmitter;
  ProviderState _state = ProviderState.NOT_READY;
  Timer? _pollingTimer;
  final Completer<void> _initCompleter = Completer<void>();

  String? _cachedAccessToken;
  DateTime? _tokenExpiry;
  final Duration _tokenLeeway = const Duration(minutes: 1);

  /// Creates a new IntelliToggle provider instance
  ///
  /// Provide IntelliToggle OAuth2 client credentials via [clientId],
  /// [clientSecret], and [tenantId]. Optionally override the requested scope
  /// with [oauthScope].
  ///
  /// [options] - Configuration options (defaults to standard settings)
  /// [httpClient] - HTTP client for API calls (uses default if not provided)
  IntelliToggleProvider({
    required String clientId,
    required String clientSecret,
    required String tenantId,
    String? oauthScope,
    IntelliToggleOptions? options,
    http.Client? httpClient,
  }) : assert(clientId.trim().isNotEmpty, 'clientId is required'),
       assert(clientSecret.trim().isNotEmpty, 'clientSecret is required'),
       assert(tenantId.trim().isNotEmpty, 'tenantId is required'),
       _clientId = clientId.trim(),
       _clientSecret = clientSecret.trim(),
       _tenantId = tenantId.trim(),
       _oauthScope = (oauthScope == null || oauthScope.trim().isEmpty)
           ? 'flags:evaluate'
           : oauthScope.trim(),
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
    final start = DateTime.now();
    try {
      if (_state != ProviderState.READY) {
        await _initCompleter.future;
      }
      final processedContext = _contextProcessor.processContext(context ?? {});
      final token = await _getAccessToken();
      final response = await _utils.evaluateFlag(
        token,
        flagKey,
        processedContext,
        valueType,
        tenantId: _tenantId,
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

      Telemetry.metrics.increment('feature_flag.evaluation_success_count');
      Telemetry.recordLatency(flagKey, DateTime.now().difference(start));

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
    } on FlagNotFoundException catch (error) {
      Telemetry.metrics.increment('feature_flag.evaluation_error_count');
      Telemetry.recordLatency(flagKey, DateTime.now().difference(start));
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
      Telemetry.metrics.increment('feature_flag.evaluation_error_count');
      Telemetry.recordLatency(flagKey, DateTime.now().difference(start));
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
  Future<void> _testConnection() async {
    final token = await _getAccessToken();
    final response = await _httpClient
        .get(
          _options.baseUri.resolve('/health'),
          headers: _utils.buildHeaders(token, tenantId: _tenantId),
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
        final token = await _getAccessToken();
        final hasChanges = await _utils.checkForChanges(
          token,
          tenantId: _tenantId,
        );
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

  Future<String> _getAccessToken() async {
    if (_cachedAccessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(_tokenLeeway))) {
      return _cachedAccessToken!;
    }

    final token = await _requestOAuthToken();
    _cachedAccessToken = token.value;
    _tokenExpiry = token.expiresAt;
    return token.value;
  }

  Future<_OAuthToken> _requestOAuthToken() async {
    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final body = _formEncode({
      'grant_type': 'client_credentials',
      'scope': _oauthScope,
    });

    final response = await _httpClient
        .post(
          _options.baseUri.resolve('/oauth/token'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic $credentials',
            'X-Tenant-ID': _tenantId,
          },
          body: body,
        )
        .timeout(_options.timeout);

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'OAuth token request failed: ${response.statusCode} - ${_sanitizeError(response.body)}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw AuthenticationException('OAuth response missing access_token');
    }
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    return _OAuthToken(token, expiresAt);
  }

  String _formEncode(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  String _sanitizeError(dynamic error) {
    // Remove sensitive info and format error message
    final msg = error?.toString() ?? 'Unknown error';
    var sanitized = msg;
    for (final secret in [_clientSecret, _cachedAccessToken]) {
      if (secret != null && secret.isNotEmpty) {
        sanitized = sanitized.replaceAll(secret, '[REDACTED]');
      }
    }
    return sanitized.replaceAll(RegExp(r'Bearer [^\s]+'), '[REDACTED]');
  }

  @override
  String get name => 'IntelliToggle';
}

class _OAuthToken {
  final String value;
  final DateTime expiresAt;
  _OAuthToken(this.value, this.expiresAt);
}
