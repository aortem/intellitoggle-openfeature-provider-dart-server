import 'dart:io';

import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:test/test.dart';

void main() {
  final config = _IntegrationConfig.fromEnvironment();

  group('IntelliToggleProvider integration', () {
    test(
      'evaluates representative flag types with configured credentials',
      () async {
        final provider = IntelliToggleProvider(
          clientId: config.clientId!,
          clientSecret: config.clientSecret!,
          tenantId: config.tenantId!,
          options: IntelliToggleOptions(baseUri: config.baseUri),
        );
        addTearDown(provider.shutdown);

        await provider.initialize();

        final api = OpenFeatureAPI();
        api.setProvider(provider);

        final booleanResult = await provider.getBooleanFlag(
          'new-dashboard-ui',
          false,
        );
        expect(booleanResult.value, isA<bool>());
        expect(booleanResult.reason, isA<String>());

        final contextualResult = await provider.getBooleanFlag(
          'test-flag',
          false,
          context: {
            'targetingKey': 'user-123',
            'kind': 'user',
            'email': 'test@example.com',
            'role': 'admin',
          },
        );
        expect(contextualResult.value, isA<bool>());
        expect(contextualResult.reason, isA<String>());

        final missingFlagResult = await provider.getBooleanFlag(
          'missing-flag',
          true,
          context: {'targetingKey': 'user-456'},
        );
        expect(missingFlagResult.value, isA<bool>());
        expect(missingFlagResult.reason, isA<String>());

        final themeConfigResult = await provider.getStringFlag(
          'theme-config',
          'light',
          context: {'targetingKey': 'user-789', 'kind': 'user'},
        );
        expect(themeConfigResult.value, isA<String>());
        expect(themeConfigResult.reason, isA<String>());

        final welcomeMessageResult = await provider.getStringFlag(
          'welcome-message',
          'Message',
        );
        expect(welcomeMessageResult.value, isA<String>());
        expect(welcomeMessageResult.reason, isA<String>());
      },
      skip: config.skipReason,
    );
  });
}

class _IntegrationConfig {
  final String? clientId;
  final String? clientSecret;
  final String? tenantId;
  final Uri baseUri;

  const _IntegrationConfig({
    required this.clientId,
    required this.clientSecret,
    required this.tenantId,
    required this.baseUri,
  });

  factory _IntegrationConfig.fromEnvironment() {
    final env = Platform.environment;
    return _IntegrationConfig(
      clientId: env['INTELLITOGGLE_CLIENT_ID'],
      clientSecret: env['INTELLITOGGLE_CLIENT_SECRET'],
      tenantId: env['INTELLITOGGLE_TENANT_ID'],
      baseUri: Uri.parse(
        env['INTELLITOGGLE_API_URL'] ?? 'https://api.intellitoggle.com',
      ),
    );
  }

  String? get skipReason {
    final missing = <String>[
      if (clientId == null || clientId!.isEmpty) 'INTELLITOGGLE_CLIENT_ID',
      if (clientSecret == null || clientSecret!.isEmpty)
        'INTELLITOGGLE_CLIENT_SECRET',
      if (tenantId == null || tenantId!.isEmpty) 'INTELLITOGGLE_TENANT_ID',
    ];

    if (missing.isEmpty) {
      return null;
    }

    return 'Set ${missing.join(', ')} to run the live IntelliToggle integration test.';
  }
}
