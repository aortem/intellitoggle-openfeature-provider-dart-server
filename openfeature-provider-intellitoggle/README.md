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
    sdkKey: 'YOUR_INTELLITOGGLE_SDK_KEY',
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
final provider = InMemoryProvider();
provider.setFlag('experimental-mode', true);

await OpenFeatureAPI().setProvider(provider);

final client = IntelliToggleClient(namespace: 'test');
final enabled = await client.getBooleanValue('experimental-mode', false);
print('Flag = $enabled'); // true
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

Let me know if you'd like a `bin/orep_server.dart` usage snippet or an `example/main.dart` to pair with this for pub.dev’s [score metrics](https://dart.dev/tools/pub/score).
```
