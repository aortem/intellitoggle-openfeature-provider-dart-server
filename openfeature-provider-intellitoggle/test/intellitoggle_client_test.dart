import 'dart:io';

import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:test/test.dart';

void main() {
  final config = _IntegrationConfig.fromEnvironment();

  group('IntelliToggleClient integration', () {
    test(
      'evaluates a boolean flag with configured credentials',
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
        await api.setProvider(provider);

        final featureClient = FeatureClient(
          metadata: ClientMetadata(name: 'test-client', version: '0.0.1'),
          provider: provider,
          hookManager: HookManager(),
          defaultContext: EvaluationContext(attributes: {}),
        );
        final client = IntelliToggleClient(featureClient);

        final newFeatureEnabled = await client.getBooleanValue(
          'new-dashboard-ui',
          false,
        );

        expect(newFeatureEnabled, isA<bool>());
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
