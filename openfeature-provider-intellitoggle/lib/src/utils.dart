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
  IntelliToggleUtils(this._httpClient, this._options);

  /// Create a canonical JSON string with sorted keys for stable hashing
  String _canonicalJson(Map<String, dynamic> value) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
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

  Map<String, String> buildHeaders(String accessToken, {String? tenantId}) {
    // Never log or expose secrets
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'User-Agent': _options.userAgent,
      'Accept': 'application/json',
      'X-SDK-Version': '1.0.0',
      'X-SDK-Language': 'dart',
      if (tenantId != null && tenantId.isNotEmpty) 'X-Tenant-ID': tenantId,
      ..._options.headers,
    };
  }

  /// Evaluate a flag via IntelliToggle API
  Future<Map<String, dynamic>> evaluateFlag(
    String accessToken,
    String flagKey,
    Map<String, dynamic> context,
    String valueType, {
    String? tenantId,
  }) async {
    final payload = {
      'flagKey': flagKey,
      'context': context,
      'valueType': valueType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (_options.enableLogging) {
      // Never log credentials or resolved values
      print('[IntelliToggle] Evaluating flag: $flagKey with context: $context');
    }
    // Enforce TLS for production
    if (_options.baseUri.scheme == 'http' &&
        _options.baseUri.host != 'localhost') {
      throw Exception(
        'In production, only HTTPS URLs are allowed for IntelliToggle API.',
      );
    }
    int attempts = 0;
    const int maxDelayMs = 30000; // 30 seconds
    while (attempts < _options.maxRetries) {
      try {
        if (_options.enableLogging) {
          print(
            '[IntelliToggle] $valueType flag evaluation attempt ${attempts + 1}',
          );
        }
        final response = await _makeRequest(
          'POST',
          '/api/v1/flags/evaluate',
          headers: buildHeaders(accessToken, tenantId: tenantId),
          body: jsonEncode(payload),
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
          throw AuthenticationException('Invalid IntelliToggle credentials');
        } else {
          throw ApiException(
            'API request failed: ${_sanitizeError(response.body)}',
            code: response.statusCode.toString(),
          );
        }
      } catch (error) {
        attempts++;
        if (attempts >= _options.maxRetries) rethrow;
        // Exponential backoff with cap
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

  /// Evaluate a flag via OFREP (Appendix C) endpoint
  Future<Map<String, dynamic>> evaluateFlagOfrep(
    String authToken,
    String flagKey,
    Map<String, dynamic> context,
    String valueType,
    dynamic defaultValue,
  ) async {
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
            'Authorization': 'Bearer ${_options.ofrepAuthToken ?? authToken}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': _options.userAgent,
            ..._options.headers,
          },
          body: jsonEncode(payload),
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
  Future<bool> checkForChanges(
    String accessToken, {
    String? tenantId,
  }) async {
    try {
      final response = await _makeRequest(
        'HEAD',
        '/api/v1/flags/config',
        headers: buildHeaders(accessToken, tenantId: tenantId),
      );

      final currentEtag = response.headers['etag'];
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
      return false;
    }
  }

  /// Make HTTP request with retry logic and exponential backoff (max 30s)
  Future<http.Response> _makeRequest(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final base = _options.useOfrep
        ? (_options.ofrepBaseUri ?? _options.baseUri)
        : _options.baseUri;
    final uri = base.resolve(path);
    int attempts = 0;
    const int maxBackoffMs = 30000;
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
        final baseDelay = _options.retryDelay.inMilliseconds *
            math.pow(2, attempts - 1).toInt();
        final backoffDelay = Duration(
          milliseconds: math.min(baseDelay, maxBackoffMs),
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
    if (msg.contains('Bearer')) {
      return 'An error occurred (details hidden for security)';
    }
    return msg.replaceAll(RegExp(r'Bearer [^\s]+'), '[REDACTED]');
  }
}

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
