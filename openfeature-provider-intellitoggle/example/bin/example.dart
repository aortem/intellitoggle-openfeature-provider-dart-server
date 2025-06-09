import 'dart:async';
import 'package:open_feature/open_feature.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

Future<void> main() async {
  // 1. Configure and register the provider
  final options = IntelliToggleOptions(
    sdkKey: 'YOUR_SDK_KEY',
    baseUri: Uri.parse('https://api.intellitoggle.com'),
    timeout: const Duration(seconds: 5),
  );
  final provider = IntelliToggleProvider(options);
  await OpenFeature.instance.setProviderAndWait(provider);

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
  await OpenFeature.instance.close();
  print('Shut down provider.');
}
