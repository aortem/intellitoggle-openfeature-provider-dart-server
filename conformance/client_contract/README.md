# IntelliToggle shared client contract evidence

This adapter runs the real `IntelliToggleRemoteClientProvider` against the
OpenFeature v2 C01-C13 shared contract. The test transport supplies controlled OFREP
responses; a transparent wrapper counts shutdown calls and otherwise delegates
unchanged to the real provider. It does not simulate provider evaluation,
events, reconciliation or caching.

The SDK/contract is pinned to `21539eb46b932c234c8daa3d4d080c3e5d703514`,
the OpenFeature development commit from merged PR193, including the asynchronous
event-observation regressions and direct provider lifecycle checks. This validates
the merged SDK source; it does
not imply that a new SDK package has been published. Run from this canonical
provider repository:

```sh
python3 tool/client_contract_evidence.py --platform vm
python3 tool/client_contract_evidence.py --platform chrome
```

Python 3, Git, Dart and Chrome/Chromium are required. `CHROME_EXECUTABLE` can name
the browser. `--sdk-checkout PATH` reuses a clean checkout only if it matches the
exact pin. Otherwise the helper creates an isolated ignored SDK checkout. The
helper writes an ignored override only when no different override already exists.

Receipts include exact SDK/provider/contract identities, dependency resolution,
platform and every scenario result. A passing controlled transport suite is not
production connectivity, token-server acceptance or native mobile evidence.
IntelliToggle is one implementation; its snapshot and remote providers do not
count as two independently maintained providers. OpenFeature #166/#167 still
require a second independent participant and maintainer review.

The shared suite exposed missing refresh error/recovery lifecycle events. The
provider now emits error for an active refresh failure and ready on successful
recovery, including ETag 304. Retired/closed requests cannot emit new readiness
or errors for the current identity. Targeted tests also cover late token failure
and refresh completion after shutdown. Existing token/request/identity tests
remain required; no credentials or vendor transport moved into OpenFeature core.

The separate conformance package is unpublished. The server provider now
requires the published OpenFeature server SDK `^0.0.26`. The client provider's
published SDK dependency remains `^0.0.1-beta.1`; the newer client source is
validated only through this pinned conformance package until its release.
Provider package versions and existing validation jobs remain unchanged.

Contract v2 declares `supportsReinitialization: false`: this provider permanently
closes its event stream on shutdown. Create a new provider instance to restart.
The C12 run exposed inconsistent uninitialized evaluation errors; the remote
provider now returns `providerNotReady` with caller defaults both before
initialization and after shutdown. Shutdown clears cached flags, context and
ETag state. Direct typed lifecycle and cache-clear regressions accompany the
shared suite; this does not claim live-backend or native mobile validation.
