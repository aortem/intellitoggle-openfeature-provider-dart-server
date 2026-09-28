# Server SDK integration evidence

The canonical IntelliToggle server provider is the candidate for OpenFeature
[server conformance issue #165](https://github.com/open-feature/dart-sdk/issues/165).
Run these commands from a clean provider checkout:

```sh
python3 tool/server_integration_evidence.py --baseline published
python3 tool/server_integration_evidence.py --baseline candidate
```

The published baseline is exactly server SDK `0.0.26`. The candidate is immutable
SDK commit `6f145989a88f55c39bfea08a2dde4fe0fadf59ae` (OpenFeature PR #198).
The helper records provider commit/tree/dirty state, actual resolved SDK path and
dependency graph, lockfile, Dart version, raw JSON tests and CI job/pipeline URLs.
It refuses an existing workspace override and removes its temporary override
after the run. Run `dart pub get` afterward to restore ordinary workspace resolution.

| Scenario | Evidence |
| --- | --- |
| S01 | SDK initialization awaits the real provider and delivers its ready event |
| S02 | SDK evaluation invokes hooks and passes each dynamic context to the project-scoped HTTP provider |
| S03 | HTTP flag-not-found returns the application default with error/finally hooks |
| S04 | Unsupported provider tracking accepts integer/double values without network delivery |
| S05 | SDK repeated shutdown closes the transport once; later SDK evaluations return defaults without HTTP requests |

The provider uses a controlled HTTP transport, fixture credentials and responses.
This does not claim real service acceptance, analytics delivery, all spontaneous
transport transitions or direct repeated provider shutdown conformance. S05
specifically tests SDK-mediated shutdown. The ordinary full server-provider suite
and all parent/child CI remain required alongside these two receipt jobs.

These receipts support maintainer review; they do not approve the SDK's 145
semantic mappings or close #165 on their own. Client v2 C01-C13 evidence remains
a separate contract and publication gate.
