import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> main() async {
  final api = OpenFeatureAPI.instance;
  final provider = IntelliToggleClientProvider.fromValues({
    'conference-demo': true,
  });
  await api.setProviderAndWait(provider);
  api.getClient('flutter-web').getBooleanValue('conference-demo', false);
  await api.shutdown();
}
