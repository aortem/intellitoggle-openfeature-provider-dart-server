import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:test/test.dart';

void main() {
  group('IntelliToggle v1 HTTP provider', () {
    test(
      'uses canonical routes, encoded OAuth form, and top-level context',
      () async {
        final requests = <http.BaseRequest>[];
        Map<String, dynamic>? evaluationBody;

        final client = MockClient((request) async {
          requests.add(request);
          switch ((request.method, request.url.path)) {
            case ('POST', '/api/v1/oauth/token'):
              return http.Response(
                jsonEncode({'access_token': 'token-1', 'expires_in': 3600}),
                200,
                headers: {'content-type': 'application/json'},
              );
            case ('GET', '/health'):
              return http.Response('{}', 200);
            case ('POST', '/api/v1/flags/flag%2Fkey/evaluate'):
              evaluationBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'flagKey': 'flag/key',
                  'value': true,
                  'reason': 'TARGETING_MATCH',
                  'variationId': 'enabled',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            default:
              return http.Response('not found', 404);
          }
        });

        final provider = IntelliToggleProvider(
          clientId: 'client&one',
          clientSecret: 'secret=two+three',
          tenantId: 'tenant-1',
          options: IntelliToggleOptions(
            baseUri: Uri.parse('https://dev-api.intellitoggle.com'),
            environment: 'development',
            maxRetries: 1,
          ),
          httpClient: client,
        );
        addTearDown(provider.shutdown);

        await provider.initialize();
        final result = await provider.getBooleanFlag(
          'flag/key',
          false,
          context: {
            'targetingKey': 'subject-123',
            'device.platform': 'android',
            'cohorts': ['beta', 'east'],
            'email': 'private@example.com',
            'privateAttributes': ['email'],
          },
        );

        final tokenRequest = requests.first as http.Request;
        expect(tokenRequest.bodyFields, {
          'grant_type': 'client_credentials',
          'client_id': 'client&one',
          'client_secret': 'secret=two+three',
          'scope': 'flags:read flags:evaluate',
        });
        expect(tokenRequest.headers['x-tenant-id'], 'tenant-1');
        expect(requests.last.headers['x-sdk-version'], '0.0.12');
        expect(requests.last.headers['authorization'], 'Bearer token-1');
        expect(evaluationBody, {
          'targetingKey': 'subject-123',
          'device.platform': 'android',
          'cohorts': ['beta', 'east'],
          'environment': 'development',
        });
        expect(evaluationBody, isNot(contains('attributes')));
        expect(evaluationBody, isNot(contains('email')));
        expect(result.value, isTrue);
        expect(result.reason, 'TARGETING_MATCH');
        expect(result.variant, 'enabled');
        expect(result.errorCode, isNull);
        expect(provider.metadata.version, '0.0.12');
      },
    );

    test(
      'allows empty context and applies the configured environment',
      () async {
        Map<String, dynamic>? evaluationBody;
        final provider = _provider(
          onEvaluate: (request) {
            evaluationBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({'value': false, 'reason': 'DEFAULT'}),
              200,
            );
          },
        );
        addTearDown(provider.shutdown);

        await provider.initialize();
        final result = await provider.getBooleanFlag('default-off', true);

        expect(evaluationBody, {'environment': 'development'});
        expect(result.value, isFalse);
        expect(result.reason, 'DEFAULT');
        expect(result.errorCode, isNull);
      },
    );

    test(
      'returns TYPE_MISMATCH instead of coercing a response value',
      () async {
        final provider = _provider(
          onEvaluate: (_) => http.Response(
            jsonEncode({'value': 'true', 'reason': 'STATIC'}),
            200,
          ),
        );
        addTearDown(provider.shutdown);

        await provider.initialize();
        final result = await provider.getBooleanFlag('wrong-type', false);

        expect(result.value, isFalse);
        expect(result.reason, 'ERROR');
        expect(result.errorCode, ErrorCode.TYPE_MISMATCH);
        expect(result.errorMessage, contains('Expected boolean'));
      },
    );

    test(
      'maps a missing flag to the caller default and FLAG_NOT_FOUND',
      () async {
        final provider = _provider(
          onEvaluate: (_) => http.Response('missing', 404),
        );
        addTearDown(provider.shutdown);

        await provider.initialize();
        final result = await provider.getStringFlag('missing', 'fallback');

        expect(result.value, 'fallback');
        expect(result.reason, 'ERROR');
        expect(result.errorCode, ErrorCode.FLAG_NOT_FOUND);
      },
    );

    test(
      'refreshes an expired token once and retries the evaluation',
      () async {
        var tokenCalls = 0;
        var evaluationCalls = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/oauth/token') {
            tokenCalls++;
            return http.Response(
              jsonEncode({
                'access_token': 'token-$tokenCalls',
                'expires_in': 3600,
              }),
              200,
            );
          }
          if (request.url.path == '/health') return http.Response('{}', 200);
          evaluationCalls++;
          if (evaluationCalls == 1) return http.Response('expired', 401);
          expect(request.headers['authorization'], 'Bearer token-2');
          return http.Response(
            jsonEncode({'value': true, 'reason': 'STATIC'}),
            200,
          );
        });
        final provider = IntelliToggleProvider(
          clientId: 'client',
          clientSecret: 'secret',
          tenantId: 'tenant',
          options: IntelliToggleOptions(
            baseUri: Uri.parse('https://api.example.test'),
            maxRetries: 2,
            retryDelay: Duration.zero,
          ),
          httpClient: client,
        );
        addTearDown(provider.shutdown);

        await provider.initialize();
        final result = await provider.getBooleanFlag('refresh-me', false);

        expect(result.value, isTrue);
        expect(result.errorCode, isNull);
        expect(tokenCalls, 2);
        expect(evaluationCalls, 2);
      },
    );

    test(
      'coalesces concurrent initialization into one connection check',
      () async {
        var tokenCalls = 0;
        var healthCalls = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/oauth/token') {
            tokenCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return http.Response(
              jsonEncode({'access_token': 'token', 'expires_in': 3600}),
              200,
            );
          }
          healthCalls++;
          return http.Response('{}', 200);
        });
        final provider = IntelliToggleProvider(
          clientId: 'client',
          clientSecret: 'secret',
          tenantId: 'tenant',
          options: IntelliToggleOptions(
            baseUri: Uri.parse('https://api.example.test'),
            maxRetries: 1,
          ),
          httpClient: client,
        );
        addTearDown(provider.shutdown);

        await Future.wait([provider.initialize(), provider.initialize()]);

        expect(provider.state, ProviderState.READY);
        expect(tokenCalls, 1);
        expect(healthCalls, 1);
      },
    );

    test(
      'rejects malformed OAuth responses without exposing credentials',
      () async {
        const secret = 'never-log-this-secret';
        final client = MockClient(
          (_) async => http.Response(jsonEncode({'expires_in': 3600}), 200),
        );
        final provider = IntelliToggleProvider(
          clientId: 'client',
          clientSecret: secret,
          tenantId: 'tenant',
          options: IntelliToggleOptions(
            baseUri: Uri.parse('https://api.example.test'),
            maxRetries: 1,
          ),
          httpClient: client,
        );
        addTearDown(provider.shutdown);

        await expectLater(
          provider.initialize(),
          throwsA(isA<AuthenticationException>()),
        );
        expect(provider.state, ProviderState.ERROR);
      },
    );
  });

  group('IntelliToggle context processing', () {
    test('preserves nested JSON and dotted attribute names', () {
      final processor = IntelliToggleContextProcessor();
      expect(
        processor.processContext({
          'key': 'subject',
          'device.platform': ' android ',
          'nested': {
            'roles': ['operator', 7, true],
          },
        }),
        {
          'targetingKey': 'subject',
          'device.platform': 'android',
          'nested': {
            'roles': ['operator', 7, true],
          },
        },
      );
    });

    test('rejects unsupported values rather than silently dropping them', () {
      final processor = IntelliToggleContextProcessor();
      expect(
        () => processor.processContext({'createdAt': DateTime(2026)}),
        throwsArgumentError,
      );
    });
  });
}

IntelliToggleProvider _provider({
  required http.Response Function(http.Request request) onEvaluate,
}) {
  final client = MockClient((request) async {
    if (request.url.path == '/api/v1/oauth/token') {
      return http.Response(
        jsonEncode({'access_token': 'token', 'expires_in': 3600}),
        200,
      );
    }
    if (request.url.path == '/health') return http.Response('{}', 200);
    return onEvaluate(request);
  });
  return IntelliToggleProvider(
    clientId: 'client',
    clientSecret: 'secret',
    tenantId: 'tenant',
    options: IntelliToggleOptions(
      baseUri: Uri.parse('https://api.example.test'),
      environment: 'development',
      maxRetries: 1,
    ),
    httpClient: client,
  );
}
