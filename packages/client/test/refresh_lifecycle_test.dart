import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';
import 'package:test/test.dart';

http.Response flags(String identity) => http.Response(
  jsonEncode({
    'flags': [
      {'key': 'identity', 'value': identity, 'reason': 'TARGETING_MATCH'},
    ],
  }),
  200,
  headers: {'etag': '"initial"'},
);

void main() {
  final api = OpenFeatureAPI.instance;
  tearDown(api.shutdown);

  test(
    'refresh failure signals error and 304 recovery restores ready status',
    () async {
      var calls = 0;
      final provider = IntelliToggleRemoteClientProvider(
        apiBaseUri: Uri.parse('https://intellitoggle.test'),
        tokenProvider: (_) async => 'fixture-token',
        httpClient: MockClient(
          (_) async => switch (++calls) {
            1 => flags('a'),
            2 => http.Response('{"error":"unavailable"}', 503),
            _ => http.Response('', 304),
          },
        ),
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'a'),
      );
      await api.setProviderAndWait(provider);
      final client = api.getClient();
      final errorStatuses = <ProviderStatus>[];
      final readyStatuses = <ProviderStatus>[];
      client.addHandler(
        ProviderEventType.error,
        (_) => errorStatuses.add(client.providerStatus),
      );
      client.addHandler(
        ProviderEventType.ready,
        (_) => readyStatuses.add(client.providerStatus),
      );
      readyStatuses.clear();
      await expectLater(
        provider.refresh(),
        throwsA(isA<OpenFeatureException>()),
      );
      expect(errorStatuses, [ProviderStatus.error]);
      expect(client.providerStatus, ProviderStatus.error);
      await provider.refresh();
      expect(readyStatuses, [ProviderStatus.ready]);
      expect(client.providerStatus, ProviderStatus.ready);
      expect(client.getStringValue('identity', 'default'), 'a');
    },
  );

  test(
    'late token failure from an old identity cannot poison new status',
    () async {
      final token = Completer<String>();
      final entered = Completer<void>();
      var oldCalls = 0;
      final provider = IntelliToggleRemoteClientProvider(
        apiBaseUri: Uri.parse('https://intellitoggle.test'),
        tokenProvider: (context) async {
          if (context.targetingKey == 'a' && ++oldCalls > 1) {
            entered.complete();
            return token.future;
          }
          return 'fixture-token';
        },
        httpClient: MockClient(
          (request) async => flags(
            (jsonDecode(request.body) as Map)['context']['targetingKey']
                as String,
          ),
        ),
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'a'),
      );
      await api.setProviderAndWait(provider);
      final client = api.getClient();
      var errors = 0;
      client.addHandler(ProviderEventType.error, (_) => errors++);
      final failure = expectLater(provider.refresh(), throwsStateError);
      await entered.future;
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'b'),
      );
      token.completeError(StateError('old token failed'));
      await failure;
      expect(errors, 0);
      expect(client.providerStatus, ProviderStatus.ready);
      expect(client.getStringValue('identity', 'default'), 'b');
    },
  );

  test(
    'a refresh completing after shutdown emits no new ready event',
    () async {
      final response = Completer<http.Response>();
      final entered = Completer<void>();
      var calls = 0;
      final provider = IntelliToggleRemoteClientProvider(
        apiBaseUri: Uri.parse('https://intellitoggle.test'),
        tokenProvider: (_) async => 'fixture-token',
        httpClient: MockClient((_) {
          if (++calls == 1) return Future.value(flags('a'));
          entered.complete();
          return response.future;
        }),
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'a'),
      );
      await api.setProviderAndWait(provider);
      final refresh = provider.refresh();
      await entered.future;
      await api.shutdown();
      response.complete(flags('late'));
      await refresh;
      expect(provider.isShutDown, isTrue);
      expect(api.getClient().providerStatus, ProviderStatus.notReady);
      expect(api.getClient().getStringValue('identity', 'default'), 'default');
    },
  );
}
