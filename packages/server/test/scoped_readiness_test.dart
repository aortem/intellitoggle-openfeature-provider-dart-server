import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_provider_intellitoggle/src/options.dart';
import 'package:openfeature_provider_intellitoggle/src/provider.dart';
import 'package:test/test.dart';

void main() {
  for (final status in [200, 204, 404, 401, 403, 500]) {
    test('scoped readiness handles $status with evaluate-only access', () async {
      var probes = 0;
      final provider = IntelliToggleProvider(
        clientId: 'test-client',
        clientSecret: 'test-secret',
        tenantId: 'tenant',
        options: IntelliToggleOptions.production(
          projectId: 'project-a',
          environment: 'development',
        ).copyWith(maxRetries: 2, retryDelay: Duration.zero),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/oauth/token')) {
            expect(request.bodyFields['scope'], 'flags:evaluate');
            return http.Response(
              '{"access_token":"test","expires_in":3600}',
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.headers['X-Environment'], 'development');
          if (request.url.path.endsWith(
            '/__intellitoggle_readiness__/evaluate',
          )) {
            probes++;
            expect(
              request.url.path,
              '/api/v1/flags/projects/project-a/flags/__intellitoggle_readiness__/evaluate',
            );
            expect(jsonDecode(request.body), isEmpty);
            return http.Response(
              status == 404
                  ? '{"error":"Flag not found"}'
                  : '{"error":"Project is not allowed"}',
              status,
            );
          }
          final key = request.url.pathSegments[6];
          expect(
            request.url.path,
            '/api/v1/flags/projects/project-a/flags/$key/evaluate',
          );
          final values = <String, Object>{
            'bool': true,
            'string': 'hello',
            'number': 42,
            'json': {'ok': true},
          };
          return http.Response(
            jsonEncode({
              'value': values[key],
              'tenantId': 'tenant',
              'projectId': 'project-a',
              'environment': 'development',
              'reasonCode': 'TARGETING_MATCH',
              'reason': 'Rule match: rule',
              'variant': 'chosen',
            }),
            200,
          );
        }),
      );
      if ([200, 204, 404].contains(status)) {
        await provider.initialize();
        expect(provider.state, ProviderState.READY);
        final b = await provider.getBooleanFlag('bool', false);
        expect(b.value, true);
        expect(b.reason, 'TARGETING_MATCH');
        expect(b.variant, 'chosen');
        expect((await provider.getStringFlag('string', '')).value, 'hello');
        expect((await provider.getIntegerFlag('number', 0)).value, 42);
        expect((await provider.getObjectFlag('json', {})).value, {'ok': true});
      } else {
        await expectLater(provider.initialize(), throwsA(anything));
        expect(provider.state, ProviderState.ERROR);
      }
      expect(probes, status == 500 ? 2 : 1);
      await provider.shutdown();
    });
  }
  test('named factories preserve scope through copyWith', () {
    for (final options in [
      IntelliToggleOptions.production(projectId: 'p', environment: 'e'),
      IntelliToggleOptions.development(projectId: 'p', environment: 'e'),
      IntelliToggleOptions.fromEnvironment(projectId: 'p', environment: 'e'),
    ]) {
      expect(options.copyWith(timeout: Duration.zero).projectId, 'p');
      expect(options.copyWith(timeout: Duration.zero).environment, 'e');
    }
  });
}
