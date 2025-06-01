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
}