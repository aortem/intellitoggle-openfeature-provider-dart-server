import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'options.dart';

/// HTTP utilities and helper functions for IntelliToggle API communication
class IntelliToggleUtils {
  final http.Client _httpClient;
  final IntelliToggleOptions _options;
  String? _lastEtag;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Credentials will be passed from the provider
  final String clientId;
  final String clientSecret;
  final String tenantId;

  IntelliToggleUtils(
    this._httpClient,
    this._options, {
    required this.clientId,
    required this.clientSecret,
    required this.tenantId,
  });

  /// Create a canonical JSON string with sorted keys for stable hashing
  String _canonicalJson(Map<String, dynamic> value) {
    List<String> keys = value.keys.map((k) => k.toString()).toList()..sort();
    final map = <String, dynamic>{};
    for (final k in keys) {
      final v = value[k];
      if (v is Map<String, dynamic>) {
        map[k] = jsonDecode(_canonicalJson(v));
      } else {
        map[k] = v;
      }
    }
    return jsonEncode(map);
  }

  /// Get or refresh OAuth2 access token
  Future<String> _getAccessToken() async {
    // Return cached token if it's still valid (with 1-minute buffer)
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(Duration(minutes: 1)))) {
      return _accessToken!;
    }

    // Build the token URL correctly
    final baseUrlStr = _options.baseUri.toString().replaceAll(
      RegExp(r'/$'),
      '',
    );
    final tokenUrl = Uri.parse('$baseUrlStr/oauth/token');

    if (_options.enableLogging) {
      print('[IntelliToggle] Requesting OAuth2 token from: $tokenUrl');
      print('[IntelliToggle] Client ID: $clientId');
      print('[IntelliToggle] Tenant ID: $tenantId');
    }

    final response = await _httpClient
        .post(
          tokenUrl,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Tenant-ID': tenantId,
          },
          body:
              'grant_type=client_credentials'
              '&client_id=$clientId'
              '&client_secret=$clientSecret'
              '&scope=flags:read flags:evaluate',
        )
        .timeout(_options.timeout);

    if (_options.enableLogging) {
      print('[IntelliToggle] OAuth2 response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('[IntelliToggle] OAuth2 error body: ${response.body}');
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String;
      final expiresIn = data['expires_in'] as int? ?? 3600; // Default 1 hour
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      if (_options.enableLogging) {
        print(
          '[IntelliToggle] OAuth2 token obtained, expires in ${expiresIn}s',
        );
      }

      return _accessToken!;
    } else {
      throw AuthenticationException(
        'OAuth2 failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Build headers with OAuth2 token
  Future<Map<String, String>> buildHeaders() async {
    final token = await _getAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'User-Agent': _options.userAgent,
      'Accept': 'application/json',
      'X-Tenant-ID': tenantId,
      'X-SDK-Version': '1.0.0',
      'X-SDK-Language': 'dart',
      ..._options.headers,
    };
  }

  Map<String, String> buildHeadersWithSDKKey(String sdkKey) {
    // Never log or expose the SDK key
    return {
      'Authorization': 'Bearer $sdkKey',
      'Content-Type': 'application/json',
      'User-Agent': _options.userAgent,
      'Accept': 'application/json',
      'X-SDK-Version': '1.0.0',
      'X-SDK-Language': 'dart',
      ..._options.headers,
    };
  }

  /// Evaluate a flag via IntelliToggle API
  ///
  /// Makes a POST request to the flag evaluation endpoint with the provided
  /// context and returns the evaluation result.
  ///
  /// [flagKey] - The flag to evaluate
  /// [context] - Processed evaluation context
  /// [valueType] - Expected value type (boolean, string, etc.)
  ///
  /// Returns the API response as a Map
  /// Throws [FlagNotFoundException] if flag doesn't exist
  /// Throws [AuthenticationException] if Client Secrets are invalid
  /// Throws [ApiException] for other API errors
  Future<Map<String, dynamic>> evaluateFlag(
    String flagKey,
    Map<String, dynamic> context,
    String valueType,
  ) async {
    if (_options.enableLogging) {
      print('[IntelliToggle] Evaluating flag: $flagKey with context: $context');
    }

    int attempts = 0;
    int maxDelayMs = 30000;

    while (attempts < _options.maxRetries) {
      try {
        if (_options.enableLogging) {
          print(
            '[IntelliToggle] $valueType flag evaluation attempt ${attempts + 1}',
          );
        }

        final headers = await buildHeaders();

        // Use POST request to evaluate flag with context
        final response = await _makeRequest(
          'POST',
          '/api/flags/$flagKey/evaluate',
          headers: headers,
          body: jsonEncode(context),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body) as Map<String, dynamic>;
          if (_options.enableLogging) {
            print('[IntelliToggle] Flag evaluation result: $result');
          }
          return result;
        } else if (response.statusCode == 404) {
          throw FlagNotFoundException('Flag "$flagKey" not found');
        } else if (response.statusCode == 401) {
          // Token expired, clear it and retry
          _accessToken = null;
          _tokenExpiry = null;

          if (_options.enableLogging) {
            print(
              '[IntelliToggle] Token expired during evaluation, retrying...',
            );
          }

          attempts++;
          if (attempts >= _options.maxRetries) {
            throw AuthenticationException(
              'Authentication failed after retries',
            );
          }
          continue;
        } else {
          throw ApiException(
            'API request failed: ${response.statusCode} - ${response.body}',
            code: response.statusCode.toString(),
          );
        }
      } catch (error) {
        if (error is FlagNotFoundException ||
            error is AuthenticationException) {
          rethrow;
        }

        attempts++;
        if (attempts >= _options.maxRetries) rethrow;

        // Exponential backoff with cap
        final delay = Duration(
          milliseconds: math.min(
            _options.retryDelay.inMilliseconds * (1 << (attempts - 1)),
            maxDelayMs,
          ),
        );

        if (_options.enableLogging) {
          print('[IntelliToggle] Retrying in ${delay.inMilliseconds}ms...');
        }

        await Future.delayed(delay);
      }
    }
    throw ApiException('Max retries exceeded');
  }

  /// Evaluate a flag via OFREP (Appendix C) endpoint
  ///
  /// Endpoint: POST {base}/v1/flags/{flagKey}/evaluate
  /// Request: { defaultValue, type, context }
  /// Response: { value, reason?, variant?, flagMetadata? }
  Future<Map<String, dynamic>> evaluateFlagOfrep(
    String sdkKey,
    String flagKey,
    Map<String, dynamic> context,
    String valueType,
    dynamic defaultValue,
  ) async {
    // Caching: key on flagKey + type + context hash
    final ctxStr = _canonicalJson(context);
    final cacheKeySource = '$flagKey|$valueType|$ctxStr';
    final cacheKey = base64Url.encode(utf8.encode(cacheKeySource));
    final cached = _options.getCachedFlag(cacheKey);
    if (cached != null) {
      return cached as Map<String, dynamic>;
    }

    final payload = {
      'defaultValue': defaultValue,
      'type': valueType,
      'context': context,
    };

    final base = _options.ofrepBaseUri ?? _options.baseUri;
    // Enforce TLS unless localhost
    if (base.scheme == 'http' &&
        base.host != 'localhost' &&
        base.host != '127.0.0.1') {
      throw Exception('OFREP requires HTTPS in non-local environments.');
    }

    int attempts = 0;
    const int maxDelayMs = 30000;
    while (attempts < _options.maxRetries) {
      try {
        final response = await _makeRequest(
          'POST',
          '/v1/flags/$flagKey/evaluate',
          headers: {
            'Authorization': 'Bearer ${_options.ofrepAuthToken ?? sdkKey}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': _options.userAgent,
            ..._options.headers,
          },
          body: jsonEncode(payload),
          // Override base via resolve
        );
        if (response.statusCode == 200) {
          if (_options.enableLogging) {
            print(
              '[IntelliToggle] OFREP raw body (${response.body.length} bytes)',
            );
          }
          final result = jsonDecode(response.body) as Map<String, dynamic>;
          if (_options.enableLogging) {
            print('[IntelliToggle] OFREP body: ${response.body}');
          }
          _options.setCachedFlag(cacheKey, result, _options.cacheTtl);
          return result;
        } else if (response.statusCode == 404) {
          throw FlagNotFoundException('Flag "$flagKey" not found');
        } else if (response.statusCode == 400) {
          // Treat bad request as type or request mismatch
          throw TypeMismatchException(
            'Invalid type or request for flag "$flagKey"',
          );
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw AuthenticationException('Unauthorized');
        } else {
          throw ApiException(
            'OFREP request failed',
            code: response.statusCode.toString(),
          );
        }
      } catch (error) {
        attempts++;
        if (attempts >= _options.maxRetries) rethrow;
        final delay = Duration(
          milliseconds: math.min(
            _options.retryDelay.inMilliseconds * (1 << (attempts - 1)),
            maxDelayMs,
          ),
        );
        await Future.delayed(delay);
      }
    }
    throw ApiException('Max retries exceeded');
  }

  /// Check for configuration changes using ETag
  ///
  /// Makes a HEAD request to check if the configuration has changed
  /// since the last check. Uses ETag for efficient change detection.
  ///
  /// [sdkKey] - SDK key for authentication
  /// Returns true if configuration has changed, false otherwise
  Future<bool> checkForChanges(String sdkKey) async {
    try {
      final response = await _makeRequest(
        'HEAD',
        '/api/v1/flags/config',
        headers: buildHeadersWithSDKKey(sdkKey),
      );

      final currentEtag = response.headers['etag'];

      // Compare with last known ETag
      if (_lastEtag != null && _lastEtag != currentEtag) {
        if (_options.enableLogging) {
          print(
            '[IntelliToggle] Configuration changed. ETag: $_lastEtag -> $currentEtag',
          );
        }
        _lastEtag = currentEtag;
        return true;
      }

      _lastEtag = currentEtag;
      return false;
    } catch (error) {
      if (_options.enableLogging) {
        print('[IntelliToggle] Error checking for changes: $error');
      }
      // Don't throw on polling errors - just return false
      return false;
    }
  }

  /// Make HTTP request with retry logic and exponential backoff (max 30s)
  ///
  /// Implements automatic retry with exponential backoff for resilient
  /// communication with the IntelliToggle API.
  ///
  /// [method] - HTTP method (GET, POST, HEAD, etc.)
  /// [path] - API endpoint path
  /// [headers] - HTTP headers
  /// [body] - Request body (for POST/PUT)
  ///
  /// Returns the HTTP response
  /// Throws the last encountered exception if all retries fail
  Future<http.Response> _makeRequest(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    // Build URI correctly
    final baseUrlStr = _options.baseUri.toString().replaceAll(
      RegExp(r'/$'),
      '',
    );
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrlStr$cleanPath');

    int attempts = 0;
    final int maxBackoffMs = 30000;

    while (attempts < _options.maxRetries) {
      try {
        if (_options.enableLogging) {
          print('[IntelliToggle] $method $uri (attempt ${attempts + 1})');
        }

        late Future<http.Response> responseFuture;
        switch (method.toUpperCase()) {
          case 'GET':
            responseFuture = _httpClient.get(uri, headers: headers);
            break;
          case 'POST':
            responseFuture = _httpClient.post(
              uri,
              headers: headers,
              body: body,
            );
            break;
          case 'HEAD':
            responseFuture = _httpClient.head(uri, headers: headers);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }

        final response = await responseFuture.timeout(_options.timeout);
        if (_options.enableLogging) {
          print('[IntelliToggle] Response: ${response.statusCode}');
        }
        return response;
      } catch (error) {
        attempts++;
        if (_options.enableLogging) {
          print(
            '[IntelliToggle] Request failed (attempt $attempts): ${_sanitizeError(error)}',
          );
        }
        if (attempts >= _options.maxRetries) {
          if (error is TimeoutException) {
            throw TimeoutException('Request timeout after ${_options.timeout}');
          }
          throw ApiException(_sanitizeError(error));
        }
        final base =
            _options.retryDelay.inMilliseconds *
            math.pow(2, attempts - 1).toInt();
        final backoffDelay = Duration(
          milliseconds: math.min(base, maxBackoffMs),
        );
        if (_options.enableLogging) {
          print('[IntelliToggle] Retrying in ${backoffDelay.inMilliseconds}ms');
        }
        await Future.delayed(backoffDelay);
      }
    }
    throw ApiException('Max retries exceeded');
  }

  String _sanitizeError(dynamic error) {
    final msg = error?.toString() ?? 'Unknown error';
    if (msg.contains('Bearer') ||
        msg.contains(clientId) ||
        msg.contains(clientSecret)) {
      return 'An error occurred (details hidden for security)';
    }
    return msg
        .replaceAll(clientId, '[REDACTED]')
        .replaceAll(clientSecret, '[REDACTED]')
        .replaceAll(RegExp(r'Bearer [^\s]+'), '[REDACTED]');
  }
}

// Custom exceptions
class FlagNotFoundException implements Exception {
  final String message;
  FlagNotFoundException(this.message);
  @override
  String toString() => 'FlagNotFoundException: $message';
}

class TypeMismatchException implements Exception {
  final String message;
  TypeMismatchException(this.message);
  @override
  String toString() => 'TypeMismatchException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  @override
  String toString() => 'AuthenticationException: $message';
}

class ApiException implements Exception {
  final String message;
  final String? code;
  ApiException(this.message, {this.code});
  @override
  String toString() => 'ApiException${code != null ? '($code)' : ''}: $message';
}
