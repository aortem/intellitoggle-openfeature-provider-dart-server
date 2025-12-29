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
  openfeature_dart_server_sdk: ^0.0.15
  openfeature_provider_intellitoggle: ^0.0.5
```

Then install:

```bash
dart pub get
```

---

## 🚀 Getting Started

```dart
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  print('Starting IntelliToggle provider with OAuth2 Credentials...\n');

  final provider = IntelliToggleProvider(
    clientId: "client_id",
    clientSecret: "cs_secret",
    tenantId: "tenant_id",
    options: IntelliToggleOptions(enableLogging: true),
  );

  print('Provider created, initializing...\n');
  await provider.initialize();
  print('✓ Provider initialized successfully!\n');

  final api = OpenFeatureAPI();
  api.setProvider(provider);

  // Evaluate a boolean flag
  // result.flagKey, result.value, result.evaluatedAt, result.reason
  final result = await provider.getBooleanFlag('new-dashboard', false);

  if (result.errorCode != null) {
    print('✗ Error Code: ${result.errorCode}');
    print('✗ Error Message: ${result.errorMessage}');
  } else {
    print('');
    print('Flag value: ${result.value}'); // Flag evaluated value
  }
  print('');

  await provider.shutdown();
  print('✓ Test completed successfully!');
}
```

---

## 🧪 IntelliToggleClient Test

```dart
import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  print('Starting IntelliClient test with OAuth2...\n');

  final provider = IntelliToggleProvider(
    clientId: "client_id",
    clientSecret: "cs_secret",
    tenantId: "tenant_id",
    options: IntelliToggleOptions(
      enableLogging: true,
    ),
  );

  print('Provider created, initializing...\n');
  await provider.initialize();
  print('✓ Provider initialized successfully!\n');

  final api = OpenFeatureAPI();
  api.setProvider(provider);

  // Create a client
  final clientMetadata = ClientMetadata(name: 'test-client', version: '0.0.1');
  final hookManager = HookManager();
  final defaultEvalContext = EvaluationContext(attributes: {});
  final featureClient = FeatureClient(
    metadata: clientMetadata,
    provider: provider,
    hookManager: hookManager,
    defaultContext: defaultEvalContext,
  );
  final client = IntelliToggleClient(featureClient);

  // Evaluate your feature flags
  final newFeatureEnabled = await client.getBooleanValue('new-dashboard-ui', false);

  print('Flag value: ${newFeatureEnabled}');

  await provider.shutdown();
  print('✓ Test completed successfully!');
}
```

---

## 🧪 Local Development & Testing

Use the included `InMemoryProvider` for fast testing without external dependencies:

```dart
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

void main() async {
  print('Starting IntelliToggle provider test with InMemoryProvider...\n');

  final provider = InMemoryProvider();

  print('Provider created, initializing...');
  await provider.initialize();
  print('✓ Provider initialized successfully!\n');

  final api = OpenFeatureAPI();
  api.setProvider(provider);

  // Create a client
  final clientMetadata = ClientMetadata(name: 'test-client', version: '0.0.1');
  final hookManager = HookManager();
  final defaultEvalContext = EvaluationContext(attributes: {});
  final featureClient = FeatureClient(
    metadata: clientMetadata,
    provider: provider,
    hookManager: hookManager,
    defaultContext: defaultEvalContext,
  );
  final client = IntelliToggleClient(featureClient);

  provider.setFlag('bool-flag', true);

  // Evaluate your feature flags
  final newFeatureEnabled = await client.getBooleanValue('bool-flag', false);

  print('Flag value: $newFeatureEnabled'); // true

  await provider.shutdown();
  print('✓ Test completed successfully!');
}
```

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

- [IntelliToggle Docs](https://intellitoggle.com)
- [OpenFeature Dart SDK](https://pub.dev/packages/openfeature_dart_server_sdk)
- [GitHub Repository](https://github.com/aortem/intellitoggle)
- [OpenFeature Specification](https://openfeature.dev)

---

## 📝 License

MIT

```

---

Let me know if you'd like a `bin/orep_server.dart` usage snippet or an `example/main.dart` to pair with this for pub.dev’s [score metrics](https://dart.dev/tools/pub/score).
```
