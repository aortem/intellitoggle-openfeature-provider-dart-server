import 'package:test/test.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  group('IntelliToggleProvider Integration', () {
    late IntelliToggleProvider provider;
    late IntelliToggleClient client;

    setUp(() async {
      provider = IntelliToggleProvider(
        sdkKey: 'test-key',
        options: IntelliToggleOptions(
          baseUri: Uri.parse('http://localhost:8080'),
          enableLogging: false,
          enablePolling: false,
          maxRetries: 1,
        ),
        httpClient: http.Client(),
      );
      await provider.initialize();
      await OpenFeatureAPI().setProvider(provider);
      client = IntelliToggleClient(namespace: 'integration');
    });

    tearDown(() async {
      await provider.shutdown();
    });

    test('end-to-end: evaluates boolean flag', () async {
      provider.setFlag('integration-flag', true);
      final result = await client.getBooleanValue('integration-flag', false);
      expect(result, true);
    });

    test('network failure: returns default on error', () async {
      final badProvider = IntelliToggleProvider(
        sdkKey: 'bad-key',
        options: IntelliToggleOptions(
          baseUri: Uri.parse('http://localhost:9999'),
          enableLogging: false,
          enablePolling: false,
          maxRetries: 1,
        ),
        httpClient: http.Client(),
      );
      await badProvider.initialize().catchError((_) {});
      await OpenFeatureAPI().setProvider(badProvider);
      final badClient = IntelliToggleClient(namespace: 'fail');
      final result = await badClient.getBooleanValue('any-flag', false);
      expect(result, false);
    });

    test('concurrent access: multiple flag evaluations', () async {
      provider.setFlag('flag1', true);
      provider.setFlag('flag2', false);
      final results = await Future.wait([
        client.getBooleanValue('flag1', false),
        client.getBooleanValue('flag2', true),
      ]);
      expect(results, [true, false]);
    });
  });
}
