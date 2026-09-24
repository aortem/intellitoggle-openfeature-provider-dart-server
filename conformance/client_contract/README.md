# IntelliToggle shared client contract evidence

This adapter runs the real `IntelliToggleRemoteClientProvider` against the
OpenFeature C01-C10 shared contract. The test transport supplies controlled OFREP
responses; a transparent wrapper counts shutdown calls and otherwise delegates
unchanged to the real provider. It does not simulate provider evaluation,
events, reconciliation or caching.

The SDK/contract is pinned to `c1dccdd0560526ce25c3a93b398c5e7af2528541`
(OpenFeature PR186). Run from this canonical provider repository:

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

The separate conformance package is unpublished. Published provider dependency
constraints, package versions and existing validation jobs remain unchanged.
