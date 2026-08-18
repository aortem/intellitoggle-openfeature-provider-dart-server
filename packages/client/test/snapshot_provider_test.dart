import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';
import 'package:test/test.dart';

void main() {
  group('IntelliToggleClientProvider', () {
    test('resolves backend-provided values through OpenFeature', () async {
      final provider = IntelliToggleClientProvider(
        IntelliToggleClientSnapshot({
          'enabled': IntelliToggleClientFlag(
            value: true,
            reason: 'TARGETING_MATCH',
            variant: 'on',
            flagMetadata: const {'source': 'backend'},
          ),
          'message': IntelliToggleClientFlag(value: 'hello'),
          'count': IntelliToggleClientFlag(value: 3),
          'ratio': IntelliToggleClientFlag(value: 0.5),
          'config': IntelliToggleClientFlag(
            value: <String, Object?>{
              'placement': 'home',
              'formats': <Object?>['video'],
            },
          ),
        }),
      );

      await OpenFeatureAPI.instance.setProviderAndWait(provider);
      final client = OpenFeatureAPI.instance.getClient('test-app');

      final details = client.getBooleanDetails('enabled', false);
      expect(details.value, isTrue);
      expect(details.reason, 'TARGETING_MATCH');
      expect(details.variant, 'on');
      expect(details.flagMetadata, {'source': 'backend'});
      expect(client.getStringValue('message', ''), 'hello');
      expect(client.getIntegerValue('count', 0), 3);
      expect(client.getDoubleValue('ratio', 0), 0.5);
      expect(client.getStructureValue('config', const {}), {
        'placement': 'home',
        'formats': ['video'],
      });

      await OpenFeatureAPI.instance.shutdown();
    });

    test('returns caller defaults for missing flags and type mismatches', () {
      final provider = IntelliToggleClientProvider.fromValues({
        'string-flag': 'value',
      });

      final missing = provider.resolveBooleanValue(
        'missing',
        false,
        EvaluationContext.empty,
      );
      final mismatch = provider.resolveBooleanValue(
        'string-flag',
        false,
        EvaluationContext.empty,
      );

      expect(missing.value, isFalse);
      expect(missing.errorCode, ErrorCode.flagNotFound);
      expect(mismatch.value, isFalse);
      expect(mismatch.errorCode, ErrorCode.typeMismatch);
    });

    test('replaces immutable snapshots and emits changed keys', () async {
      final mutableConfig = <String, Object?>{
        'formats': <Object?>['video'],
      };
      final provider = IntelliToggleClientProvider.fromValues({
        'ads-enabled': true,
        'config': mutableConfig,
      });
      final eventFuture = provider.events.first;

      mutableConfig['formats'] = <Object?>['mutated'];
      final original = provider.resolveStructureValue(
        'config',
        const {},
        EvaluationContext.empty,
      );
      expect(original.value, {
        'formats': ['video'],
      });

      provider.replaceValues({'ads-enabled': false, 'placement': 'home'});
      final event = await eventFuture;
      expect(event.type, ProviderEventType.configurationChanged);
      expect(event.flagsChanged, ['ads-enabled', 'config', 'placement']);
      expect(
        provider
            .resolveBooleanValue('ads-enabled', true, EvaluationContext.empty)
            .value,
        isFalse,
      );

      await provider.shutdown();
    });

    test('rejects invalid client snapshot values', () {
      expect(
        () => IntelliToggleClientProvider.fromValues({
          'unsupported': DateTime.utc(2026),
        }),
        throwsArgumentError,
      );
      expect(
        () => IntelliToggleClientProvider.fromValues({'': true}),
        throwsArgumentError,
      );
    });
  });
}
