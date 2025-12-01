// test.dart
import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  print('Starting IntelliToggle provider test with OAuth2...\n');

  final provider = IntelliToggleProvider(
    clientId: "client_id",
    clientSecret: "cs_secret",
    tenantId: "tenant_id",
    options: IntelliToggleOptions(
      // baseUri: Uri.parse("https://api.intellitoggle.com"),
      // timeout: const Duration(seconds: 10),
      // enableLogging: true,
    ),
  );

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

  // Evaluate your feature flags
  final newFeatureEnabled = await client.getBooleanValue(
    'new-dashboard-ui',
    false,
  );

  print('Flag value: ${newFeatureEnabled}');

  await provider.shutdown();
  print('✓ Test completed successfully!');
}
