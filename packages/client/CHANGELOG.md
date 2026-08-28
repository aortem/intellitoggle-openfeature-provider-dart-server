# Changelog

## Unreleased

- Validate the OpenFeature Dart client beta with Dart web and Flutter web
  compile targets.
- Resolve the published `openfeature_dart_client_sdk` beta from pub.dev.
- Add a Flutter demo that replaces backend-resolved IntelliToggle snapshots.

## 0.0.1-alpha.2

- Invalidate backend-resolved snapshots when the OpenFeature evaluation
  context changes.
- Add decoded JSON snapshot parsing with evaluation metadata preservation.
- Widen JSON integers for double flags and report only genuinely changed keys.
- Expose shutdown state and consistently reject non-JSON snapshot values.

## 0.0.1-alpha.1

- Add a public-safe OpenFeature client provider for backend-resolved snapshots.
- Support typed local evaluation, immutable snapshot replacement, and
  configuration-change events.
