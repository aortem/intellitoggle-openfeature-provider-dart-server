import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> main() async {
  final api = OpenFeatureAPI.instance;
  final provider = IntelliToggleClientProvider.fromValues({
    'conference-demo': true,
  });
  await api.setProviderAndWait(provider);
  api.getClient('flutter-web').getBooleanValue('conference-demo', false);
  await api.shutdown();

  // Construction proves the remote provider and its HTTP dependency remain
  // available to dart2js without importing dart:io or Flutter.
  final remoteProvider = IntelliToggleRemoteClientProvider(
    apiBaseUri: Uri.parse('https://api.intellitoggle.com'),
    tokenProvider: (_) async => 'short-lived-evaluation-token',
  );
  await remoteProvider.shutdown();
}
