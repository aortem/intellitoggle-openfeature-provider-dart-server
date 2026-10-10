# Dart SDK and provider support windows

Aortem's published plan covers the client SDK/provider on the current stable
Dart minor and three previous minors (N through N-3), and the server SDK/provider
on the current and previous stable minor (N through N-1). These are Dart minor
versions; Flutter's bundled Dart and native platform acceptance are separate.

For N=3.13 the client matrix is 3.10-3.13. The CI representatives are 3.10.0
(the declared minimum), 3.11.0, 3.12.2 and 3.13.4 on both VM and Chrome. Run
`python3 tool/client_support_evidence.py --platform vm` or `--platform chrome`
with the chosen Dart executable on PATH. Revisit the matrix when a new stable
minor arrives; changing the supported floor requires normal review and migration
notes rather than silently dropping the public support promise.

The client compatibility helper copies the package to an isolated receipt
folder and uses Dart's documented standalone workspace resolution. It keeps the
provider runtime source unchanged, resolves the actual hosted client SDK0.0.1,
and copies the reviewed C01-C13 contract at SDK release commit4b10dd84. The
unpublished test harness is adapted to the hosted SDK; no runtime dependency
override hides the server workspace floor. Receipts keep exact Dart version,
source identity, dependency lock, unit tests, web compile and all contract results.

The server workspace remains Dart3.12.2+. Existing server validation and original
pinned-candidate contract jobs remain required. Passing this controlled-transport
client matrix is not live-backend, native-device, independent provider or API1.0
certification. The published client provider beta.3 retains its3.12.2 floor until
a reviewed compatibility package release is published and its archive is verified.

## Published server provider validation, October 10, 2026

The immutable hosted server provider0.0.16 with hosted server SDK0.1.0 passed
its archive contract tests and every S01-S05 controlled-transport scenario on
standalone Windows Dart3.12.2,3.13.4 and current stable3.13.5. Dependency locks
and package configuration were retained without overrides; the3.13.5 SDK
archive was checked against its official SHA256. Three optional live tests
requiring separately configured credentials remain separate from these passed
controlled scenarios. Existing native support-window jobs remain required.

These receipts validate the current and previous server minor; they do not
extend the declared minimum, certify another OS, or establish deployed
application consumption. The client VM/Chrome and native-device gates, SDK
independent-provider evidence, actual app/runtime checks and October31 provider
milestone decision remain separate. Publishing0.1.0 is not automatic.

The existing0.0.x consumer constraints do not admit0.1.0. Maintainers must
deliberately review constraints and migration behavior before that milestone.
For current0.0.16 retry configuration, see the server README: `maxRetries: 1`
means one total readiness attempt; zero does not mean one attempt without retry.
