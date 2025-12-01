// test.dart
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  try {
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

    // Test 1a: Evaluate a boolean flag
    print('Test 1a: Evaluating boolean flag "new-dashboard-ui"...');
    try {
      // result.flagKey, result.value, result.evaluatedAt, result.reason
      final result = await provider.getBooleanFlag('new-dashboard-ui', false);

      if (result.errorCode != null) {
        print('✗ Error Code: ${result.errorCode}');
        print('✗ Error Message: ${result.errorMessage}');
      } else {
        print('Flag value: ${result.value}'); // Flag evaluated value
      }
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    print('Test 1b: Evaluating boolean flag "test-flag"...');
    try {
      // result.flagKey, result.value, result.evaluatedAt, result.reason
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

      if (result.errorCode != null) {
        print('✗ Error Code: ${result.errorCode}');
        print('✗ Error Message: ${result.errorMessage}');
      } else {
        print('Flag value: ${result.value}'); // Flag evaluated value
      }
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    // Test 2: Evaluate a non-existent flag (should return default)
    print('Test 2: Evaluating non-existent flag "missing-flag"...');
    try {
      // result.flagKey, result.value, result.evaluatedAt, result.reason
      final result = await provider.getBooleanFlag(
        'missing-flag',
        true, // default value
        context: {'targetingKey': 'user-456'},
      );

      if (result.errorCode != null) {
        print('✗ Error Code: ${result.errorCode}');
        print('✗ Error Message: ${result.errorMessage}');
      } else {
        print('Flag value: ${result.value}'); // Flag evaluated value
      }
      print('');
    } catch (e) {
      print('✗ Unexpected error: $e\n');
    }

    // Test 3: Evaluate a string flag
    print('Test 3: Evaluating string flag "theme-config"...');
    try {
      // result.flagKey, result.value, result.evaluatedAt, result.reason
      final result = await provider.getStringFlag(
        'theme-config',
        'light',
        context: {'targetingKey': 'user-789', 'kind': 'user'},
      );

      if (result.errorCode != null) {
        print('✗ Error Code: ${result.errorCode}');
        print('✗ Error Message: ${result.errorMessage}');
      } else {
        print('Flag value: ${result.value}'); // Flag evaluated value
      }
      print('');
    } catch (e) {
      print('✗ Flag evaluation failed: $e\n');
    }

    print('Test: Evaluating string flag "welcome-message"...');
    try {
      // result.flagKey, result.value, result.evaluatedAt, result.reason
      final result = await provider.getStringFlag('welcome-message', 'Message');

      if (result.errorCode != null) {
        print('✗ Error Code: ${result.errorCode}');
        print('✗ Error Message: ${result.errorMessage}');
      } else {
        print('Flag value: ${result.value}'); // Flag evaluated value
      }
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
      print(
        '2. Check if your credentials have the "flags:read flags:evaluate" scope',
      );
    }
  }
}
