# Changelog

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
