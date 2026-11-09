#!/usr/bin/env python3
"""Test the real skeleton assembler and Helm wiring without a live cluster."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import yaml

ROOT = Path(__file__).resolve().parents[1]
GITEA = ROOT / 'automation/gitops/components/gitea'
RHDH = ROOT / 'automation/gitops/components/rhdh'
ASSEMBLER = GITEA / 'files/seed/assemble-skeleton.sh'
SKELETON = 'automation/gitops/components/rhdh/files/skeletons/lightwell-java-service'

def run(*args, env=None):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT)

def chart_data(chart, name, *args):
    docs = yaml.safe_load_all(run('helm', 'template', 'test', str(chart), *args))
    return next(d['data'] for d in docs if d and d.get('metadata', {}).get('name') == name)

with tempfile.TemporaryDirectory(prefix='track3-rhdh-') as tmp:
    base = Path(tmp)
    source = base / 'source'
    shutil.copytree(ROOT / SKELETON, source / SKELETON)
    run('git', 'init', '-q', '-b', 'main', str(source))
    run('git', '-C', str(source), 'add', '.')
    run('git', '-C', str(source), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Fixture')
    seed = base / 'seed'
    seed.mkdir()
    for name, content in chart_data(GITEA, 'gitea-student-repo-seed').items():
        (seed / name).write_text(content)
    env = dict(os.environ, SOURCE_MODE='live', SOURCE_REPO_URL=str(source),
               SOURCE_REVISION='main', SKELETON_PATH=SKELETON, SEED_MOUNT=str(seed))
    output = base / 'assembled'
    run('bash', str(ASSEMBLER), str(output), env=env)
    # Exercise contracts consumed by Track 3 and Track 4.
    for name in ('renovate.json', 'lightwell-pins.properties', 'Dockerfile.known-bad'):
        assert (output / name).read_bytes() == (GITEA / 'files/seed/overlay' / name).read_bytes(), name
    for name in ('pipeline.yaml', 'pipelinerun.yaml', 'rbac.yaml'):
        assert (output / '.tekton' / name).read_bytes() == (GITEA / 'files/seed/overlay/tekton' / name).read_bytes(), name
    pom = ET.parse(output / 'pom.xml').getroot()
    ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
    assert pom.find('m:properties/m:commons.lang3.version', ns).text == '3.14.0'
    assert not (output / 'pom.xml.example').exists()
    assert 'ubi9/openjdk-21-runtime' in (output / 'Dockerfile').read_text()
    assert '${{ values.name }}' in (output / 'catalog-info.yaml').read_text()
    pins = (output / 'lightwell-pins.properties').read_text()
    assert 'commons-lang3=3.14.0.rhlw-00000' in pins
    assert 'sha256:' + '0' * 64 in pins
    managers = json.loads((output / 'renovate.json').read_text())['customManagers']
    assert {m['datasourceTemplate'] for m in managers} == {'maven', 'docker'}
    # A missing fixture must fail, rather than silently create a broken student repo.
    (seed / 'overlay-lightwell-pins.properties').unlink()
    result = subprocess.run(['bash', str(ASSEMBLER), str(base / 'missing')], env=env, text=True, capture_output=True)
    assert result.returncode != 0 and 'missing Java exercise overlay' in result.stderr

# Helm exposes readiness configuration but refuses empty plugin activation.
lab = chart_data(RHDH, 'lab-rhdh')
assert lab['gitea_scaffolder_enabled'] == 'true'
assert lab['scaffolder_username'] == 'gitea-admin'
result = subprocess.run(['helm', 'template', 'test', str(RHDH), '--set', 'dynamicPlugins.giteaScaffolder.package='], capture_output=True, text=True)
assert result.returncode != 0 and 'published dynamic plugin archive' in result.stderr
defaults = yaml.safe_load(chart_data(RHDH, 'dynamic-plugins-rhdh')['dynamic-plugins.yaml'])
assert defaults['plugins'][0]['package'].startswith('https://github.com/rhpds/lightwell-tssc-workshop/releases/download/')
assert defaults['plugins'][0]['integrity'].startswith('sha512-')
args = ('--set', 'dynamicPlugins.giteaScaffolder.enabled=true', '--set', 'dynamicPlugins.giteaScaffolder.package=https://example.invalid/plugin.tgz', '--set', 'dynamicPlugins.giteaScaffolder.integrity=sha512-test')
plugins = yaml.safe_load(chart_data(RHDH, 'dynamic-plugins-rhdh', *args)['dynamic-plugins.yaml'])
assert plugins['plugins'][0]['disabled'] is False
assert chart_data(RHDH, 'lab-rhdh', *args)['gitea_scaffolder_enabled'] == 'true'
bootstrap = ROOT / 'automation/gitops/bootstrap-infra'
docs = yaml.safe_load_all(run('helm', 'template', 'test', str(bootstrap), '--set', 'components.rhdh.giteaScaffolder.enabled=true', '--set', 'components.rhdh.giteaScaffolder.package=https://example.invalid/plugin.tgz', '--set', 'components.rhdh.giteaScaffolder.integrity=sha512-test'))
app = next(d for d in docs if d and d.get('metadata', {}).get('name') == 'test-rhdh')
assert app['spec']['source']['helm']['valuesObject']['dynamicPlugins']['giteaScaffolder'] == {'enabled': True, 'package': 'https://example.invalid/plugin.tgz', 'integrity': 'sha512-test'}
template = yaml.safe_load((RHDH / 'files/catalog/lightwell-java-service.yaml').read_text())
assert [s['action'] for s in template['spec']['steps']] == ['fetch:template', 'publish:gitea', 'catalog:register']
assert template['spec']['parameters'][0]['properties']['name']['const'] == 'spring-boot-lw-poc'
print('PASS: Java assembly parity, missing-overlay failure, plugin configuration and bootstrap forwarding, and RHDH action sequence')
