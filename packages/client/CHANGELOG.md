# Changelog

## 0.0.1-beta.1

- Add a web-compatible OFREP provider with short-lived evaluation-token
  callbacks, bulk initialization, context reconciliation, ETag refresh, and
  synchronous cached resolution.
- Keep OAuth client credentials out of browsers and Flutter applications.
- Validate the OpenFeature Dart client beta with Dart web and Flutter web
  compile targets and a Flutter snapshot demo.

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
