"""Record canonical server-provider integration against published and candidate SDKs."""
from pathlib import Path
from urllib.parse import unquote, urlparse
import argparse
import json
import os
import shutil
import subprocess

SDK_COMMIT = '8bfe8971aed82e816220c4514f7bd005417e0894'
PUBLISHED_VERSION = '0.1.0'


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], encoding='utf-8').strip()


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', choices=['published', 'candidate'], required=True)
    parser.add_argument('--output', default='build/server-integration')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = Path(args.output).resolve() / args.baseline
    out.mkdir(parents=True, exist_ok=True)
    dart = shutil.which('dart')
    if dart is None:
        raise RuntimeError('Dart is required')
    override = root / 'pubspec_overrides.yaml'
    if override.exists():
        raise RuntimeError('Refusing to replace an existing workspace override')
    sdk = None
    if args.baseline == 'candidate':
        sdk = root / '.dart_tool/server-integration-sdk'
        if not sdk.exists():
            subprocess.run(['git', 'clone', '--filter=blob:none', '--no-checkout',
                            'https://github.com/open-feature/dart-sdk.git', str(sdk)], check=True)
            subprocess.run(['git', '-C', str(sdk), 'checkout', '--detach', SDK_COMMIT], check=True)
        if git(sdk, 'rev-parse', 'HEAD') != SDK_COMMIT or git(sdk, 'status', '--porcelain'):
            raise RuntimeError('SDK must be clean at the pinned candidate commit')
        dependency = '    path: ' + (sdk / 'packages/openfeature_dart_server_sdk').as_posix()
    else:
        dependency = '    version: ' + PUBLISHED_VERSION + '\n    hosted: https://pub.dev'
    override.write_text('dependency_overrides:\n  openfeature_dart_server_sdk:\n' + dependency + '\n', encoding='utf-8')
    try:
        subprocess.run([dart, 'pub', 'get'], cwd=root, check=True)
        config_path = root / '.dart_tool/package_config.json'
        config = json.loads(config_path.read_text(encoding='utf-8'))
        entry = next(p for p in config['packages'] if p['name'] == 'openfeature_dart_server_sdk')
        uri = urlparse(entry['rootUri'])
        if uri.scheme == 'file':
            path = unquote(uri.path)
            if os.name == 'nt' and path.startswith('/'):
                path = path[1:]
            resolved = Path(path).resolve()
        elif not uri.scheme:
            resolved = (config_path.parent / unquote(entry['rootUri'])).resolve()
        else:
            raise RuntimeError('Unexpected resolved SDK URI')
        if sdk and resolved != (sdk / 'packages/openfeature_dart_server_sdk').resolve():
            raise RuntimeError('Tests are not using the pinned SDK checkout')
        shutil.copyfile(root / 'pubspec.lock', out / 'pubspec.lock')
        shutil.copyfile(config_path, out / 'package_config.json')
        deps = json.loads(subprocess.check_output([dart, 'pub', 'deps', '--json'], cwd=root, encoding='utf-8'))
        sdk_dependency = next(p for p in deps['packages'] if p['name'] == 'openfeature_dart_server_sdk')
        if args.baseline == 'published' and (sdk_dependency['version'] != PUBLISHED_VERSION or sdk_dependency['source'] != 'hosted'):
            raise RuntimeError('Published baseline did not resolve the exact hosted SDK')
        (out / 'dependencies.json').write_text(json.dumps(deps, indent=2), encoding='utf-8')
        result = subprocess.run([dart, 'test', 'test/sdk_conformance_integration_test.dart', '--reporter=json'],
                                cwd=root / 'packages/server', encoding='utf-8', capture_output=True)
        (out / 'tests.jsonl').write_text(result.stdout, encoding='utf-8')
        (out / 'tests.stderr.log').write_text(result.stderr, encoding='utf-8')
        tests = {}
        completed = False
        for line in result.stdout.splitlines():
            event = json.loads(line)
            if event['type'] == 'testStart':
                tests[event['test']['id']] = {'name': event['test']['name'], 'result': 'unfinished'}
            elif event['type'] == 'testDone' and event['testID'] in tests:
                tests[event['testID']].update(result=event['result'], skipped=event['skipped'], hidden=event['hidden'])
            elif event['type'] == 'done':
                completed = event['success']
        cases = [t for t in tests.values() if t['name'].startswith(('S01 ', 'S02 ', 'S03 ', 'S04 ', 'S05 '))]
        passed = (result.returncode == 0 and completed and len(cases) == 5 and
                  {t['name'][:3] for t in cases} == {'S01', 'S02', 'S03', 'S04', 'S05'} and
                  all(t['result'] == 'success' and not t.get('skipped') and not t.get('hidden') for t in cases))
        report = {
            'schema': 1, 'canonical_repository': 'https://gitlab.com/dartapps/apps/intellitoggle/openfeature-provider-intellitoggle',
            'provider_commit': git(root, 'rev-parse', 'HEAD'), 'provider_tree': git(root, 'rev-parse', 'HEAD^{tree}'),
            'provider_dirty': bool(git(root, 'status', '--porcelain')), 'baseline': args.baseline,
            'sdk_commit': SDK_COMMIT if sdk else None, 'sdk_dirty': False if sdk else None,
            'sdk_dependency': sdk_dependency, 'resolved_sdk_path': str(resolved),
            'dart': subprocess.check_output([dart, '--version'], encoding='utf-8').strip(),
            'ci_job': os.environ.get('CI_JOB_URL'), 'ci_pipeline': os.environ.get('CI_PIPELINE_URL'),
            'scenarios': cases, 'passed': passed,
            'boundary': 'Controlled HTTP transport with actual canonical provider and SDK. Tracking is unsupported/no-op. Not live-backend acceptance or semantic conformance certification.',
        }
        (out / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'baseline': args.baseline, 'passed': passed, 'provider_dirty': report['provider_dirty'], 'cases': len(cases)}))
        return 0 if passed and not report['provider_dirty'] else 1
    finally:
        override.unlink()


if __name__ == '__main__':
    raise SystemExit(run())
