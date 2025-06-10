import 'package:test/test.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';

void main() {
  group('IntelliToggleClient', () {
    late IntelliToggleClient client;
    late InMemoryProvider provider;

    setUp(() async {
      provider = InMemoryProvider();
      await OpenFeatureAPI().setProvider(provider);
      client = IntelliToggleClient(namespace: 'test');
    });

    test('getBooleanValue returns correct value', () async {
      provider.setFlag('bool-flag', true);
      final result = await client.getBooleanValue('bool-flag', false);
      expect(result, true);
    });

    test('getStringValue returns correct value', () async {
      provider.setFlag('str-flag', 'hello');
      final result = await client.getStringValue('str-flag', 'default');
      expect(result, 'hello');
    });

    test('getIntegerValue returns correct value', () async {
      provider.setFlag('int-flag', 42);
      final result = await client.getIntegerValue('int-flag', 0);
      expect(result, 42);
    });

    test('getDoubleValue returns correct value', () async {
      provider.setFlag('dbl-flag', 3.14);
      final result = await client.getDoubleValue('dbl-flag', 0.0);
      expect(result, 3.14);
    });

    test('getObjectValue returns correct value', () async {
      provider.setFlag('obj-flag', {'foo': 'bar'});
      final result = await client.getObjectValue('obj-flag', {});
      expect(result, containsPair('foo', 'bar'));
    });

    test('context building: passes context to provider', () async {
      provider.setFlag('ctx-flag', true);
      final ctx = {'targetingKey': 'user-1', 'email': 'a@b.com'};
      final result = await client.getBooleanValue('ctx-flag', false, evaluationContext: ctx);
      expect(result, true);
    });

    test('multi-context: supports multi-context evaluation', () async {
      provider.setFlag('multi-flag', 'multi');
      final ctx = {
        'kind': 'multi',
        'user': {'targetingKey': 'user-1'},
        'org': {'targetingKey': 'org-1'}
      };
      final result = await client.getStringValue('multi-flag', 'default', evaluationContext: ctx);
      expect(result, 'multi');
    });

    test('error handling: returns default on missing flag', () async {
      final result = await client.getBooleanValue('missing-flag', false);
      expect(result, false);
    });

    test('error handling: throws on type mismatch', () async {
      provider.setFlag('flag', 123);
      expect(
        () async => await client.getBooleanValue('flag', false),
        throwsA(isA<Exception>()),
      );
    });
  });
}
