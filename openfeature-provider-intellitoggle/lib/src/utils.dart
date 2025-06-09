import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'options.dart';

/// HTTP utilities and helper functions for IntelliToggle API communication
///
/// Handles HTTP requests, retry logic, error handling, and API-specific formatting
/// for communication with the IntelliToggle service.
class IntelliToggleUtils {
  /// HTTP client for making requests
  final http.Client _httpClient;

  /// Configuration options for the provider
  final IntelliToggleOptions _options;

  /// Last ETag received from server for change detection
  String? _lastEtag;

  /// Creates a new utils instance
  ///
  /// [_httpClient] - HTTP client to use for requests
  /// [_options] - Configuration options
  IntelliToggleUtils(this._httpClient, this._options);

  /// Build HTTP headers for API requests
  ///
  /// Includes authentication, content type, user agent, and custom headers.
  ///
  /// [sdkKey] - SDK key for authentication
  /// Returns map of HTTP headers
  Map<String, String> buildHeaders(String sdkKey) {
    return {
      'Authorization': 'Bearer $sdkKey',
      'Content-Type': 'application/json',
      'User-Agent': _options.userAgent,
      'Accept': 'application/json',
      'X-SDK-Version': '1.0.0',
      'X-SDK-Language': 'dart',
      // Add any custom headers from options
      ..._options.headers,
    };
  }

  /// Evaluate a flag via IntelliToggle API
  ///
  /// Makes a POST request to the flag evaluation endpoint with the provided
  /// context and returns the evaluation result.
  ///
  /// [sdkKey] - SDK key for authentication
  /// [flagKey] - The flag to evaluate
  /// [context] - Processed evaluation context
  /// [valueType] - Expected value type (boolean, string, etc.)
  ///
  /// Returns the API response as a Map
  /// Throws [FlagNotFoundException] if flag doesn't exist
  /// Throws [AuthenticationException] if SDK key is invalid
  /// Throws [ApiException] for other API errors
  Future<Map<String, dynamic>> evaluateFlag(
    String sdkKey,
    String flagKey,
    Map<String, dynamic> context,
    String valueType,
  ) async {
    // Build request payload
    final payload = {
      'flagKey': flagKey,
      'context': context,
      'valueType': valueType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_options.enableLogging) {
      print('[IntelliToggle] Evaluating flag: $flagKey with context: $context');
    }

    // Make HTTP request with retry logic
    final response = await _makeRequest(
      'POST',
      '/api/v1/flags/evaluate',
      headers: buildHeaders(sdkKey),
      body: jsonEncode(payload),
    );

    // Handle different response codes
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (_options.enableLogging) {
        print('[IntelliToggle] Flag evaluation result: $result');
      }

      return result;
    } else if (response.statusCode == 404) {
      throw FlagNotFoundException('Flag "$flagKey" not found');
    } else if (response.statusCode == 401) {
      throw AuthenticationException('Invalid SDK key');
    } else {
      throw ApiException('API request failed: ${response.statusCode}');
    }
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
        headers: buildHeaders(sdkKey),
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

  /// Make HTTP request with retry logic and exponential backoff
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
    final uri = _options.baseUri.resolve(path);
    int attempts = 0;

    while (attempts < _options.maxRetries) {
      try {
        if (_options.enableLogging) {
          print('[IntelliToggle] $method $uri (attempt ${attempts + 1})');
        }

        // Create the appropriate HTTP request
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

        // Execute request with timeout
        final response = await responseFuture.timeout(_options.timeout);

        if (_options.enableLogging) {
          print('[IntelliToggle] Response: ${response.statusCode}');
        }

        return response;
      } catch (error) {
        attempts++;

        if (_options.enableLogging) {
          print('[IntelliToggle] Request failed (attempt $attempts): $error');
        }

        // If max retries reached, rethrow the error
        if (attempts >= _options.maxRetries) {
          if (error is TimeoutException) {
            throw TimeoutException('Request timeout after ${_options.timeout}');
          }
          rethrow;
        }

        // Calculate exponential backoff delay with jitter
        final backoffDelay = Duration(
          milliseconds:
              _options.retryDelay.inMilliseconds *
              math.pow(2, attempts - 1).toInt(),
        );

        if (_options.enableLogging) {
          print('[IntelliToggle] Retrying in ${backoffDelay.inMilliseconds}ms');
        }

        await Future.delayed(backoffDelay);
      }
    }

    throw Exception('Max retries exceeded');
  }
}

/// Custom exceptions for IntelliToggle API errors
///
/// These exceptions provide specific error types for different API failure modes,
/// allowing for more targeted error handling in application code.

/// Exception thrown when a requested flag is not found
class FlagNotFoundException implements Exception {
  final String message;
  FlagNotFoundException(this.message);

  @override
  String toString() => 'FlagNotFoundException: $message';
}

/// Exception thrown when authentication fails (invalid SDK key)
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// General API exception for other HTTP errors
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
