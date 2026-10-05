# Changelog

## Unreleased

- Align the client provider with published OpenFeature client SDK `0.0.1`.
- Lower the client Dart minimum to `3.10.0`; validate the isolated package
  and shared provider contract on Dart 3.10, 3.11, 3.12 and 3.13 in VM/Chrome.
- Preserve the server workspace minimum; client compatibility is resolved
  independently without runtime dependency overrides.

## 0.0.1-beta.3

- Require the published OpenFeature Dart Client SDK `0.0.1-beta.2` or later
  within the existing prerelease constraint.
- Report failed refreshes with provider error events and emit readiness again
  when a subsequent refresh recovers, including unchanged flag snapshots.

- Report `providerNotReady` consistently before remote initialization and after
  shutdown, while preserving typed caller defaults.
- Clear cached flags, context and validators during shutdown. Provider instances
  remain single-use; the shared v2 contract declares no reinitialization support.

## 0.0.1-beta.2

- Point package metadata at the public GitHub mirror so pub.dev users can
  inspect the source, examples, and issue history without private-repository
  access.

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
