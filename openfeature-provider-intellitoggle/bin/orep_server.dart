import 'dart:convert';
import 'dart:io';

import 'package:jwt_generator/jwt_generator.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart'
    hide InMemoryProvider;
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

final IntelliToggleContextProcessor _contextProcessor =
    IntelliToggleContextProcessor();

Future<FeatureProvider> _createProvider() async {
  final mode = (Platform.environment['OREP_PROVIDER_MODE'] ?? 'inmemory')
      .toLowerCase();
  if (mode == 'intellitoggle') {
    final clientId = Platform.environment['INTELLITOGGLE_CLIENT_ID'];
    final clientSecret = Platform.environment['INTELLITOGGLE_CLIENT_SECRET'];
    final tenantId = Platform.environment['INTELLITOGGLE_TENANT_ID'];
    if (clientId == null ||
        clientSecret == null ||
        tenantId == null ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        tenantId.isEmpty) {
      throw StateError(
        'INTELLITOGGLE_CLIENT_ID, INTELLITOGGLE_CLIENT_SECRET, and INTELLITOGGLE_TENANT_ID must be set when OREP_PROVIDER_MODE=intellitoggle',
      );
    }
    final env = (Platform.environment['INTELLITOGGLE_ENV'] ?? 'production')
        .toLowerCase();
    final options = env == 'development'
        ? IntelliToggleOptions.development()
        : IntelliToggleOptions.production();
    final provider = IntelliToggleProvider(
      clientId: clientId,
      clientSecret: clientSecret,
      tenantId: tenantId,
      options: options,
    );
    await provider.initialize();
    return provider;
  }

  final inMemory = InMemoryProvider();
  // Example: Seed some flags for demo/testing
  inMemory.setFlag('bool-flag', true);
  inMemory.setFlag('string-flag', 'hello');
  inMemory.setFlag('int-flag', 42);
  inMemory.setFlag('double-flag', 3.14);
  inMemory.setFlag('object-flag', {'foo': 'bar', 'enabled': true});
  return inMemory;
}

Future<void> main() async {
  final provider = await _createProvider();
  final inMemory = provider is InMemoryProvider
      ? provider as InMemoryProvider
      : null;

  final host = Platform.environment['OREP_HOST'] ?? '0.0.0.0';
  final port =
      int.tryParse(Platform.environment['OREP_PORT'] ?? '8080') ?? 8080;
  final server = await HttpServer.bind(host, port);
  print('OREP/OPTSP server running on http://$host:$port');

  final requiredToken =
      Platform.environment['OREP_AUTH_TOKEN'] ?? 'changeme-token';

  await for (HttpRequest req in server) {
    // --- Simple Bearer token authentication ---
    if (!await _isAuthorized(req, requiredToken)) {
      req.response.statusCode = 401;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'error': 'Unauthorized'}));
      await req.response.close();
      continue;
    }

    try {
      final segments = req.uri.pathSegments;

      // --- OREP: Flag Evaluation ---
      if ((req.method == 'POST' || req.method == 'GET') &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'flags' &&
          segments[3] == 'evaluate') {
        final flagKey = segments[2];

        // Prepare payload from POST body or GET query params
        Map<String, dynamic> payload = {};
        if (req.method == 'POST') {
          final body = await utf8.decoder.bind(req).join();
          try {
            payload = body.isNotEmpty ? jsonDecode(body) : {};
          } catch (e) {
            req.response.statusCode = 400;
            req.response.headers.contentType = ContentType.json;
            req.response.write(
              jsonEncode({'error': 'Invalid JSON', 'details': e.toString()}),
            );
            await req.response.close();
            continue;
          }
        } else {
          // GET: type, default, context (JSON) via query params
          final qp = req.uri.queryParameters;
          payload = {
            'type': qp['type'],
            'defaultValue': _parseDefault(qp['default'], qp['type']),
            'context': _parseContext(qp['context']),
          }..removeWhere((k, v) => v == null);
        }

        if (!payload.containsKey('defaultValue') ||
            !payload.containsKey('type')) {
          req.response.statusCode = 400;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'error': 'Missing required fields: defaultValue and type',
            }),
          );
          await req.response.close();
          continue;
        }

        final type = payload['type'];
        const allowedTypes = [
          'boolean',
          'string',
          'integer',
          'double',
          'float',
          'object',
        ];
        if (!allowedTypes.contains(type)) {
          req.response.statusCode = 400;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'error': 'Invalid flag type',
              'allowedTypes': allowedTypes,
            }),
          );
          await req.response.close();
          continue;
        }

        // 404 when flag key does not exist (OFREP-guidance, in-memory only)
        if (inMemory != null && !inMemory.hasFlag(flagKey)) {
          req.response.statusCode = 404;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({'error': 'Flag not found', 'flagKey': flagKey}),
          );
          await req.response.close();
          continue;
        }

        final context = (payload['context'] as Map<String, dynamic>?) ?? {};
        final defaultValue = payload['defaultValue'];

        final processedContext = processContext(context);

        dynamic result;
        try {
          switch (type) {
            case 'boolean':
              result = await provider.getBooleanFlag(
                flagKey,
                defaultValue == null ? false : defaultValue as bool,
                context: processedContext,
              );
              break;
            case 'string':
              result = await provider.getStringFlag(
                flagKey,
                defaultValue == null ? '' : defaultValue as String,
                context: processedContext,
              );
              break;
            case 'integer':
              result = await provider.getIntegerFlag(
                flagKey,
                defaultValue == null ? 0 : defaultValue as int,
                context: processedContext,
              );
              break;
            case 'double':
            case 'float':
              result = await provider.getDoubleFlag(
                flagKey,
                defaultValue == null ? 0.0 : (defaultValue as num).toDouble(),
                context: processedContext,
              );
              break;
            case 'object':
              result = await provider.getObjectFlag(
                flagKey,
                defaultValue == null
                    ? <String, dynamic>{}
                    : defaultValue as Map<String, dynamic>,
                context: processedContext,
              );
              break;
            default:
              throw Exception('Unsupported flag type: $type');
          }
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode(_orepResponse(result, type)));
        } catch (e) {
          req.response.statusCode = 400;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({'error': 'Evaluation failed', 'details': e.toString()}),
          );
        }
        await req.response.close();
        continue;
      }

      // --- OPTSP: Provider Metadata ---
      if (req.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'provider' &&
          segments[2] == 'metadata') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'name': provider.name,
            'version': '1.0.0', // Set your provider version here
            'capabilities': ['seed', 'reset', 'shutdown', 'evaluate'],
          }),
        );
        await req.response.close();
        continue;
      }

      // --- OPTSP: Seed Flags ---
      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'provider' &&
          segments[2] == 'seed') {
        if (inMemory == null) {
          req.response.statusCode = 501;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'error':
                  'Seeding flags is only supported when using the InMemoryProvider.',
            }),
          );
          await req.response.close();
          continue;
        }
        final body = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> payload = body.isNotEmpty
            ? jsonDecode(body)
            : {};
        final flags = payload['flags'] as Map<String, dynamic>? ?? {};
        inMemory.clearFlags();
        flags.forEach((k, v) => inMemory.setFlag(k, v));
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'status': 'ok'}));
        await req.response.close();
        continue;
      }

      // --- OPTSP: Reset Provider ---
      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'provider' &&
          segments[2] == 'reset') {
        if (inMemory == null) {
          req.response.statusCode = 501;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'error':
                  'Reset is only supported when using the InMemoryProvider.',
            }),
          );
          await req.response.close();
          continue;
        }
        inMemory.clearFlags();
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'status': 'ok'}));
        await req.response.close();
        continue;
      }

      // --- OPTSP: Shutdown Provider ---
      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'provider' &&
          segments[2] == 'shutdown') {
        await provider.shutdown();
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'status': 'ok'}));
        await req.response.close();
        // Optionally, shut down the HTTP server as well
        await server.close(force: true);
        break;
      }

      // --- OPTSP: Provider State (optional) ---
      if (req.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'provider' &&
          segments[2] == 'state') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'state': provider.state.toString()}));
        await req.response.close();
        continue;
      }

      // --- 404 Not Found ---
      req.response.statusCode = 404;
      await req.response.close();
    } catch (e, st) {
      req.response.statusCode = 400;
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode({
          'error': 'Bad Request',
          'details': e.toString(),
          'stack': st.toString(),
        }),
      );
      await req.response.close();
    }
  }
}

