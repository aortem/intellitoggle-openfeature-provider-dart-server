import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import '../config/app_config.dart';

class IntelliToggleDemoProvider {
  late final IntelliToggleProvider _provider;
  late final FeatureClient _client;
  final AppConfig _config;

  IntelliToggleDemoProvider(this._config);

  Future<void> initialize() async {
    // Initialize provider with OAuth2 client secret
    _provider = IntelliToggleProvider(
      sdkKey: _config.clientSecret,
      options: IntelliToggleOptions(
        baseUri: Uri.parse(_config.baseUrl),
        timeout: _config.timeout,
        enablePolling: true,
        pollingInterval: Duration(minutes: 5),
        enableLogging: true,
      ),
    );

    // Set as global provider
    await OpenFeatureAPI().setProvider(_provider);

    // Set global context with tenant information
    OpenFeatureAPI().setGlobalContext(
      OpenFeatureEvaluationContext({
        'environment': 'production',
        'service': 'intellitoggle-demo',
        'tenantId': _config.tenantId,
      }),
    );

    // Create client
    _client = FeatureClient(
      metadata: ClientMetadata(name: 'intellitoggle-demo'),
      hookManager: HookManager(),
      defaultContext: EvaluationContext(attributes: {}),
    );

    // Listen to provider events (if supported by IntelliToggle provider)
    try {
      _provider.events.listen(_handleProviderEvent);
    } catch (e) {
      print('ℹ️  Provider events not available: $e');
    }

    print('✅ IntelliToggle provider initialized');
  }

  void _handleProviderEvent(dynamic event) {
    print('🔄 Provider event: $event');
  }

  Future<bool> getBooleanFlag(
    String flagKey,
    bool defaultValue, {
    String? targetingKey,
    Map<String, dynamic>? context,
  }) async {
    try {
      final attributes = <String, dynamic>{...?context};
      if (targetingKey != null) {
        attributes['targetingKey'] = targetingKey;
      }

      final evaluationContext = EvaluationContext(attributes: attributes);

      return await _client.getBooleanFlag(
        flagKey,
        context: evaluationContext,
        defaultValue: defaultValue,
      );
    } catch (e) {
      print('⚠️  Error evaluating boolean flag "$flagKey": $e');
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
      final attributes = <String, dynamic>{...?context};
      if (targetingKey != null) {
        attributes['targetingKey'] = targetingKey;
      }

      final evaluationContext = EvaluationContext(attributes: attributes);

      return await _client.getStringFlag(
        flagKey,
        context: evaluationContext,
        defaultValue: defaultValue,
      );
    } catch (e) {
      print('⚠️  Error evaluating string flag "$flagKey": $e');
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
      final attributes = <String, dynamic>{...?context};
      if (targetingKey != null) {
        attributes['targetingKey'] = targetingKey;
      }

      final evaluationContext = EvaluationContext(attributes: attributes);

      return await _client.getIntegerFlag(
        flagKey,
        context: evaluationContext,
        defaultValue: defaultValue,
      );
    } catch (e) {
      print('⚠️  Error evaluating integer flag "$flagKey": $e');
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
      final attributes = <String, dynamic>{...?context};
      if (targetingKey != null) {
        attributes['targetingKey'] = targetingKey;
      }

      final evaluationContext = EvaluationContext(attributes: attributes);

      return await _client.getDoubleFlag(
        flagKey,
        context: evaluationContext,
        defaultValue: defaultValue,
      );
    } catch (e) {
      print('⚠️  Error evaluating double flag "$flagKey": $e');
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
      final attributes = <String, dynamic>{...?context};
      if (targetingKey != null) {
        attributes['targetingKey'] = targetingKey;
      }

      final evaluationContext = EvaluationContext(attributes: attributes);

      return await _client.getObjectFlag(
        flagKey,
        context: evaluationContext,
        defaultValue: defaultValue,
      );
    } catch (e) {
      print('⚠️  Error evaluating object flag "$flagKey": $e');
      return defaultValue;
    }
  }

  EvaluationContext createContext({
    String? targetingKey,
    Map<String, dynamic>? attributes,
  }) {
    final contextAttributes = <String, dynamic>{...?attributes};
    if (targetingKey != null) {
      contextAttributes['targetingKey'] = targetingKey;
    }

    return EvaluationContext(attributes: contextAttributes);
  }

  EvaluationContext createMultiContext({
    Map<String, Map<String, dynamic>>? contexts,
  }) {
    final defaultContexts =
        contexts ??
        {
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

    // Create multi-context attributes
    final attributes = <String, dynamic>{};
    for (final entry in defaultContexts.entries) {
      attributes[entry.key] = entry.value;
    }

    return EvaluationContext(attributes: attributes);
  }

  Future<void> shutdown() async {
    try {
      await _provider.shutdown();
      print('✅ Provider shutdown complete');
    } catch (e) {
      print('⚠️  Error during provider shutdown: $e');
    }
  }
}
