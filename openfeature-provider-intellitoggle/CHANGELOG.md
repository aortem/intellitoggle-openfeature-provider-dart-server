
## 0.0.8

### Changed

* Declared `openfeature_provider_intellitoggle` as the canonical Dart server package for IntelliToggle.
* Deprecated the legacy in-repo `intellitoggle_server_sdk` package and consolidated provider ownership here.
* Updated package documentation to reflect the OAuth client-credentials flow as the primary integration model.

## 0.0.7

### Added

* Added OpenFeature tracking support via `IntelliToggleClient.track()`.
* Added no-op tracking implementations for the IntelliToggle and in-memory providers to align with the OpenFeature spec.
* Added OpenTelemetry-compatible telemetry hook documentation and release notes coverage for the latest provider capabilities.

### Changed

* Bumped `openfeature_dart_server_sdk` compatibility to `^0.0.17`.
* Re-exported `FeatureProvider` while hiding the SDK `InMemoryProvider` to avoid symbol conflicts.
* Updated OFREP documentation and usage examples to reflect the current provider API and remote-evaluation flow.
* Refreshed package and example dependency references for the `0.0.7` release.

## 0.0.6

### Added

* Added local execution support for running the OpenFeature provider server during tests.
* Added improved error handling and coverage for evaluation failures.
* Added initial tracing and metrics hooks for feature flag evaluation flows.
* Added additional test coverage for provider lifecycle and error scenarios.
* Added stronger validation and guardrails around provider startup configuration.
* Added expanded tracing spans for flag resolution and provider lifecycle events.
* Added test helpers to simplify local provider execution in CI and developer environments.


### Changed

* Improved provider initialization and shutdown handling.
* Refactored test setup to better reflect real-world provider usage.
* Updated README with clearer local usage and testing instructions.
* Improved resilience of feature flag evaluation under partial provider failures.
* Refined metrics emission to reduce noise and improve signal consistency.
* Simplified test bootstrapping to reduce duplication and improve readability.

### Fixed

* Fixed edge cases where provider shutdown could leave dangling resources in tests.
* Fixed inconsistent error propagation during failed evaluations.

## 0.0.5

### Changed
- Updated README with improved usage documentation.

### Removed
- Dependency on deprecated `gherkin` package.

## 0.0.4

### Changed
- Updated repository URL.

## 0.0.3

### Changed
- Updated README and GitHub repository link.

## 0.0.2

### Added
- Implemented `@override` for `ProviderMetadata` getter with required fields.
- Ensured `FlagEvaluationResult` sets all required fields in every code path.
- Added proper error codes (`FLAG_NOT_FOUND`, `TYPE_MISMATCH`, `GENERAL`) for error scenarios.
- Implemented correct provider state transitions per OpenFeature lifecycle.

## 0.0.1

### Added
- Initial release of `intellitoggle-openfeature-provider-dart`.
