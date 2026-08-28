import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'loads OFREP values and revalidates the active context with ETag',
    () async {
      var calls = 0;
      final httpClient = MockClient((request) async {
        calls++;
        expect(request.url.path, '/ofrep/v1/evaluate/flags');
        expect(request.headers['authorization'], 'Bearer evaluation-token');
        final body = jsonDecode(request.body);
        expect(body['context']['targetingKey'], 'user-a');
        if (calls == 2) {
          expect(request.headers['if-none-match'], '"version-1"');
          return http.Response('', 304);
        }
        return http.Response(
          jsonEncode({
            'flags': [
              {
                'key': 'checkout-v2',
                'value': true,
                'reason': 'TARGETING_MATCH',
                'variant': 'on',
                'metadata': {'environment': 'production'},
              },
            ],
          }),
          200,
          headers: {'etag': '"version-1"'},
        );
      });
      final provider = IntelliToggleRemoteClientProvider(
        apiBaseUri: Uri.parse('https://api.intellitoggle.test'),
        tokenProvider: (_) async => 'evaluation-token',
        httpClient: httpClient,
      );
      final context = EvaluationContext(targetingKey: 'user-a');

      await OpenFeatureAPI.instance.setEvaluationContextAndWait(context);
      await OpenFeatureAPI.instance.setProviderAndWait(provider);
      final client = OpenFeatureAPI.instance.getClient('remote-test');
      final details = client.getBooleanDetails('checkout-v2', false);
      expect(details.value, isTrue);
      expect(details.reason, 'TARGETING_MATCH');
      expect(details.variant, 'on');
      expect(details.flagMetadata, {'environment': 'production'});

      await provider.refresh();
      expect(calls, 2);
      expect(client.getBooleanValue('checkout-v2', false), isTrue);
      await OpenFeatureAPI.instance.shutdown();
    },
  );

  test('reconciles context remotely without leaking previous values', () async {
    final requestedSubjects = <String>[];
    final httpClient = MockClient((request) async {
      final subject =
          jsonDecode(request.body)['context']['targetingKey'] as String;
      requestedSubjects.add(subject);
      return http.Response(
        jsonEncode({
          'flags': [
            {
              'key': 'personalized',
              'value': subject == 'user-a',
              'reason': 'TARGETING_MATCH',
            },
          ],
        }),
        200,
      );
    });
    final provider = IntelliToggleRemoteClientProvider(
      apiBaseUri: Uri.parse('https://api.intellitoggle.test'),
      tokenProvider: (context) async => 'token-${context.targetingKey}',
      httpClient: httpClient,
    );
    final api = OpenFeatureAPI.instance;
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-a'),
    );
    await api.setProviderAndWait(provider);
    final client = api.getClient('context-test');
    expect(client.getBooleanValue('personalized', false), isTrue);

    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-b'),
    );
    expect(client.getBooleanValue('personalized', true), isFalse);
    expect(requestedSubjects, ['user-a', 'user-b']);
    await api.shutdown();
  });

  test(
    'requires a targeting key and does not embed long-lived credentials',
    () async {
      final provider = IntelliToggleRemoteClientProvider(
        apiBaseUri: Uri.parse('https://api.intellitoggle.test'),
        tokenProvider: (_) async => 'token',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        OpenFeatureAPI.instance.setProviderAndWait(provider),
        throwsA(isA<OpenFeatureException>()),
      );
      await OpenFeatureAPI.instance.shutdown();
    },
  );

  test('ignores a late response from a superseded context', () async {
    final firstResponse = Completer<http.Response>();
    final httpClient = MockClient((request) async {
      final subject =
          jsonDecode(request.body)['context']['targetingKey'] as String;
      if (subject == 'user-a') return firstResponse.future;
      return http.Response(
        jsonEncode({
          'flags': [
            {
              'key': 'personalized',
              'value': false,
              'reason': 'TARGETING_MATCH',
            },
          ],
        }),
        200,
      );
    });
    final provider = IntelliToggleRemoteClientProvider(
      apiBaseUri: Uri.parse('https://api.intellitoggle.test'),
      tokenProvider: (_) async => 'token',
      httpClient: httpClient,
    );

    final firstRefresh = provider.initialize(
      EvaluationContext(targetingKey: 'user-a'),
    );
    await Future<void>.delayed(Duration.zero);
    await provider.onContextChanged(
      EvaluationContext(targetingKey: 'user-a'),
      EvaluationContext(targetingKey: 'user-b'),
    );
    firstResponse.complete(
      http.Response(
        jsonEncode({
          'flags': [
            {'key': 'personalized', 'value': true, 'reason': 'TARGETING_MATCH'},
          ],
        }),
        200,
      ),
    );
    await firstRefresh;

    final details = provider.resolveBooleanValue(
      'personalized',
      true,
      EvaluationContext(targetingKey: 'user-b'),
    );
    expect(details.value, isFalse);
    await provider.shutdown();
  });
}
