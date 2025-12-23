// test.dart
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

void main() async {
  print('Starting IntelliToggle provider test with InMemoryProvider...\n');

  final provider = InMemoryProvider();

  print('Provider created, initializing...');
  await provider.initialize();
  print('✓ Provider initialized successfully!\n');

  final api = OpenFeatureAPI();
  api.setProvider(provider);

  // Create a client
  final clientMetadata = ClientMetadata(name: 'test-client', version: '0.0.1');
  final hookManager = HookManager();
  final defaultEvalContext = EvaluationContext(attributes: {});
  final featureClient = FeatureClient(
    metadata: clientMetadata,
    provider: provider,
    hookManager: hookManager,
    defaultContext: defaultEvalContext,
  );
  final client = IntelliToggleClient(featureClient);

  provider.setFlag('bool-flag', true);

  // Evaluate your feature flags
  final newFeatureEnabled = await client.getBooleanValue('bool-flag', false);

  print(newFeatureEnabled);

  await provider.shutdown();
  print('✓ Test completed successfully!');
}
