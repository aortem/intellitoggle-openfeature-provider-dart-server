# IntelliToggle OpenFeature provider for Dart

The official server-side Dart provider for
[IntelliToggle](https://intellitoggle.com), built on the
[OpenFeature Dart Server SDK](https://pub.dev/packages/openfeature_dart_server_sdk).

The legacy `intellitoggle_server_sdk` package is deprecated. New server
integrations should use this package.

## Install

```yaml
dependencies:
  openfeature_dart_server_sdk: ^0.0.23
  openfeature_provider_intellitoggle: ^0.0.10
```

The provider uses an IntelliToggle OAuth client with `flags:read` and
`flags:evaluate` scopes. Keep the client secret in a runtime secret manager;
never ship it in a browser or mobile application.

## Configure and evaluate

```dart
import 'dart:io';

import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

Future<void> main() async {
  final provider = IntelliToggleProvider(
    clientId: Platform.environment['INTELLITOGGLE_CLIENT_ID']!,
    clientSecret: Platform.environment['INTELLITOGGLE_CLIENT_SECRET']!,
    tenantId: Platform.environment['INTELLITOGGLE_TENANT_ID']!,
    options: IntelliToggleOptions(
      baseUri: Uri.parse('https://api.intellitoggle.com'),
      environment: 'production',
    ),
  );

  final api = OpenFeatureAPI();
  await api.setProviderAndWait(provider);
  final client = api.getClient('orders-service');

  final enabled = await client.getBooleanFlag(
    'new-checkout',
    defaultValue: false,
    context: const EvaluationContext(
      targetingKey: 'non-pii-subject-id',
      attributes: {
        'cohort': 'beta',
        'device.platform': 'android',
      },
    ),
  );

  print(enabled);
  await OpenFeatureAPI.resetInstance();
}
```

The default transport uses IntelliToggle's canonical REST endpoints:

- `POST /api/v1/oauth/token`
- `POST /api/v1/flags/{flagKey}/evaluate`

Use `IntelliToggleOptions.environment` to supply the deployment environment
for every evaluation. An invocation context can override it by explicitly
providing `environment`.

## Context and privacy

Evaluation attributes are sent as IntelliToggle's top-level context contract.
JSON-compatible nested maps and lists are preserved, including dotted
attribute names.

The provider does not require a targeting key for default flag evaluation.
When targeting is needed, use an opaque, non-PII identifier. Attributes listed
in `privateAttributes` are removed before the request is sent:

```dart
const EvaluationContext(
  targetingKey: 'subject-7f41',
  attributes: {
    'plan': 'free',
    'email': 'not-sent@example.com',
    'privateAttributes': ['email'],
  },
)
```

Paid entitlements, authorization, and other product policy should remain in
the consuming service. A feature flag is not an authorization boundary.

## Failure behavior

IntelliToggle follows OpenFeature fallback semantics:

- missing flags return the caller default with `FLAG_NOT_FOUND`;
- response type mismatches return the caller default with `TYPE_MISMATCH`;
- authentication, transport, and unexpected API failures return the caller
  default with `GENERAL`.

Use the OpenFeature detailed-evaluation methods when the caller needs the
reason, variant, or error code.

## Optional OFREP transport

Set `useOfrep: true` and provide `ofrepBaseUri` to evaluate through an
OFREP-compatible endpoint. The package also includes local OREP/OFREP helpers
for protocol testing.

```dart
final options = IntelliToggleOptions(
  useOfrep: true,
  ofrepBaseUri: Uri.parse('https://ofrep.example.com'),
  ofrepAuthToken: Platform.environment['OFREP_AUTH_TOKEN'],
  timeout: const Duration(seconds: 5),
  maxRetries: 3,
  cacheTtl: const Duration(minutes: 1),
);
```

Plain HTTP is accepted only for `localhost` and `127.0.0.1`.

## Local and fallback testing

```dart
final provider = InMemoryProvider()
  ..setFlag('new-checkout', true);

final api = OpenFeatureAPI();
await api.setProviderAndWait(provider);
final client = api.getClient('test-service');

final enabled = await client.getBooleanFlag(
  'new-checkout',
  defaultValue: false,
);
```

Run the package validation suite with:

```bash
dart pub get
dart analyze
dart test
dart pub publish --dry-run
```

Live IntelliToggle integration tests additionally require
`INTELLITOGGLE_CLIENT_ID`, `INTELLITOGGLE_CLIENT_SECRET`, and
`INTELLITOGGLE_TENANT_ID`. Set `INTELLITOGGLE_API_URL` to test a
non-production deployment.

## License

BSD-3-Clause
