import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

const _goodToken = 'changeme-token';
const _badToken = 'bad-token';
const _port = 59990;

String _baseUrl(String path) => 'http://localhost:$_port$path';

Future<void> _waitForServer() async {
  final client = HttpClient();
  final uri = Uri.parse(_baseUrl('/v1/provider/metadata'));
  for (var i = 0; i < 50; i++) {
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 1));
      req.headers.add('authorization', 'Bearer $_goodToken');
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
  throw StateError('OREP HTTP server did not start in time (parity tests)');
}

Future<void> _seedBoolFlag() async {
  final client = HttpClient();
  final uri = Uri.parse(_baseUrl('/v1/provider/seed'));
  final req = await client.postUrl(uri);
  req.headers.contentType = ContentType.json;
  req.headers.add('authorization', 'Bearer $_goodToken');
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
        'OREP_AUTH_TOKEN': _goodToken,
        'OREP_HOST': '127.0.0.1',
        'OREP_PORT': '$_port',
      },
    );
    await _waitForServer();
    await _seedBoolFlag();
  });

  tearDownAll(() async {
    serverProcess.kill();
    await serverProcess.exitCode;
  });

  group('OREP HTTP parity and auth', () {
    test('GET evaluate matches POST evaluate (boolean)', () async {
      // Ensure server has the flag (tests may have reset earlier)
      {
        final client = HttpClient();
        final seed = await client.postUrl(Uri.parse(_baseUrl('/v1/provider/seed')));
        seed.headers.contentType = ContentType.json;
        seed.headers.add('authorization', 'Bearer $_goodToken');
        seed.write(jsonEncode({'flags': {'bool-flag': true}}));
        final seedResp = await seed.close();
        expect(seedResp.statusCode, 200);
      }
      // POST
      final client = HttpClient();
      final post = await client
          .postUrl(Uri.parse(_baseUrl('/v1/flags/bool-flag/evaluate')));
      post.headers.contentType = ContentType.json;
      post.headers.add('authorization', 'Bearer $_goodToken');
      post.write(jsonEncode({'defaultValue': false, 'type': 'boolean'}));
      final postResp = await post.close();
      expect(postResp.statusCode, 200);
      final postJson = jsonDecode(await utf8.decoder.bind(postResp).join());

      // GET
      final get = await client.getUrl(Uri.parse(
          _baseUrl('/v1/flags/bool-flag/evaluate?type=boolean&default=false')));
      get.headers.add('authorization', 'Bearer $_goodToken');
      final getResp = await get.close();
      expect(getResp.statusCode, 200);
      final getJson = jsonDecode(await utf8.decoder.bind(getResp).join());

      expect(getJson['value'], postJson['value']);
      expect(getJson['type'], postJson['type']);
    });

    test('Unauthorized returns 401', () async {
      final client = HttpClient();
      final req = await client
          .postUrl(Uri.parse(_baseUrl('/v1/flags/bool-flag/evaluate')));
      req.headers.contentType = ContentType.json;
      req.headers.add('authorization', 'Bearer $_badToken');
      req.write(jsonEncode({'defaultValue': false, 'type': 'boolean'}));
      final resp = await req.close();
      expect(resp.statusCode, 401);
    });

    test('Unknown flag returns 404', () async {
      final client = HttpClient();
      final req = await client
          .postUrl(Uri.parse(_baseUrl('/v1/flags/does-not-exist/evaluate')));
      req.headers.contentType = ContentType.json;
      req.headers.add('authorization', 'Bearer $_goodToken');
      req.write(jsonEncode({'defaultValue': false, 'type': 'boolean'}));
      final resp = await req.close();
      expect(resp.statusCode, 404);
    });
  });
}
