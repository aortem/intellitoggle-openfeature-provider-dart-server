import 'dart:async';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

Future<void> main() async {
  // 1. Configure and register the provider
  final provider = IntelliToggleProvider(
    sdkKey: 'YOUR_SDK_KEY',
    options: IntelliToggleOptions(
      baseUri: Uri.parse('https://api.intellitoggle.com'),
      timeout: const Duration(seconds: 5),
    ),  );
  final api = OpenFeatureAPI();
  api.setProvider(provider);

  // 2. Create a client scoped to your service
  final featureClient = FeatureClient(
    metadata: ClientMetadata(name: 'example-client', version: '1.0.0'),
    provider: provider,
    hookManager: HookManager(),
    defaultContext: EvaluationContext(attributes: {}),
  );
  final client = IntelliToggleClient(featureClient);

  // 3. Build an evaluation context
  final ctx = {
    'kind': 'user',
    'targetingKey': 'user-123',
    'email': 'test@example.com',
  };

  // 4. Evaluate some flags
  final isEnabled = await client.getBooleanValue(
    'new-ui-enabled',
    false,
    evaluationContext: ctx,
  );
  print('new-ui-enabled = $isEnabled');

  final welcomeText = await client.getStringValue(
    'welcome-message',
    'Hello!',
    evaluationContext: ctx,
  );
  print('welcome-message = $welcomeText');

  // 5. Clean up
  await provider.shutdown();
  print('Shut down provider.');
}
