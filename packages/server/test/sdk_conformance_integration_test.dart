import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_dart_server_sdk/experimental/isolated.dart';
import 'package:openfeature_dart_server_sdk/open_feature_event.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:test/test.dart';

// Real canonical provider and SDK, controlled HTTP transport; no live backend.
class RecordingTransport extends MockClient {
  RecordingTransport(super.handler);
  int closeCount = 0;

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

void main() {
  late OpenFeatureAPI api;
  late IntelliToggleProvider provider;
  late RecordingTransport transport;
  late FeatureClient client;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> contexts;
  late Completer<OpenFeatureEvent> ready;

  setUp(() async {
    requests = [];
    contexts = [];
    transport = RecordingTransport((request) async {
      requests.add(request);
      switch ((request.method, request.url.path)) {
        case ('POST', '/api/v1/oauth/token'):
          return http.Response(
            jsonEncode({'access_token': 'fixture-token', 'expires_in': 3600}),
            200,
          );
        case (
          'POST',
          '/api/v1/flags/projects/fixture-project/flags/__intellitoggle_readiness__/evaluate',
        ):
          return http.Response('{"error":"Flag not found"}', 404);
        case (
          'POST',
          '/api/v1/flags/projects/fixture-project/flags/flag/evaluate',
        ):
          contexts.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'flagKey': 'flag',
              'tenantId': 'fixture-tenant',
              'projectId': 'fixture-project',
              'environment': 'development',
              'value': true,
              'reasonCode': 'TARGETING_MATCH',
              'variant': 'enabled',
            }),
            200,
          );
        case (
          'POST',
          '/api/v1/flags/projects/fixture-project/flags/missing/evaluate',
        ):
          return http.Response('{"errorCode":"FLAG_NOT_FOUND"}', 404);
        default:
          throw StateError('Unexpected transport request: ${request.url}');
      }
    });
    provider = IntelliToggleProvider(
      clientId: 'fixture-client',
      clientSecret: 'fixture-secret',
      tenantId: 'fixture-tenant',
      options: IntelliToggleOptions(
        baseUri: Uri.parse('https://fixture.invalid'),
        environment: 'development',
        projectId: 'fixture-project',
        maxRetries: 1,
      ),
      httpClient: transport,
    );
    api = createIsolatedOpenFeatureAPI();
    ready = Completer<OpenFeatureEvent>();
    api.addEventHandler(OpenFeatureEventType.PROVIDER_READY, (event) {
      if (event.type == OpenFeatureEventType.PROVIDER_READY &&
          event.providerName == 'IntelliToggle' &&
          !ready.isCompleted) {
        ready.complete(event);
      }
    });
    await api.setProviderAndWait(provider);
    client = api.createClient();
  });

  tearDown(() async {
    await client.dispose();
    await api.dispose();
  });

  test(
    'S01 canonical provider initialization produces scoped ready event',
    () async {
      final event = await ready.future.timeout(const Duration(seconds: 2));
      expect(event.providerName, 'IntelliToggle');
      expect(provider.state, ProviderState.READY);
      expect(client.providerStatus, ProviderState.READY);
    },
  );

  test(
    'S02 SDK hooks and dynamic context reach the canonical HTTP provider',
    () async {
      final stages = <String>[];
      client.addHooks([
        EvaluationHook(
          metadata: const HookMetadata(name: 'integration'),
          before: (context, hints) {
            stages.add('before');
            return EvaluationContext.immutable(attributes: {'fromHook': true});
          },
          after: (context, details, hints) => stages.add('after'),
          finallyAfter: (context, details, hints) => stages.add('finally'),
        ),
      ]);
      api.setEvaluationContext(
        EvaluationContext.immutable(targetingKey: 'first-user'),
      );
      final details = await client.getBooleanEvaluationDetails(
        'flag',
        defaultValue: false,
      );
      expect(details.value, isTrue);
      expect(details.variant, 'enabled');
      expect(details.reason, 'TARGETING_MATCH');
      expect(stages, ['before', 'after', 'finally']);
      expect(contexts.single['targetingKey'], 'first-user');
      expect(contexts.single['fromHook'], isTrue);
      api.setEvaluationContext(
        EvaluationContext.immutable(targetingKey: 'second-user'),
      );
      expect(await client.getBooleanValue('flag', defaultValue: false), isTrue);
      expect(contexts.last['targetingKey'], 'second-user');
    },
  );

  test(
    'S03 provider HTTP failure returns default and runs error/finally hooks',
    () async {
      final stages = <String>[];
      client.addHooks([
        EvaluationHook(
          metadata: const HookMetadata(name: 'integration'),
          error: (context, error, hints) => stages.add('error'),
          finallyAfter: (context, details, hints) => stages.add('finally'),
        ),
      ]);
      final details = await client.getBooleanEvaluationDetails(
        'missing',
        defaultValue: false,
      );
      expect(details.value, isFalse);
      expect(details.errorCode, ErrorCode.FLAG_NOT_FOUND);
      expect(stages, ['error', 'finally']);
    },
  );

  test(
    'S04 unsupported tracking is a safe no-op with numeric properties',
    () async {
      final requestCount = requests.length;
      await client.track(
        'purchase',
        trackingDetails: TrackingEventDetails(value: 2),
      );
      await client.track(
        'purchase',
        trackingDetails: TrackingEventDetails(value: 2.5),
      );
      expect(requests.length, requestCount);
      expect(provider.state, ProviderState.READY);
    },
  );

  test(
    'S05 SDK shutdown releases transport once and subsequent evaluation defaults',
    () async {
      await api.shutdown();
      await api.shutdown();
      expect(provider.state, ProviderState.SHUTDOWN);
      expect(transport.closeCount, 1);
      final requestCount = requests.length;
      expect(
        await client.getBooleanValue('flag', defaultValue: false),
        isFalse,
      );
      expect(requests.length, requestCount);
    },
  );
}
