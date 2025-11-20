import 'package:test/test.dart';

import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

import '../lib/utils/telemetry.dart';
import '../lib/src/client.dart';
import '../lib/src/in_memory_provider.dart';
import '../lib/hooks/intellitoggle_telemetry_hook.dart';

void main() {
  test('Telemetry smoke test runs end-to-end', () async {
    // 1. Create in-memory provider and set flags
    final provider = InMemoryProvider();
    provider.setFlag('test-flag', true);

    
    // Build HookManager with telemetry hook
    final hookManager = HookManager()
      ..addHook(IntelliToggleTelemetryHook());

    // Build FeatureClient from SDK
    final featureClient = FeatureClient(
      metadata: ClientMetadata(name: 'smoke-client'),
      hookManager: hookManager,
      defaultContext: EvaluationContext(attributes: {}),
      provider: provider,
    );

    // 3. Wrap with IntelliToggleClient
    final client = IntelliToggleClient(featureClient);

    // 4. Evaluate flag
    final value = await client.getBooleanValue(
      'test-flag',
      false,
      targetingKey: 'user-1',
      evaluationContext: {'role': 'tester'},
    );

    print('\nFlag value: $value');

    print('\n---- TELEMETRY METRICS ----');
    print(Telemetry.metrics.counters);

    print('\n---- TELEMETRY LATENCY ----');
    print(Telemetry.metrics.latencyHistogram);

    // ✅ Assertions
    expect(value, true);
    expect(Telemetry.metrics.counters['feature_flag.evaluation_count'], greaterThan(0));
    expect(Telemetry.metrics.counters['feature_flag.evaluation_success_count'], greaterThan(0));
    expect(Telemetry.metrics.latencyHistogram['test-flag'], isNotEmpty);
    expect(Telemetry.metrics.latencyHistogram['test-flag'], isA<Map<int, int>>());

    print('\n✅ All tests passed!');
  });
}