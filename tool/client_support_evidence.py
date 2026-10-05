"""Validate client support independently of the server workspace and hosted SDK."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import shutil
import subprocess

SDK_COMMIT = '4b10dd84ae94bb6d849b9a450b6a48fb127505a5'
SDK_VERSION = '0.0.1'


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], encoding='utf-8').strip()


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['vm', 'chrome'], required=True)
    parser.add_argument('--sdk-checkout')
    parser.add_argument('--output', default='build/client-support')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    dart = shutil.which('dart')
    if dart is None:
        raise RuntimeError('Dart is required')
    dart_version = subprocess.check_output([dart, '--version'], encoding='utf-8').strip()
    version = re.search(r'version: (\d+\.\d+\.\d+)', dart_version)[1]
    out = Path(args.output).resolve() / version / args.platform
    if out.exists():
        raise RuntimeError('Use a fresh receipt directory; existing evidence is preserved')
    out.mkdir(parents=True)
    sdk = Path(args.sdk_checkout).resolve() if args.sdk_checkout else root / '.dart_tool/support-sdk'
    if not sdk.exists():
        if args.sdk_checkout:
            raise RuntimeError('Requested SDK checkout is missing')
        sdk.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--filter=blob:none', '--no-checkout',
                        'https://github.com/open-feature/dart-sdk.git', str(sdk)], check=True)
        subprocess.run(['git', '-C', str(sdk), 'checkout', '--detach', SDK_COMMIT], check=True)
    if git(sdk, 'rev-parse', 'HEAD') != SDK_COMMIT or git(sdk, 'status', '--porcelain'):
        raise RuntimeError('Harness checkout must be clean at the reviewed release commit')
    ignored = shutil.ignore_patterns('.dart_tool', 'build', 'pubspec.lock', 'pubspec_overrides.yaml')
    provider = out / 'provider'
    shutil.copytree(root / 'packages/client', provider, ignore=ignored)
    # Official standalone resolution escape; no runtime dependency overrides.
    (provider / 'pubspec_overrides.yaml').write_text('resolution:\n', encoding='utf-8')
    harness = out / 'harness'
    shutil.copytree(sdk / 'conformance/client_provider_contract', harness, ignore=ignored)
    manifest = harness / 'pubspec.yaml'
    original = manifest.read_text(encoding='utf-8')
    needle = 'openfeature_dart_client_sdk:\n    path: ../../packages/openfeature_dart_client_sdk'
    if original.count(needle) != 1:
        raise RuntimeError('Review the harness manifest before adapting its test dependency')
    manifest.write_text(original.replace(needle, f'openfeature_dart_client_sdk: {SDK_VERSION}'), encoding='utf-8')
    runtime_hashes = {}
    for source in (root / 'packages/client/lib').rglob('*.dart'):
        relative = source.relative_to(root / 'packages/client')
        copied = provider / relative
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(copied.read_bytes()).hexdigest() != source_hash:
            raise RuntimeError('Staged provider runtime differs from current source')
        runtime_hashes[relative.as_posix()] = source_hash
    consumer = out / 'consumer'
    (consumer / 'test').mkdir(parents=True)
    shutil.copyfile(root / 'conformance/client_contract/test/shared_contract_test.dart', consumer / 'test/shared_contract_test.dart')
    (consumer / 'pubspec.yaml').write_text(f'''name: client_support_consumer
publish_to: none
environment:
  sdk: ^3.10.0
dependencies:
  http: ^1.6.0
  test: ^1.26.3
  openfeature_dart_client_sdk: {SDK_VERSION}
  openfeature_provider_intellitoggle_client:
    path: ../provider
  openfeature_client_provider_contract:
    path: ../harness
''', encoding='utf-8')
    commands = []

    def execute(cwd, label, command):
        result = subprocess.run([dart, *command], cwd=cwd, encoding='utf-8',
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (out / (label + '.log')).write_text(result.stdout, encoding='utf-8')
        commands.append({'label': label, 'arguments': command, 'exit_code': result.returncode})
        if result.returncode:
            raise RuntimeError(f'{label} failed; inspect {out / (label + ".log")}')
        return result.stdout

    success = False
    try:
        execute(provider, 'provider-get', ['pub', 'get'])
        execute(provider, 'provider-analyze', ['analyze'])
        unit_output = execute(provider, 'provider-tests', ['test', '--platform', args.platform, '--reporter=json'])
        execute(provider, 'provider-web-compile', ['compile', 'js', 'test/web_compile_smoke.dart', '-o', 'build/smoke.js'])
        execute(consumer, 'consumer-get', ['pub', 'get'])
        execute(consumer, 'consumer-analyze', ['analyze'])
        deps = json.loads(execute(consumer, 'consumer-dependencies', ['pub', 'deps', '--json']))
        loaded = next(p for p in deps['packages'] if p['name'] == 'openfeature_dart_client_sdk')
        if loaded['version'] != SDK_VERSION or loaded['source'] != 'hosted':
            raise RuntimeError('The consumer must use the actual hosted client SDK')
        output = execute(consumer, 'contract-tests', ['test', '--platform', args.platform, '--reporter=json', 'test/shared_contract_test.dart'])
        # Reuse the reviewed canonical summary, including all C01-C13 assertions.
        import importlib.util
        spec = importlib.util.spec_from_file_location('canonical_evidence', sdk / 'tool/client_provider_evidence.py')
        evidence = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(evidence)
        summary = evidence.summarize(output)
        if not summary['all_scenarios_passed'] or summary['platforms'] != [args.platform]:
            raise RuntimeError('Canonical scenario/platform verification failed')
        unit_events = [json.loads(line) for line in unit_output.splitlines()]
        unit_passed = sum(e['type'] == 'testDone' and not e['hidden'] and not e['skipped'] and e['result'] == 'success' for e in unit_events if e['type'] == 'testDone')
        shutil.copyfile(consumer / 'pubspec.lock', out / 'consumer-pubspec.lock')
        success = True
    finally:
        receipt = {'observed_at': datetime.now(timezone.utc).isoformat(), 'dart': dart_version,
                   'platform': args.platform, 'provider_commit': git(root, 'rev-parse', 'HEAD'),
                   'provider_tree': git(root, 'rev-parse', 'HEAD^{tree}'),
                   'provider_dirty': bool(git(root, 'status', '--porcelain')), 'harness_commit': SDK_COMMIT,
                   'hosted_sdk_version': SDK_VERSION, 'commands': commands, 'success': success,
                   'staged_provider_runtime_sha256': runtime_hashes,
                   'classification': 'first-party compatibility QA; controlled OFREP transport',
                   'native_or_live_backend_acceptance': False, 'independent_adoption': False}
        if success:
            receipt.update(summary)
            receipt['provider_unit_tests_passed'] = unit_passed
            receipt['runtime_dependencies'] = deps
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'dart': version, 'platform': args.platform, 'unit_tests': unit_passed,
                      'contract_scenarios': len(summary['scenarios']), 'success': success}), flush=True)


if __name__ == '__main__':
    run()
