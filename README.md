<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/aortem/logos/main/Aortem-logo-small.png" />
    <img align="center" alt="Aortem Logo" src="https://raw.githubusercontent.com/aortem/logos/main/Aortem-logo-small.png" />
  </picture>
</p>

<!-- x-hide-in-docs-end -->
<p align="center" class="github-badges">
  <!-- Release Badge -->
  <a href="https://github.com/aortem/intellitoggle/tags">
    <img alt="GitHub Tag" src="https://img.shields.io/github/v/tag/aortem/intellitoggle?style=for-the-badge" />
  </a>
  <!-- Dart-Specific Badges -->
  <a href="https://pub.dev/packages/firebase_dart_admin_auth_sdk">
    <img alt="Pub Version" src="https://img.shields.io/pub/v/firebase_dart_admin_auth_sdk.svg?style=for-the-badge" />
  </a>
  <a href="https://dart.dev/">
    <img alt="Built with Dart" src="https://img.shields.io/badge/Built%20with-Dart-blue.svg?style=for-the-badge" />
  </a>
<!-- x-hide-in-docs-start -->

# IntelliToggle OpenFeature Provider for Dart (Server-Side SDK)**

This provider enables using IntelliToggle’s feature management platform with the OpenFeature Dart Server-Side SDK.

> **Note:** This provider targets multi-user server environments (e.g. web servers, back-end services). It is **not** intended for use in Flutter desktop or embedded contexts.

---

## IntelliToggle Overview

[IntelliToggle](https://intellitoggle.com) is a SaaS feature-flag and experimentation platform that powers dynamic rollouts, canary deployments, and real-time flag evaluations. By integrating with OpenFeature, you can swap providers transparently, leverage IntelliToggle’s advanced rules engine, and maintain consistent flag behavior across services.

---

## Supported Dart Versions

Compatible with Dart **3.8.1** and above.

---

## Getting Started

### Installation

Add to your server-side `pubspec.yaml`:

```yaml
dependencies:
  open_feature: ^0.1.0
  intellitoggle_openfeature: ^0.0.1
```

Then run:

```bash
dart pub get
```

### Usage

```dart
import 'package:open_feature/open_feature.dart';
import 'package:intellitoggle_openfeature/intellitoggle_provider.dart';

void main() async {
  // Create and register the IntelliToggle provider
  final provider = IntelliToggleProvider(
    sdkKey: 'YOUR_INTELLITOGGLE_SDK_KEY',
    options: IntelliToggleOptions(
      timeout: Duration(seconds: 5),
      baseUri: Uri.parse('https://api.intellitoggle.com'),
    ),
  );

  // Set as the global OpenFeature provider
  OpenFeature.instance.setProvider(provider);

  // Optionally wait until ready
  await OpenFeature.instance.setProviderAndWait(provider);

  // Create a client and evaluate a flag
  final client = OpenFeature.instance.getClient('my-service');
  final value = await client.getBooleanValue(
    'new-dashboard-enabled',
    false,
    evaluationContext: {
      'kind': 'user',
      'targetingKey': 'user-123',
      'role': 'beta_tester',
    },
  );

  print('Feature “new-dashboard-enabled” = $value');
}
```

---

## OpenFeature Context & IntelliToggle Specifics

IntelliToggle supports both single-context and multi-context flag evaluations. The provider inspects your `evaluationContext` for a `kind` attribute:

1. **No `kind`** → treated as a single “user” context.
2. **`kind: 'multi'`** → multi-context; additional keys denote each context.
3. **`kind: '<anything-else>'`** → single context of that custom kind.

> The `targetingKey` (or `key`) attribute is **required** and takes precedence over `key` if both are present.

### Reserved Context Attributes

* `privateAttributes` (List<String>) → hides sensitive fields
* `anonymous` (bool) → flags the context as anonymous
* `name` (String) → human-readable name

---

## Examples

### Single-User Context

```dart
final ctx = {
  'targetingKey': 'user-123',
  'name': 'Jane Doe',
  'anonymous': false,
};
final flag = await client.getBooleanValue('beta-feature', false, evaluationContext: ctx);
```

### Custom Context Kind

```dart
final ctx = {
  'kind': 'organization',
  'targetingKey': 'org-456',
  'plan': 'enterprise',
};
final flag = await client.getStringValue('org-level-flag', 'none', evaluationContext: ctx);
```

### Multi-Context

```dart
final ctx = {
  'kind': 'multi',
  'user': {
    'targetingKey': 'user-123',
    'email': 'jane@example.com',
  },
  'project': {
    'targetingKey': 'proj-789',
    'tier': 'beta',
  },
};
final flag = await client.getObjectValue<Map<String, dynamic>>(
  'project-experiment',
  {},
  evaluationContext: ctx,
);
```

---

## Provider Events

You can listen to lifecycle events:

```dart
OpenFeature.instance.addHandler(ProviderEvents.Ready, (_) {
  print('IntelliToggle provider is ready!');
});

OpenFeature.instance.addHandler(ProviderEvents.ConfigurationChanged, (evt) {
  print('Flags changed: ${evt.flagsChanged}');
});
```

---

## Cleanup

Before your process shuts down, flush any pending events:

```dart
await OpenFeature.instance.close();
```

---

## Contributing

We welcome contributions! See [`CONTRIBUTING.md`](https://github.com/intellitoggle/openfeature-dart) for guidelines.

---

## Learn More

* **Website:** [https://intellitoggle.com](https://intellitoggle.com)
* **Docs & CLI:** [https://docs.intellitoggle.com/openfeature-dart](https://docs.intellitoggle.com/openfeature-dart)
* **API Reference:** [https://api.intellitoggle.com/docs](https://api.intellitoggle.com/docs)
* **GitHub:** [https://github.com/intellitoggle/openfeature-dart](https://github.com/intellitoggle/openfeature-dart)
