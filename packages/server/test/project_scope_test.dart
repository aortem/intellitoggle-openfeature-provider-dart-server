import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_provider_intellitoggle/src/options.dart';
import 'package:openfeature_provider_intellitoggle/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test(
    'explicit project sends scope and rejects unverified evaluation identity',
    () async {
      var responseProject = 'project-a';
      var includeIdentity = true;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/oauth/token'))
          return http.Response(
            jsonEncode({'access_token': 'test', 'expires_in': 3600}),
            200,
          );
        expect(request.headers['X-Project-ID'], 'project-a');
        expect(request.headers['X-Environment'], 'development');
        return http.Response(
          jsonEncode({
            'value': true,
            if (includeIdentity) ...{
              'projectId': responseProject,
              'tenantId': 'tenant',
              'environment': 'development',
            },
          }),
          200,
        );
      });
      final utils = IntelliToggleUtils(
        client,
        IntelliToggleOptions(
          projectId: 'project-a',
          environment: 'development',
          maxRetries: 1,
        ),
        clientId: 'client',
        clientSecret: 'secret',
        tenantId: 'tenant',
      );
      expect(
        (await utils.evaluateFlag('same-key', {}, 'boolean'))['value'],
        true,
      );
      responseProject = 'project-b';
      await expectLater(
        utils.evaluateFlag('same-key', {}, 'boolean'),
        throwsA(isA<AuthenticationException>()),
      );
      includeIdentity = false;
      await expectLater(
        utils.evaluateFlag('same-key', {}, 'boolean'),
        throwsA(isA<AuthenticationException>()),
      );
      client.close();
    },
  );

  test(
    'legacy configuration remains compatible with previous API responses',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/oauth/token')
                ? {'access_token': 'test', 'expires_in': 3600}
                : {'value': false},
          ),
          200,
        ),
      );
      final utils = IntelliToggleUtils(
        client,
        IntelliToggleOptions(maxRetries: 1),
        clientId: 'client',
        clientSecret: 'secret',
        tenantId: 'tenant',
      );
      expect(
        (await utils.evaluateFlag('same-key', {}, 'boolean'))['value'],
        false,
      );
      client.close();
    },
  );
}
