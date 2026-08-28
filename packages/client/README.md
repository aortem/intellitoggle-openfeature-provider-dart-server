# IntelliToggle OpenFeature client provider for Dart

This package connects Dart, Flutter, and Dart web applications to
IntelliToggle through the static-context OpenFeature Dart Client SDK. It
includes a web-compatible remote OFREP provider and a no-network snapshot
provider.

The upstream client SDK is available from pub.dev as `0.0.1-beta.1`.

The [Flutter beta demo](example/flutter_snapshot_demo/) validates this provider
in a real Flutter web application without adding Flutter to the provider's
dependency graph. The standalone Dart web smoke target lives at
`test/web_compile_smoke.dart`.

## Security model

The application backend authenticates with IntelliToggle and mints a
short-lived evaluation token for the current subject. The client uses that
token only with IntelliToggle's `/ofrep/v1/evaluate/flags` endpoint. Never send
an IntelliToggle OAuth client ID and secret to a browser or mobile application.

Flags are not an authorization boundary. Paid entitlements, permissions, ad-free
status, and other product policy remain authoritative on the backend.

## Use remote OFREP evaluation

Your application backend should expose an authenticated endpoint that obtains
an IntelliToggle evaluation token from
`POST /api/v1/ofrep/evaluation-token`. The browser or Flutter application
supplies that short-lived token to the provider:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

Future<void> configureFlags(String signedInUserId) async {
  final provider = IntelliToggleRemoteClientProvider(
    apiBaseUri: Uri.parse('https://api.intellitoggle.com'),
    tokenProvider: (context) async {
      // This is your application backend, authenticated as the signed-in user.
      final response = await http.post(
        Uri.base.resolve('/api/feature-token'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'targetingKey': context.targetingKey}),
      );
      return (jsonDecode(response.body) as Map<String, dynamic>)['token']
          as String;
    },
  );

  await OpenFeatureAPI.instance.setEvaluationContextAndWait(
    EvaluationContext(targetingKey: signedInUserId),
  );
  await OpenFeatureAPI.instance.setProviderAndWait(provider);

  final client = OpenFeatureAPI.instance.getClient('my-app');
  final enabled = client.getBooleanValue('checkout-v2', false);
  print('checkout-v2: $enabled');
}
```

The provider bulk-loads evaluated flags during initialization and every context
change. It keeps resolutions synchronous, sends `If-None-Match` during an
explicit `refresh()`, and atomically drops the old subject's values before
reconciliation. It depends only on pure Dart, web-compatible packages.

The token endpoint binds the targeting key, tenant, and environment for at most
15 minutes. Your backend must send its OAuth access token plus `x-tenant-id`
and `x-environment`; the OAuth client needs `flags:evaluate`.

## Use a backend-resolved snapshot

For applications that proxy all evaluation through their own backend, the
snapshot provider remains available and performs no network or authentication
work:

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

PairQueue can continue consuming its existing server-side flag payload and can
adopt the remote client provider when it needs OpenFeature-controlled Flutter
UI behavior.
