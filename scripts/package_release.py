"""Build a signed release and export verified files to the repository's dist folder."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT,
                        help='Project with local release signing configured; defaults to this project')
    parser.add_argument('--skip-build', action='store_true', help='Export an already built release')
    args = parser.parse_args()
    project = args.project.resolve()
    studio = Path(os.environ.get('DEVECO_STUDIO_HOME', 'C:/Program Files/Huawei/DevEco Studio'))
    if not args.skip_build:
        env = os.environ.copy()
        env['JAVA_HOME'] = str(studio / 'jbr')
        env['PATH'] = str(studio / 'tools/node') + os.pathsep + str(studio / 'jbr/bin') + os.pathsep + env.get('PATH', '')
        subprocess.run([str(studio / 'tools/node/node.exe'), str(studio / 'tools/hvigor/bin/hvigorw.js'),
                        'assembleApp', '--mode', 'project', '-p', 'product=default', '-p',
                        'buildMode=release', '--no-daemon'], cwd=project, env=env, check=True)
    app = project / 'build/outputs/default' / (project.name + '-default-signed.app')
    hap = project / 'entry/build/default/outputs/default/entry-default-signed.hap'
    expected = json.loads((ROOT / 'AppScope/app.json5').read_text(encoding='utf-8'))['app']
    with zipfile.ZipFile(hap) as package:
        actual = json.loads(package.read('module.json'))['app']
        for key in ('bundleName', 'versionName', 'versionCode'):
            if actual[key] != expected[key]:
                raise ValueError('Release does not match current project: ' + key)
        if actual.get('debug') is not False or actual.get('buildMode') != 'release':
            raise ValueError('Expected a release package')
    # Verify before exporting, and keep certificate/Profile output out of dist.
    private = ROOT / 'artifacts/signing/dist-verification'
    private.mkdir(parents=True, exist_ok=True)
    for source in (app, hap):
        result = subprocess.run([str(studio / 'jbr/bin/java.exe'), '-jar',
            str(studio / 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'),
            'verify-app', '-inFile', str(source), '-outCertChain', str(private / (source.suffix[1:] + '.cer')),
            '-outProfile', str(private / (source.suffix[1:] + '.p7b'))], capture_output=True)
        (private / (source.suffix[1:] + '.log')).write_bytes(result.stdout + result.stderr)
        result.check_returncode()
    output = ROOT / 'dist'
    output.mkdir(exist_ok=True)
    manifest = {'bundle': expected['bundleName'], 'version': expected['versionName'],
                'versionCode': expected['versionCode'], 'sdk_signature_verified': True, 'artifacts': {}}
    for source in (app, hap):
        dest = output / ('MuNet-' + expected['versionName'] + '-release-signed' + source.suffix)
        shutil.copy2(source, dest)
        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        manifest['artifacts'][dest.name] = {'bytes': dest.stat().st_size, 'sha256': digest}
        print(dest)
    (output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