Map<String, dynamic> _orepResponse(dynamic result, String type) {
  return {
    'flagKey': result.flagKey,
    'type': type,
    'value': result.value,
    'reason': result.reason,
    'evaluatedAt': result.evaluatedAt.toIso8601String(),
    'evaluatorId': result.evaluatorId,
  };
}

Map<String, dynamic> processContext(Map<String, dynamic> context) {
  final mode = (Platform.environment['OREP_PROVIDER_MODE'] ?? 'inmemory')
      .toLowerCase();
  if (mode == 'intellitoggle') {
    return _contextProcessor.processContext(context);
  }
  // In-memory mode: keep context usage flexible for tests
  return context;
}

bool _isBearer(String? authHeader) =>
    authHeader != null && authHeader.toLowerCase().startsWith('bearer ');

Future<bool> _isAuthorized(HttpRequest req, String requiredToken) async {
  final authHeader = req.headers.value('authorization');
  if (!_isBearer(authHeader)) return false;
  final token = authHeader!.substring(7);

  // First, allow API key mode when token matches required token
  if (token == requiredToken && requiredToken.isNotEmpty) return true;

  // Optional JWT HS256 verification using internal library
  final hsSecret = Platform.environment['OAUTH_JWT_HS256_SECRET'];
  if (hsSecret != null && hsSecret.isNotEmpty) {
    try {
      final parsed = ParsedJwt.parse(token);
      final verifier = HmacSignatureVerifier(secret: utf8.encode(hsSecret));
      final ok = verifier.verify(parsed.signingInput, parsed.signatureB64);
      if (!ok) return false;
      // Optional claim checks
      final expectedAud = Platform.environment['OAUTH_EXPECTED_AUD'];
      final expectedIss = Platform.environment['OAUTH_EXPECTED_ISS'];
      if (expectedAud != null || expectedIss != null) {
        final payload = _decodeJwtPayload(token);
        if (expectedAud != null && payload['aud'] != expectedAud) return false;
        if (expectedIss != null && payload['iss'] != expectedIss) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  return false;
}

Map<String, dynamic> _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final payloadBytes = base64.decode(normalized);
    final jsonStr = utf8.decode(payloadBytes);
    final map = jsonDecode(jsonStr);
    return map is Map<String, dynamic> ? map : {};
  } catch (_) {
    return {};
  }
}

dynamic _parseDefault(String? raw, String? type) {
  if (raw == null || type == null) return null;
  switch (type) {
    case 'boolean':
      return raw.toLowerCase() == 'true';
    case 'integer':
      return int.tryParse(raw);
    case 'double':
    case 'float':
      return double.tryParse(raw);
    case 'string':
      return raw;
    case 'object':
      try {
        final val = jsonDecode(raw);
        return (val is Map<String, dynamic>) ? val : null;
      } catch (_) {
        return null;
      }
  }
  return null;
}

Map<String, dynamic> _parseContext(String? raw) {
  if (raw == null) return {};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  } catch (_) {
    return {};
  }
}
