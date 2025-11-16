import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

const _testToken = 'changeme-token';

Future<void> _waitForServer() async {
  final client = HttpClient();
  final uri = Uri.parse('http://localhost:8080/v1/provider/metadata');
  for (var i = 0; i < 50; i++) {
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 1));
      req.headers.add('authorization', 'Bearer $_testToken');
      final resp = await req.close();
      await resp.drain();
      if (resp.statusCode == 200) {
        client.close();
        return;
      }
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  client.close();
  throw StateError('OREP HTTP server did not start in time');
}

Future<void> _seedBoolFlag() async {
  final client = HttpClient();
  final uri = Uri.parse('http://localhost:8080/v1/provider/seed');
  final req = await client.postUrl(uri);
  req.headers.contentType = ContentType.json;
  req.headers.add('authorization', 'Bearer $_testToken');
  req.write(jsonEncode({'flags': {'bool-flag': true}}));
  final resp = await req.close();
  await resp.drain();
  client.close();
}

void main() {
  late Process serverProcess;

  setUpAll(() async {
    serverProcess = await Process.start(
      Platform.executable,
      ['run', 'bin/orep_server.dart'],
      environment: {
        ...Platform.environment,
        'OREP_AUTH_TOKEN': _testToken,
        'OREP_HOST': '127.0.0.1',
        'OREP_PORT': '8080',
      },
    );
    await _waitForServer();
    await _seedBoolFlag();
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  test('OREP boolean flag evaluation endpoint returns correct value', () async {
    final client = HttpClient();
    final req = await client.postUrl(Uri.parse('http://localhost:8080/v1/flags/bool-flag/evaluate'));
    req.headers.contentType = ContentType.json;
    req.headers.add('authorization', 'Bearer $_testToken');
    req.write(jsonEncode({'defaultValue': false, 'type': 'boolean', 'context': {}}));
    final resp = await req.close();
    expect(resp.statusCode, 200);

    final body = await utf8.decoder.bind(resp).join();
    final json = jsonDecode(body);
    expect(json['flagKey'], 'bool-flag');
    expect(json['type'], 'boolean');
    expect(json['value'], true);
    expect(json['reason'], 'STATIC');
    expect(json['evaluatorId'], 'InMemoryProvider');
  });

  test('OPTSP metadata endpoint returns provider info', () async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://localhost:8080/v1/provider/metadata'));
    req.headers.add('authorization', 'Bearer $_testToken');
    final resp = await req.close();
    expect(resp.statusCode, 200);
    final body = await utf8.decoder.bind(resp).join();
    final json = jsonDecode(body);
    expect(json['name'], isNotEmpty);
    expect(json['capabilities'], contains('seed'));
  });

  test('OPTSP seed and reset endpoints work', () async {
    final client = HttpClient();
    // Seed
    var req = await client.postUrl(Uri.parse('http://localhost:8080/v1/provider/seed'));
    req.headers.contentType = ContentType.json;
    req.headers.add('authorization', 'Bearer $_testToken');
    req.write(jsonEncode({'flags': {'test-flag': 123}}));
    var resp = await req.close();
    expect(resp.statusCode, 200);

    // Reset
    req = await client.postUrl(Uri.parse('http://localhost:8080/v1/provider/reset'));
    req.headers.add('authorization', 'Bearer $_testToken');
    resp = await req.close();
    expect(resp.statusCode, 200);
  });

  test('OREP returns 400 on invalid JSON', () async {
    final client = HttpClient();
    final req = await client.postUrl(Uri.parse('http://localhost:8080/v1/flags/bool-flag/evaluate'));
    req.headers.contentType = ContentType.json;
    req.headers.add('authorization', 'Bearer $_testToken');
    req.write('not a json');
    final resp = await req.close();
    expect(resp.statusCode, 400);
    final body = await utf8.decoder.bind(resp).join();
    expect(body, contains('Invalid JSON'));
  });
}
