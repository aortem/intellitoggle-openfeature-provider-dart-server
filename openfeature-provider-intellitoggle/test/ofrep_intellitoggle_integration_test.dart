import 'dart:io';

import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:test/test.dart';

void main() {
  final clientId = Platform.environment['INTELLITOGGLE_CLIENT_ID'];
  final clientSecret = Platform.environment['INTELLITOGGLE_CLIENT_SECRET'];
  final tenantId = Platform.environment['INTELLITOGGLE_TENANT_ID'];
  final scope = Platform.environment['INTELLITOGGLE_OAUTH_SCOPE'];
  final hasClientCredentials =
      clientId != null &&
      clientSecret != null &&
      tenantId != null &&
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      tenantId.isNotEmpty;
  if (!hasClientCredentials) {
    test(
      'OFREP IntelliToggle integration (skipped: missing client credentials)',
      () {},
      skip:
          'Set INTELLITOGGLE_CLIENT_ID, INTELLITOGGLE_CLIENT_SECRET, and INTELLITOGGLE_TENANT_ID to run this test.',
    );
    return;
  }

  test('OFREP IntelliToggleProvider evaluates boolean flag', () async {
    final env = (Platform.environment['INTELLITOGGLE_ENV'] ?? 'production')
        .toLowerCase();
    final options = env == 'development'
        ? IntelliToggleOptions.development()
        : IntelliToggleOptions.production();

    final provider = IntelliToggleProvider(
      clientId: clientId!,
      clientSecret: clientSecret!,
      tenantId: tenantId!,
      oauthScope: scope,
      options: options,
    );

    await provider.initialize();

    final flagKey =
        Platform.environment['INTELLITOGGLE_TEST_FLAG'] ?? 'ofrep-test-flag';

    final result = await provider.getBooleanFlag(
      flagKey,
      false,
      context: {'targetingKey': 'ofrep-integration-user', 'kind': 'user'},
    );

    expect(result, isA<FlagEvaluationResult<bool>>());
  });
}
