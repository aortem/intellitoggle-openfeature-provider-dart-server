// test.dart
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  try {
    print('Starting IntelliToggle provider test with OAuth2...\n');

    final provider = IntelliToggleProvider(
      clientId: "client_",
      clientSecret: "cs_",
      tenantId: "tenant_",
      options: IntelliToggleOptions(
        baseUri: Uri.parse("https://dev-api.intellitoggle.com"),
        // timeout: const Duration(seconds: 10),
        enableLogging: true,
      ),
    );

    print('Provider created, initializing...');
    await provider.initialize();
    print('✓ Provider initialized successfully!\n');

    final api = OpenFeatureAPI();
    api.setProvider(provider);

    // Test 1a: Evaluate a boolean flag
    print('Test 1a: Evaluating boolean flag "new-ui-enabled"...');
    try {
      final result = await provider.getBooleanFlag('new-ui-enabled', false);

      print('✓ Flag evaluation result:');
      print('  Flag Key: ${result.flagKey}');
      print('  Value: ${result.value}');
      print('  Reason: ${result.reason}');
      print('  Variant: ${result.variant}');
      if (result.errorCode != null) {
        print('  Error Code: ${result.errorCode}');
        print('  Error Message: ${result.errorMessage}');
      }
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    print('Test 1b: Evaluating boolean flag "test-flag"...');
    try {
      final result = await provider.getBooleanFlag(
        'test-flag',
        false,
        context: {
          'targetingKey': 'user-123',
          'kind': 'user',
          'email': 'test@example.com',
          'role': 'admin',
        },
      );

      print('✓ Flag evaluation result:');
      print('  Flag Key: ${result.flagKey}');
      print('  Value: ${result.value}');
      print('  Reason: ${result.reason}');
      print('  Variant: ${result.variant}');
      if (result.errorCode != null) {
        print('  Error Code: ${result.errorCode}');
        print('  Error Message: ${result.errorMessage}');
      }
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    // Test 2: Evaluate a non-existent flag (should return default)
    print('Test 2: Evaluating non-existent flag "missing-flag"...');
    try {
      final result = await provider.getBooleanFlag(
        'missing-flag',
        true, // default value
        context: {'targetingKey': 'user-456'},
      );

      print('✓ Non-existent flag handled gracefully:');
      print('  Value: ${result.value} (default)');
      print('  Reason: ${result.reason}');
      print('  Error Code: ${result.errorCode}');
      print('');
    } catch (e) {
      print('✗ Unexpected error: $e\n');
    }

    // Test 3: Evaluate a string flag
    print('Test 3: Evaluating string flag "theme-config"...');
    try {
      final result = await provider.getStringFlag(
        'theme-config',
        'light',
        context: {'targetingKey': 'user-789', 'kind': 'user'},
      );

      print('✓ String flag evaluation:');
      print('  Value: ${result.value}');
      print('  Reason: ${result.reason}');
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    print('Test: Evaluating string flag "welcome-message"...');
    try {
      final result = await provider.getStringFlag(
        'welcome-message',
        'Message'
      );

      print('✓ String flag evaluation:');
      print('  Value: ${result.value}');
      print('  Reason: ${result.reason}');
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    await provider.shutdown();
    print('✓ Test completed successfully!');
  } catch (error, stackTrace) {
    print('ERROR: $error');
    print('STACK TRACE: $stackTrace');

    if (error.toString().contains('401')) {
      print('\nOAuth2 Authentication Failed:');
      print('1. Check your client_id, client_secret, and tenant_id');
      print('2. Verify the OAuth2 token endpoint is accessible');
      print(
        '3. Check if your credentials have the "flags:read flags:evaluate" scope',
      );
    } else if (error.toString().contains('404')) {
      print('\nEndpoint Not Found:');
      print('1. Verify the flag key exists in your IntelliToggle dashboard');
      print('2. Check the API base URL is correct');
      print('3. Ensure the evaluate endpoint format is correct');
    }
  }
}
