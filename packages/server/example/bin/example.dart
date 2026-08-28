import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

Future<void> main() async {
  // 1. Configure and register the provider
  final provider = IntelliToggleProvider(
    clientId: 'YOUR_CLIENT_ID',
    clientSecret: 'YOUR_CLIENT_SECRET',
    tenantId: 'YOUR_TENANT_ID',
    options: IntelliToggleOptions(
      baseUri: Uri.parse('https://api.intellitoggle.com'),
      timeout: const Duration(seconds: 5),
    ),
  );
  final api = OpenFeatureAPI();
  await api.setProviderAndWait(provider);

  // 2. Create a client scoped to your service
  final client = IntelliToggleClient(api.getClient('example-client'));

  // 3. Build an evaluation context
  final ctx = {'targetingKey': 'user-123', 'cohort': 'beta'};

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
  await OpenFeatureAPI.resetInstance();
  print('Shut down provider.');
}
