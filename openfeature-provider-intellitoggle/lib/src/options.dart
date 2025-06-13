/// Configuration options for the IntelliToggle provider
///
/// Defines connection settings, timeouts, polling behavior, and other
/// provider-specific configuration options.
///
/// Example usage:
/// ```dart
/// final options = IntelliToggleOptions(
///   baseUri: Uri.parse('https://custom.intellitoggle.com'),
///   timeout: Duration(seconds: 5),
///   enablePolling: true,
/// );
/// ```
class IntelliToggleOptions {
  /// Base URI for the IntelliToggle API
  final Uri baseUri;

  /// Timeout duration for HTTP requests
  final Duration timeout;

  /// Additional HTTP headers to include with requests
  final Map<String, String> headers;

  /// Enable automatic polling for configuration changes
  ///
  /// When enabled, the provider will periodically check for flag changes
  /// and emit configuration change events.
  final bool enablePolling;

  /// Interval between polling requests for configuration changes
  final Duration pollingInterval;

  /// Enable streaming updates via Server-Sent Events (SSE)
  ///
  /// When available, streaming provides real-time updates instead of polling.
  /// Falls back to polling if streaming is not supported.
  final bool enableStreaming;

  /// Maximum number of retry attempts for failed HTTP requests
  final int maxRetries;

  /// Delay between retry attempts
  ///
  /// Uses exponential backoff: delay * attempt^2
  final Duration retryDelay;

  /// Enable request/response logging for debugging
  final bool enableLogging;

  /// Maximum time to wait for provider initialization
  final Duration initializationTimeout;

  /// Cache TTL for flag evaluations (client-side caching)
  ///
  /// Set to Duration.zero to disable caching
  final Duration cacheTtl;

  /// User agent string for HTTP requests
  final String userAgent;

  /// Creates a new IntelliToggleOptions instance
  ///
  /// All parameters are optional and have sensible defaults for production use.
  IntelliToggleOptions({
    Uri? baseUri,
    Duration? timeout,
    Map<String, String>? headers,
    bool? enablePolling,
    Duration? pollingInterval,
    bool? enableStreaming,
    int? maxRetries,
    Duration? retryDelay,
    bool? enableLogging,
    Duration? initializationTimeout,
    Duration? cacheTtl,
    String? userAgent,
  }) : baseUri = baseUri ?? Uri.parse('https://api.intellitoggle.com'),
       timeout = timeout ?? const Duration(seconds: 10),
       headers = headers ?? const {},
       enablePolling = enablePolling ?? true,
       pollingInterval = pollingInterval ?? const Duration(minutes: 5),
       enableStreaming = enableStreaming ?? false,
       maxRetries = maxRetries ?? 3,
       retryDelay = retryDelay ?? const Duration(seconds: 1),
       enableLogging = enableLogging ?? false,
       initializationTimeout =
           initializationTimeout ?? const Duration(seconds: 30),
       cacheTtl = cacheTtl ?? Duration.zero,
       userAgent = userAgent ?? 'IntelliToggle-Dart-SDK/1.0.0';

  /// Create a copy of this options object with modified values
  ///
  /// Only non-null parameters will override existing values.
  IntelliToggleOptions copyWith({
    Uri? baseUri,
    Duration? timeout,
    Map<String, String>? headers,
    bool? enablePolling,
    Duration? pollingInterval,
    bool? enableStreaming,
    int? maxRetries,
    Duration? retryDelay,
    bool? enableLogging,
    Duration? initializationTimeout,
    Duration? cacheTtl,
    String? userAgent,
  }) {
    return IntelliToggleOptions(
      baseUri: baseUri ?? this.baseUri,
      timeout: timeout ?? this.timeout,
      headers: headers ?? this.headers,
      enablePolling: enablePolling ?? this.enablePolling,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      enableLogging: enableLogging ?? this.enableLogging,
      initializationTimeout:
          initializationTimeout ?? this.initializationTimeout,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  /// Create options optimized for development/testing
  ///
  /// Enables logging, disables polling, and uses shorter timeouts for faster feedback.
  ///
  /// [baseUri] - Custom API endpoint (defaults to localhost:8080)
  /// [timeout] - Custom timeout (defaults to 5 seconds)
  factory IntelliToggleOptions.development({Uri? baseUri, Duration? timeout}) {
    return IntelliToggleOptions(
      baseUri: baseUri ?? Uri.parse('http://localhost:8080'),
      timeout: timeout ?? const Duration(seconds: 5),
      enableLogging: true,
      enablePolling: false, // Disable polling in dev for faster iteration
      maxRetries: 1, // Fail fast in development
    );
  }

  /// Create options optimized for production
  ///
  /// Enables polling and streaming, disables logging, uses production timeouts.
  ///
  /// [baseUri] - Custom API endpoint (defaults to production URL)
  /// [timeout] - Custom timeout (defaults to 10 seconds)
  /// [pollingInterval] - Custom polling interval (defaults to 5 minutes)
  factory IntelliToggleOptions.production({
    Uri? baseUri,
    Duration? timeout,
    Duration? pollingInterval,
  }) {
    return IntelliToggleOptions(
      baseUri: baseUri ?? Uri.parse('https://api.intellitoggle.com'),
      timeout: timeout ?? const Duration(seconds: 10),
      pollingInterval: pollingInterval ?? const Duration(minutes: 5),
      enableLogging: false, // Disable logging in production
      enablePolling: true,
      enableStreaming: true,
      maxRetries: 3,
      cacheTtl: const Duration(minutes: 1), // Enable short-term caching
    );
  }

  /// In-memory cache for flag evaluations (bounded by cacheTtl)
  final Map<String, dynamic> _flagCache = {};
  dynamic getCachedFlag(String cacheKey) {
    final entry = _flagCache[cacheKey];
    if (entry != null && entry['expiresAt'].isAfter(DateTime.now())) {
      return entry['value'];
    }
    return null;
  }
  void setCachedFlag(String cacheKey, dynamic value, Duration ttl) {
    if (ttl > Duration.zero) {
      _flagCache[cacheKey] = {
        'value': value,
        'expiresAt': DateTime.now().add(ttl),
      };
    }
  }
  void clearFlagCache() {
    _flagCache.clear();
  }
}
