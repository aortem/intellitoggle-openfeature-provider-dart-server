import 'dart:convert';

import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';
import 'package:test/test.dart';

void main() {
  group('IntelliToggleClientProvider', () {
    test('invalidates values and completes context reconciliation', () async {
      final api = OpenFeatureAPI.instance;
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-a'),
      );
      final provider = IntelliToggleClientProvider.fromValues({
        'paid-feature': true,
      });
      await api.setProviderAndWait(provider);
      final client = api.getClient('context-test');
      expect(client.getBooleanValue('paid-feature', false), isTrue);

      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-b'),
      );

      final details = client.getBooleanDetails('paid-feature', false);
      expect(details.value, isFalse);
      expect(details.errorCode, ErrorCode.flagNotFound);
    });

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

      provider.replaceValues({
        'ads-enabled': false,
        'config': <String, Object?>{
          'formats': <Object?>['video'],
        },
        'placement': 'home',
      });
      final event = await eventFuture;
      expect(event.type, ProviderEventType.configurationChanged);
      expect(event.flagsChanged, ['ads-enabled', 'placement']);
      expect(
        provider
            .resolveBooleanValue('ads-enabled', true, EvaluationContext.empty)
            .value,
        isFalse,
      );

      await provider.shutdown();
    });

    test('parses full and flat JSON snapshots', () {
      final decoded =
          jsonDecode('''
        {
          "flags": {
            "ratio": {
              "value": 1,
              "reason": "TARGETING_MATCH",
              "variant": "all",
              "metadata": {"source": "backend"}
            }
          }
        }
      ''')
              as Map<String, Object?>;
      final provider = IntelliToggleClientProvider(
        IntelliToggleClientSnapshot.fromJson(decoded),
      );

      final ratio = provider.resolveDoubleValue(
        'ratio',
        0,
        EvaluationContext.empty,
      );
      expect(ratio.value, 1.0);
      expect(ratio.errorCode, isNull);
      expect(ratio.reason, 'TARGETING_MATCH');
      expect(ratio.variant, 'all');
      expect(ratio.flagMetadata, {'source': 'backend'});

      final flat = IntelliToggleClientProvider(
        IntelliToggleClientSnapshot.fromJson(
          jsonDecode('{"enabled": true}') as Map<String, Object?>,
        ),
      );
      expect(
        flat
            .resolveBooleanValue('enabled', false, EvaluationContext.empty)
            .reason,
        'CACHED',
      );
    });

    test('reports shutdown state and enforces single-use updates', () async {
      final provider = IntelliToggleClientProvider.fromValues({'flag': true});
      expect(provider.isShutDown, isFalse);

      await provider.shutdown();
      await provider.shutdown();

      expect(provider.isShutDown, isTrue);
      expect(
        provider
            .resolveBooleanValue('flag', false, EvaluationContext.empty)
            .errorCode,
        ErrorCode.providerNotReady,
      );
      expect(() => provider.replaceValues({'flag': false}), throwsStateError);
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
      expect(
        () => IntelliToggleClientProvider.fromValues({
          'nested': <String, Object?>{'unsupported': DateTime.utc(2026)},
        }),
        throwsArgumentError,
      );
      expect(
        () => IntelliToggleClientSnapshot.fromJson(
          jsonDecode('{"broken": null}') as Map<String, Object?>,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'message',
            contains('broken'),
          ),
        ),
      );
      expect(
        () => IntelliToggleClientSnapshot.fromJson({
          'flags': <String, Object?>{
            'bad-metadata': <String, Object?>{
              'value': true,
              'metadata': <String, Object?>{'nested': <String, Object?>{}},
            },
          },
        }),
        throwsArgumentError,
      );
    });
  });
}
