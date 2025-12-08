# openfeature_provider_intellitoggle

An OpenFeature provider for [IntelliToggle](https://intellitoggle.com), enabling Dart backends to evaluate feature flags using the OpenFeature API standard.

This package integrates seamlessly with [`openfeature_dart_server_sdk`](https://pub.dev/packages/openfeature_dart_server_sdk) and supports IntelliToggle's advanced targeting, rule-based rollouts, and experimentation platform.

---

## 🔧 Features

- ✅ Supports Boolean, String, Number, and Object flag evaluations
- 🔁 Real-time updates via IntelliToggle event system
- 🧪 Includes `InMemoryProvider` for local development and testing
- 🌐 Optional OREP/OPTSP server support for remote evaluation (e.g. test suites)

---

## 💻 Installation

Add to your server-side Dart project:

```yaml
dependencies:
  openfeature_dart_server_sdk: ^0.1.0
  openfeature_provider_intellitoggle: ^0.0.2
````

Then install:

```bash
dart pub get
```

---

## 🚀 Getting Started

```dart
import 'package:openfeature_dart_server_sdk/openfeature_dart_server_sdk.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  final provider = IntelliToggleProvider(
    clientId: 'YOUR_INTELLITOGGLE_CLIENT_ID',
    clientSecret: 'YOUR_INTELLITOGGLE_CLIENT_SECRET',
    tenantId: 'YOUR_INTELLITOGGLE_TENANT_ID',
    // Optional: override default scope (defaults to `flags:evaluate`)
    // oauthScope: 'flags:evaluate projects:read',
  );

  await OpenFeatureAPI().setProvider(provider);

  final client = IntelliToggleClient(namespace: 'my-service');

  final enabled = await client.getBooleanValue(
    'new-dashboard-enabled',
    false,
    evaluationContext: {
      'targetingKey': 'user-123',
      'role': 'beta_tester',
    },
  );

  print('Feature enabled: $enabled');
}
```

---

## 🧪 Local Development & Testing

Use the included `InMemoryProvider` for fast testing without external dependencies:

```dart
// Seed initial flags at construction (optional)
final provider = InMemoryProvider(initialFlags: {
  'experimental-mode': true,
  'welcome-text': (Map<String, dynamic> ctx) =>
      ctx['role'] == 'beta_tester' ? 'Welcome, beta!' : 'Welcome!',
});
provider.setFlag('experimental-mode', true);

await OpenFeatureAPI().setProvider(provider);

final client = IntelliToggleClient(namespace: 'test');
final enabled = await client.getBooleanValue('experimental-mode', false);
print('Flag = $enabled'); // true
```

Listen for configuration change events (union of previous and new keys is emitted):

```dart
final sub = provider.events.listen((e) {
  if (e.type == IntelliToggleEventType.configurationChanged) {
    print('Flags changed: ${e.data?['flagsChanged']}');
  }
});
```

Context-aware flags can be set with a callback:

```dart
provider.setFlag('is-admin', (Map<String, dynamic> ctx) => ctx['role'] == 'admin');
```

---

## 🪵 Console Logging Hook

Log evaluation lifecycle events to stdout. Optionally include the evaluation context for debugging:

`dart
final hook = ConsoleLoggingHook(printContext: true);

// Add globally
OpenFeatureAPI().addHooks([hook]);

