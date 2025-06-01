import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('OREP boolean flag evaluation endpoint returns correct value', () async {
    // Assumes orep_server.dart is running on localhost:8080
    final client = HttpClient();
    final req = await client.postUrl(Uri.parse('http://localhost:8080/v1/flags/bool-flag/evaluate'));
    req.headers.contentType = ContentType.json;
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
    req.write(jsonEncode({'flags': {'test-flag': 123}}));
    var resp = await req.close();
    expect(resp.statusCode, 200);

    // Reset
    req = await client.postUrl(Uri.parse('http://localhost:8080/v1/provider/reset'));
    resp = await req.close();
    expect(resp.statusCode, 200);
  });
}