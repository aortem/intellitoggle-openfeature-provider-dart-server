# IntelliToggle OpenFeature client provider for Dart

This package exposes backend-resolved IntelliToggle flag snapshots through the
static-context OpenFeature Dart Client SDK. It is pure Dart and performs no
network, file, Flutter platform-channel, or remote-authentication work.

The upstream client SDK is available from pub.dev as `0.0.1-beta.1`. This
provider remains unpublished while its external beta validation is completed.

The [Flutter beta demo](example/flutter_snapshot_demo/) validates this provider
in a real Flutter web application without adding Flutter to the provider's
dependency graph. The standalone Dart web smoke target lives at
`test/web_compile_smoke.dart`.

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
event contains only keys whose values or evaluation details actually changed.

For decoded backend JSON, prefer the full snapshot contract so evaluation
details survive the network boundary:

```json
{
  "flags": {
    "ads-enabled": {
      "value": true,
      "reason": "TARGETING_MATCH",
      "variant": "on",
      "metadata": {"source": "backend"}
    }
  }
}
```

Pass the decoded object to `IntelliToggleClientSnapshot.fromJson`. A flat
`{"ads-enabled": true}` object is also accepted as a shorthand and uses the
default `CACHED` reason. Flag values must be non-null JSON values; metadata
values must be booleans, strings, or numbers. JSON integer values are widened
when resolving a double flag, but doubles are not truncated for integer flags.

Changing the OpenFeature evaluation context immediately invalidates the old
snapshot so values resolved for one user cannot be served to another. Fetch a
new backend-resolved snapshot and call `replaceSnapshot` after login, logout,
account, or other relevant context changes.

Provider instances are single-use. The SDK shuts a provider down when it is no
longer bound; check `isShutDown` before a background refresh. Calls to
`replaceSnapshot` and `replaceValues` after shutdown throw `StateError`, and a
shut-down instance must not be registered again.

PairQueue can continue consuming its existing backend flag payload directly and
does not need to adopt this package.