// Or add to a specific client
final hookManager = HookManager();
hookManager.addHook(hook);
`

Example log entries (JSON):

`
[OpenFeature] {"stage":"before","domain":"flag_evaluation","provider_name":"InMemoryProvider","flag_key":"new-ui","default_value":false}
[OpenFeature] {"stage":"after","domain":"flag_evaluation","provider_name":"InMemoryProvider","flag_key":"new-ui","default_value":false,"result":true}
`

---
## ⚙️ OREP Server (Optional)

Start a remote flag evaluation API:

```bash
dart run bin/orep_server.dart
```

Configure using environment variables:

| Variable          | Default          |
| ----------------- | ---------------- |
| `OREP_PORT`       | `8080`           |
| `OREP_HOST`       | `0.0.0.0`        |
| `OREP_AUTH_TOKEN` | `changeme-token` |
| `OREP_PROVIDER_MODE` | `inmemory` (`intellitoggle` to use remote provider) |
| `INTELLITOGGLE_CLIENT_ID` | Required when `OREP_PROVIDER_MODE=intellitoggle` |
| `INTELLITOGGLE_CLIENT_SECRET` | Required when `OREP_PROVIDER_MODE=intellitoggle` |
| `INTELLITOGGLE_TENANT_ID` | Required when `OREP_PROVIDER_MODE=intellitoggle` |
| `INTELLITOGGLE_OAUTH_SCOPE` | Optional OAuth scope override (`flags:evaluate`) |
| `INTELLITOGGLE_ENV` | `production` or `development` |

Example multi-context GET:

```bash
curl -H "Authorization: Bearer $OREP_AUTH_TOKEN" \
  "http://localhost:8080/v1/flags/my-flag/evaluate?type=boolean&default=false&context=%7B%22kind%22%3A%22multi%22%2C%22user%22%3A%7B%22targetingKey%22%3A%22user-123%22%7D%2C%22org%22%3A%7B%22targetingKey%22%3A%22org-999%22%7D%7D"
```

### OFREP Client (Remote Evaluation)

The provider can call an OFREP-compliant endpoint for remote flag evaluation.

- Enable via options or environment variables.
- Maps OFREP responses to OpenFeature `ProviderEvaluation` including `value`, `variant`, `reason`, `errorCode`, and `flagMetadata`.
- Supports retries, timeouts, and optional in-memory cache keyed by `(flagKey + context)`.

Environment variables:

```
OFREP_ENABLED=true
OFREP_BASE_URL=https://ofrep.example.com
OFREP_AUTH_TOKEN=your_bearer_token
OFREP_TIMEOUT_MS=5000
OFREP_MAX_RETRIES=3
OFREP_CACHE_TTL_MS=60000
```

Code example:

```dart
final provider = IntelliToggleProvider(
  sdkKey: 'YOUR_TOKEN', // used if OFREP_AUTH_TOKEN not set
  options: IntelliToggleOptions(
    useOfrep: true,
    ofrepBaseUri: Uri.parse('https://ofrep.example.com'),
    cacheTtl: const Duration(minutes: 1),
    maxRetries: 3,
    timeout: const Duration(seconds: 5),
  ),
);
await OpenFeatureAPI().setProvider(provider);

final client = IntelliToggleClient(
  FeatureClient(
    metadata: ClientMetadata(name: 'service-x'),
    hookManager: HookManager(),
  ),
);

final result = await client.getBooleanValue(
  'my-flag',
  false,
  targetingKey: 'user-123',
  evaluationContext: {'region': 'us-east-1'},
);
```

---

## 📚 Resources

* [IntelliToggle Docs](https://intellitoggle.com)
* [OpenFeature Dart SDK](https://pub.dev/packages/openfeature_dart_server_sdk)
* [GitHub Repository](https://github.com/aortem/intellitoggle)
* [OpenFeature Specification](https://openfeature.dev)

---

## 📝 License

MIT

```

---

Let me know if you'd like a `bin/orep_server.dart` usage snippet or an `example/main.dart` to pair with this for pub.dev's [score metrics](https://dart.dev/tools/pub/score).
```

---

## gRPC Server

Start the OFREP gRPC server:

```bash
dart run bin/ofrep_grpc_server.dart
```

Environment variables:

| Variable            | Default       |
| ------------------- | ------------- |
| `OREP_GRPC_HOST`    | `0.0.0.0`     |
| `OREP_GRPC_PORT`    | `50051`       |
| `OREP_AUTH_TOKEN`   | `changeme-token` |
| `OAUTH_JWT_HS256_SECRET` | (unset) |
| `OAUTH_EXPECTED_AUD`     | (unset) |
| `OAUTH_EXPECTED_ISS`     | (unset) |

Set `OREP_PROVIDER_MODE=intellitoggle` plus the same `INTELLITOGGLE_CLIENT_ID` / `INTELLITOGGLE_CLIENT_SECRET` / `INTELLITOGGLE_TENANT_ID` variables (and optional `INTELLITOGGLE_OAUTH_SCOPE`) from the HTTP gateway table when you want the gRPC server to call the real backend.

Protobufs are in `protos/ofrep.proto`. Generated Dart used by the server is vendored under `lib/src/gen/` for convenience.
