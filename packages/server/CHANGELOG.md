## [0.0.13]

- Await the initialization result inside its error-handling block when shutdown interrupts initialization. This also resolves the newer Dart analyzer warning that blocked full server CI validation.
- Retain the project identity verification introduced in 0.0.12. Enable explicit project selection after the IntelliToggle 0.1.5 API rollout is verified.

## [0.0.12]

- Add projectId configuration and project/environment request headers. Explicit project evaluations fail closed unless the API confirms tenant, project and environment identity. Partition cached evaluations by that identity.
- Enable explicit project selection after IntelliToggle API 0.1.5 is deployed and the returned scope is verified. Existing configurations without projectId retain compatibility.

## 0.0.11

- Updated compatibility to `openfeature_dart_server_sdk` `^0.0.24` so the
  provider installs with the current published server SDK.
- Aligned provider metadata, outbound headers, documentation, and the example
  package with version `0.0.11`.

## 0.0.10

- Corrected IntelliToggle OAuth and flag evaluation routes to the canonical
  `/api/v1` endpoints.
- Send evaluation attributes as IntelliToggle's top-level context contract,
  preserve JSON-compatible and dotted attributes, and remove declared private
  attributes before transmission.
- Added an optional default environment for server-side evaluations.
- Enforce OpenFeature type-mismatch fallbacks instead of coercing invalid
  response values.
- Preserve optional variants in the in-memory provider so detailed evaluation
  and OpenFeature conformance tests exercise variant propagation.
- Aligned provider metadata and outbound headers with package version `0.0.10`.
- Updated to `openfeature_dart_server_sdk` `^0.0.23` and Dart `^3.12.2`.


## 0.0.9

### Changed

* Bumped `openfeature_dart_server_sdk` compatibility to `^0.0.19`.
* Updated the provider and examples for the async `OpenFeatureAPI.setProvider(...)` flow.
* Re-exported the SDK hook and multi-provider helpers from this package.
* Hardened `ConsoleLoggingHook` against complex and circular evaluation payloads.
* Moved telemetry hook span state into evaluation-scoped hook data to avoid cross-request collisions.

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
