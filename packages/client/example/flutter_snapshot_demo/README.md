# IntelliToggle Flutter beta demo

This small Flutter web application validates the IntelliToggle snapshot
provider against the OpenFeature Dart client SDK beta. It exercises provider
registration, synchronous flag evaluation, configuration-change events, and
snapshot replacement through a real external provider implementation.

The example intentionally contains no network authentication. A trusted
backend evaluates IntelliToggle targeting rules and gives the application only
the resolved snapshot. Never ship an IntelliToggle client secret in a Flutter
mobile or web application.

Run the demo with:

```text
flutter run -d chrome
```

Validate the distributable web build with:

```text
flutter test
flutter build web --release
```
