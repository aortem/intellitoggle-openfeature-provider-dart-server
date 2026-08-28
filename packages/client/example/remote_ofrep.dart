import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> main() async {
  const userId = 'signed-in-user-123';
  final provider = IntelliToggleRemoteClientProvider(
    apiBaseUri: Uri.parse('https://api.intellitoggle.com'),
    tokenProvider: (context) async {
      // Replace with your authenticated application-backend endpoint. That
      // backend, not this distributed client, holds IntelliToggle credentials.
      final response = await http.post(
        Uri.parse('https://app.example.com/api/feature-token'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'targetingKey': context.targetingKey}),
      );
      if (response.statusCode != 200) {
        throw StateError('Could not obtain an evaluation token');
      }
      return (jsonDecode(response.body) as Map<String, dynamic>)['token']
          as String;
    },
  );

  final api = OpenFeatureAPI.instance;
  await api.setEvaluationContextAndWait(
    EvaluationContext(targetingKey: userId),
  );
  await api.setProviderAndWait(provider);

  final client = api.getClient('example-app');
  print(client.getBooleanValue('checkout-v2', false));
  await api.shutdown();
}
