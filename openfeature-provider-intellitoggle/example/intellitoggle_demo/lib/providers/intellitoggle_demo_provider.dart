import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

import '../config/app_config.dart';

class IntelliToggleDemoProvider {
  late final IntelliToggleProvider _provider;
  late final FeatureClient _client;
  final AppConfig _config;

  IntelliToggleDemoProvider(this._config);

  Future<void> initialize() async {
    _provider = IntelliToggleProvider(
      clientId: _config.clientId,
      clientSecret: _config.clientSecret,
      tenantId: _config.tenantId,
      options: IntelliToggleOptions(
        baseUri: Uri.parse(_config.baseUrl),
        environment: 'production',
        timeout: _config.timeout,
        enablePolling: true,
        pollingInterval: const Duration(minutes: 5),
        enableLogging: true,
      ),
    );

    final api = OpenFeatureAPI();
    await api.setProviderAndWait(_provider);
    api.setGlobalContext(
      OpenFeatureEvaluationContext({'service': 'intellitoggle-demo'}),
    );
    _client = api.getClient('intellitoggle-demo');

    _provider.events.listen(_handleProviderEvent);
    print('IntelliToggle provider initialized');
  }

  void _handleProviderEvent(dynamic event) {
    print('Provider event: $event');
  }

  Future<bool> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await _client.getBooleanFlag(
        flagKey,
        context: _context(targetingKey, context),
        defaultValue: defaultValue,
      );
    } catch (error) {
      print('Error evaluating boolean flag "$flagKey": $error');
      return defaultValue;
    }
  }

  Future<String> getStringFlag(
    String flagKey,
    String defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await _client.getStringFlag(
        flagKey,
        context: _context(targetingKey, context),
        defaultValue: defaultValue,
      );
    } catch (error) {
      print('Error evaluating string flag "$flagKey": $error');
      return defaultValue;
    }
  }

  Future<int> getIntegerFlag(
    String flagKey,
    int defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await _client.getIntegerFlag(
        flagKey,
        context: _context(targetingKey, context),
        defaultValue: defaultValue,
      );
    } catch (error) {
      print('Error evaluating integer flag "$flagKey": $error');
      return defaultValue;
    }
  }

  Future<double> getDoubleFlag(
    String flagKey,
    double defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await _client.getDoubleFlag(
        flagKey,
        context: _context(targetingKey, context),
        defaultValue: defaultValue,
      );
    } catch (error) {
      print('Error evaluating double flag "$flagKey": $error');
      return defaultValue;
    }
  }

  Future<Map<String, dynamic>> getObjectFlag(
    String flagKey,
    Map<String, dynamic> defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await _client.getObjectFlag(
        flagKey,
        context: _context(targetingKey, context),
        defaultValue: defaultValue,
      );
    } catch (error) {
      print('Error evaluating object flag "$flagKey": $error');
      return defaultValue;
    }
  }

  EvaluationContext createContext({
    String? targetingKey,
    Map<String, dynamic>? attributes,
  }) {
    return _context(targetingKey, attributes);
  }

  EvaluationContext createMultiContext({
    Map<String, Map<String, dynamic>>? contexts,
  }) {
    final resolvedContexts =
        contexts ??
        const {
          'user': {
            'targetingKey': 'demo-user',
            'role': 'admin',
            'plan': 'enterprise',
          },
          'organization': {
            'targetingKey': 'demo-org',
            'tier': 'premium',
            'industry': 'technology',
          },
        };

    return EvaluationContext(
      attributes: {'kind': 'multi', ...resolvedContexts},
    );
  }

  EvaluationContext _context(
    String? targetingKey,
    Map<String, dynamic>? attributes,
  ) {
    return EvaluationContext(
      targetingKey: targetingKey,
      attributes: <String, dynamic>{...?attributes},
    );
  }

  Future<void> shutdown() async {
    try {
      await OpenFeatureAPI.resetInstance();
      print('Provider shutdown complete');
    } catch (error) {
      print('Error during provider shutdown: $error');
    }
  }
}
