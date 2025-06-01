import 'dart:convert';
import 'dart:io';
import 'package:intellitoggle_openfeature/intellitoggle_openfeature.dart';

Future<void> main() async {
  final provider = InMemoryProvider();

  // Example: Seed some flags for demo/testing
  provider.setFlag('bool-flag', true);
  provider.setFlag('string-flag', 'hello');
  provider.setFlag('int-flag', 42);
  provider.setFlag('double-flag', 3.14);
  provider.setFlag('object-flag', {'foo': 'bar', 'enabled': true});

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('OREP/OPTSP server running on http://localhost:8080');

  await for (HttpRequest req in server) {
    final segments = req.uri.pathSegments;

    // --- OREP: Flag Evaluation ---
    if (req.method == 'POST' &&
        segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'flags' &&
        segments[3] == 'evaluate') {
      final flagKey = segments[2];
      final body = await utf8.decoder.bind(req).join();
      final Map<String, dynamic> payload = body.isNotEmpty ? jsonDecode(body) : {};

      final context = payload['context'] as Map<String, dynamic>? ?? {};
      final defaultValue = payload['defaultValue'];
      final type = payload['type'] as String? ?? _inferType(defaultValue);

      dynamic result;
      try {
        switch (type) {
          case 'boolean':
            result = await provider.getBooleanFlag(flagKey, defaultValue == null ? false : defaultValue as bool, context: context);
            break;
          case 'string':
            result = await provider.getStringFlag(flagKey, defaultValue == null ? '' : defaultValue as String, context: context);
            break;
          case 'integer':
            result = await provider.getIntegerFlag(flagKey, defaultValue == null ? 0 : defaultValue as int, context: context);
            break;
          case 'double':
          case 'float':
            result = await provider.getDoubleFlag(flagKey, defaultValue == null ? 0.0 : (defaultValue as num).toDouble(), context: context);
            break;
          case 'object':
            result = await provider.getObjectFlag(flagKey, defaultValue == null ? <String, dynamic>{} : defaultValue as Map<String, dynamic>, context: context);
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
        req.response.write(jsonEncode({
          'error': 'Evaluation failed',
          'details': e.toString(),
        }));
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
      req.response.write(jsonEncode({
        'name': provider.name,
        'version': '1.0.0', // Set your provider version here
        'capabilities': ['seed', 'reset', 'shutdown', 'evaluate'],
      }));
      await req.response.close();
      continue;
    }

    // --- OPTSP: Seed Flags ---
    if (req.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'provider' &&
        segments[2] == 'seed') {
      final body = await utf8.decoder.bind(req).join();
      final Map<String, dynamic> payload = body.isNotEmpty ? jsonDecode(body) : {};
      final flags = payload['flags'] as Map<String, dynamic>? ?? {};
      provider.clearFlags();
      flags.forEach((k, v) => provider.setFlag(k, v));
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
      provider.clearFlags();
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
      req.response.write(jsonEncode({
        'state': provider.state.toString(),
      }));
      await req.response.close();
      continue;
    }

    // --- 404 Not Found ---
    req.response.statusCode = 404;
    await req.response.close();
  }
}

String _inferType(dynamic value) {
  if (value is bool) return 'boolean';
  if (value is int) return 'integer';
  if (value is double) return 'double';
  if (value is String) return 'string';
  if (value is Map<String, dynamic>) return 'object';
  return 'string';
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