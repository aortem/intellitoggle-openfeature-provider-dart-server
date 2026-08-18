import 'package:test/test.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() {
  group('IntelliToggleProvider Integration', () {
    late InMemoryProvider provider;
    late IntelliToggleClient client;

    setUp(() async {
      provider = InMemoryProvider();
      await provider.initialize();
      final clientMetadata = ClientMetadata(
        name: 'integration-test-client',
        version: '0.0.1',
      );
      final hookManager = HookManager();
      final defaultEvalContext = EvaluationContext(attributes: {});
      final featureClient = FeatureClient(
        metadata: clientMetadata,
        provider: provider,
        hookManager: hookManager,
        defaultContext: defaultEvalContext,
      );
      client = IntelliToggleClient(featureClient);
      provider.setFlag('integration-flag', true);
      provider.setFlag('flag1', true);
      provider.setFlag('flag2', false);
    });

    tearDown(() async {
      await provider.shutdown();
    });

    test('end-to-end: evaluates boolean flag', () async {
      final result = await client.getBooleanValue('integration-flag', false);
      expect(result, isTrue);
    });

    test('concurrent access: multiple flag evaluations', () async {
      final results = await Future.wait([
        client.getBooleanValue('flag1', false),
        client.getBooleanValue('flag2', true),
      ]);
      expect(results, [true, false]);
    });
  });
}
