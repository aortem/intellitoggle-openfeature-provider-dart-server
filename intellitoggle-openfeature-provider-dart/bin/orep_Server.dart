import 'dart:convert';
import 'dart:io';
import 'package:intellitoggle_openfeature/intellitoggle_openfeature.dart';

/// OREP-compliant HTTP server for remote flag evaluation.
/// Supports boolean, string, integer, double, and object flags.
Future<void> main() async {
  final provider = InMemoryProvider();

  // Example: Seed some flags for demo/testing
  provider.setFlag('bool-flag', true);
  provider.setFlag('string-flag', 'hello');
  provider.setFlag('int-flag', 42);
  provider.setFlag('double-flag', 3.14);
  provider.setFlag('object-flag', {'foo': 'bar', 'enabled': true});

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('OREP server running on http://localhost:8080');

  await for (HttpRequest req in server) {
    // OREP: /v1/flags/{flagKey}/evaluate
    final segments = req.uri.pathSegments;
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
    } else {
      req.response.statusCode = 404;
      await req.response.close();
    }
  }
}

/// Infer OREP type from Dart value.
String _inferType(dynamic value) {
  if (value is bool) return 'boolean';
  if (value is int) return 'integer';
  if (value is double) return 'double';
  if (value is String) return 'string';
  if (value is Map<String, dynamic>) return 'object';
  return 'string';
}

/// Format OREP-compliant response.
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