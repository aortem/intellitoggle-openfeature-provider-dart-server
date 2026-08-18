# IntelliToggle OpenFeature providers for Dart

This repository is the Dart workspace for IntelliToggle's OpenFeature
providers. Server and client integrations live in separate publishable
packages so applications only depend on the OpenFeature API model appropriate
to their runtime.

## Packages

| Package | Runtime model | Status |
| --- | --- | --- |
| [`openfeature_provider_intellitoggle`](packages/server/) | Server-side, dynamic evaluation context | Published |
| `openfeature_provider_intellitoggle_client` | Client-side, static evaluation context | Planned |

The server package retains its existing pub.dev package name, imports, and
version history after its move to [`packages/server`](packages/server/).

## Workspace commands

Resolve all workspace dependencies from the repository root:

```bash
dart pub get
dart pub workspace list
```

Run validation for a specific package from its package directory:

```bash
cd packages/server
dart analyze
dart test
dart pub publish --dry-run
```

See each package README for configuration, security guidance, and usage.
