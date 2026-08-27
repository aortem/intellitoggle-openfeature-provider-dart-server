import 'package:flutter_test/flutter_test.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

void main() {
  test('registers the provider in a Flutter test process', () async {
    await OpenFeatureAPI.instance.shutdown();
    final provider = IntelliToggleClientProvider.fromValues({'flag': true});
    await OpenFeatureAPI.instance.setProviderAndWait(provider);
    expect(OpenFeatureAPI.instance.getClient().getBooleanValue('flag', false), isTrue);
    await OpenFeatureAPI.instance.shutdown();
  });
}
