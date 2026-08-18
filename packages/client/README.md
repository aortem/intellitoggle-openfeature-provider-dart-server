# IntelliToggle OpenFeature client provider for Dart

This package exposes backend-resolved IntelliToggle flag snapshots through the
static-context OpenFeature Dart Client SDK. It is pure Dart and performs no
network, file, Flutter platform-channel, or remote-authentication work.

The package is intentionally unpublished while the upstream client SDK remains
an unpublished beta dependency.

## Security model

The application backend authenticates with IntelliToggle, evaluates flags for
the current subject, and returns only resolved values to the client. Never send
an IntelliToggle client secret to a browser or mobile application.

Flags are not an authorization boundary. Paid entitlements, permissions, ad-free
status, and other product policy remain authoritative on the backend.

## Use a backend-resolved snapshot

```dart
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> main() async {
  final provider = IntelliToggleClientProvider.fromValues({
    'ads-enabled': true,
    'ad-format': 'sponsored-video',
  });

  await OpenFeatureAPI.instance.setProviderAndWait(provider);
  final client = OpenFeatureAPI.instance.getClient('mobile-app');

  final adsEnabled = client.getBooleanValue('ads-enabled', false);
  final adFormat = client.getStringValue('ad-format', 'none');

  print('$adsEnabled: $adFormat');
  await OpenFeatureAPI.instance.shutdown();
}
```

When the backend returns a refreshed snapshot, replace the local values:

```dart
provider.replaceValues({
  'ads-enabled': false,
  'ad-format': 'none',
});
```

Snapshot replacement emits an OpenFeature `configurationChanged` event. The
provider does not reevaluate targeting rules when client context changes; fetch
a new backend-resolved snapshot when the signed-in subject or relevant context
changes.

PairQueue can continue consuming its existing backend flag payload directly and
does not need to adopt this package.
