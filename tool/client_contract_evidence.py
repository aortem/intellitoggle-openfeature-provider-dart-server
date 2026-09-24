"""Run the canonical IntelliToggle adapter against one immutable SDK contract."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import sys

SDK_COMMIT = '675b9af76301649c6b1796ad2672c1579fbc6281'


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['vm','chrome'], default='vm')
    parser.add_argument('--sdk-checkout', help='Reuse an existing clean checkout at the exact pinned commit')
    parser.add_argument('--output', default='build/client-contract')
    options = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sdk = Path(options.sdk_checkout).resolve() if options.sdk_checkout else root/'.dart_tool/shared-client-sdk'
    if not sdk.exists():
        if options.sdk_checkout:
            raise RuntimeError('Requested SDK checkout does not exist')
        sdk.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git','clone','--filter=blob:none','--no-checkout','https://github.com/open-feature/dart-sdk.git',str(sdk)],check=True)
        subprocess.run(['git','-C',str(sdk),'checkout','--detach',SDK_COMMIT],check=True)
    actual = subprocess.check_output(['git','-C',str(sdk),'rev-parse','HEAD'],encoding='utf-8').strip()
    dirty = subprocess.check_output(['git','-C',str(sdk),'status','--porcelain'],encoding='utf-8').strip()
    if actual != SDK_COMMIT or dirty:
        raise RuntimeError('SDK checkout must be clean and match the pinned commit')
    package = root/'conformance/client_contract'
    overrides = package/'pubspec_overrides.yaml'
    text = ('dependency_overrides:\n  openfeature_dart_client_sdk:\n    path: '+(sdk/'packages/openfeature_dart_client_sdk').as_posix()+
        '\n  openfeature_client_provider_contract:\n    path: '+(sdk/'conformance/client_provider_contract').as_posix()+'\n')
    if overrides.exists() and overrides.read_text() != text:
        raise RuntimeError('Refusing to overwrite a different local dependency override')
    overrides.write_text(text)
    dart = shutil.which('dart')
    subprocess.run([dart,'pub','get'],cwd=package,check=True)
    subprocess.run([dart,'format','--output=none','--set-exit-if-changed','test'],cwd=package,check=True)
    subprocess.run([dart,'analyze'],cwd=package,check=True)
    output = Path(options.output).resolve()/options.platform
    return subprocess.run([sys.executable,str(sdk/'tool/client_provider_evidence.py'),
        '--classification','external','--canonical-repository','https://gitlab.com/dartapps/apps/intellitoggle/openfeature-provider-intellitoggle',
        '--provider-repo',str(root),'--working-directory',str(package),
        '--test-target','test/shared_contract_test.dart','--platform',options.platform,
        '--output',str(output)],env=os.environ.copy()).returncode


if __name__ == '__main__':
    sys.exit(run())
