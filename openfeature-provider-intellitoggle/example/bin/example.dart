import 'dart:async';
import 'package:openfeature_dart_server_sdk/openfeature_dart_server_sdk.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

Future<void> main() async {
  // 1. Configure and register the provider
  final provider = IntelliToggleProvider(
    sdkKey: 'YOUR_SDK_KEY',
    options: IntelliToggleOptions(
      baseUri: Uri.parse('https://api.intellitoggle.com'),
      timeout: const Duration(seconds: 5),
    ),
  );
  await OpenFeatureAPI().setProvider(provider);

  // 2. Create a client scoped to your service
  final client = IntelliToggleClient(namespace: 'my-service');

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
