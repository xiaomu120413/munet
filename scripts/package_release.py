"""Build a signed release and export verified files to the repository's dist folder."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def local_signing_project():
    """Keep encrypted signing config and private build inputs in ignored sign_tools."""
    signing_root = ROOT / 'sign_tools'
    signing = signing_root / 'signing-config.json'
    if not signing.is_file():
        raise FileNotFoundError('Configure sign_tools/signing-config.json before packaging')
    sign = json.loads(signing.read_text(encoding='utf-8'))
    for key in ('storeFile', 'certpath', 'profile'):
        path = Path(sign['material'][key])
        resolved = (signing_root / path).resolve()
        if not resolved.is_relative_to(signing_root.resolve()) or not resolved.is_file():
            raise ValueError('Signing material must exist inside sign_tools: ' + key)
        sign['material'][key] = str(resolved)
    if not (signing_root / 'material').is_dir():
        raise FileNotFoundError('Missing sign_tools/material for the encrypted signing configuration')
    # Every build starts with current inputs, so renamed/deleted sources cannot linger.
    project = Path(tempfile.mkdtemp(prefix='build-', dir=signing_root))
    try:
        names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
                                        cwd=ROOT).decode('utf-8').split('\0')
        for name in names:
            if not name or name.startswith(('docs/', '.git')):
                continue
            source = ROOT / name
            if source.is_file():
                dest = project / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, dest)
        import _winapi
        _winapi.CreateJunction(str(ROOT / 'oh_modules'), str(project / 'oh_modules'))
        config = json.loads((ROOT / 'build-profile.json5').read_text(encoding='utf-8-sig'))
        config['app']['signingConfigs'] = [sign]
        for product in config['app']['products']:
            product['signingConfig'] = sign['name']
        (project / 'build-profile.json5').write_text(json.dumps(config, indent=2), encoding='utf-8')
        yield project
    finally:
        if project.resolve().parent != signing_root.resolve() or not project.name.startswith('build-'):
            raise ValueError('Unexpected build cleanup path')
        modules = project / 'oh_modules'
        if modules.is_junction():
            modules.rmdir()  # Remove only the junction; preserve the real dependency directory.
        shutil.rmtree(project)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT,
                        help='Project with local release signing configured; defaults to this project')
    parser.add_argument('--skip-build', action='store_true', help='Export an already built release')
    args = parser.parse_args()
    if args.project.resolve() == ROOT:
        if args.skip_build:
            parser.error('--skip-build requires --project pointing to an existing signed build')
        with local_signing_project() as project:
            package(project, False)
    else:
        package(args.project.resolve(), args.skip_build)


def package(project, skip_build):
    studio = Path(os.environ.get('DEVECO_STUDIO_HOME') or os.environ.get('DEVECO_STUDIO_PATH')
                  or 'C:/Program Files/Huawei/DevEco Studio')
    if not skip_build:
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
    private = ROOT / 'sign_tools/verification'
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
