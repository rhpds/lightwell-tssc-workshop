#!/usr/bin/env python3
"""Check Java ACS ordering and execute the rendered gate with stubbed network IO.

Requires Helm and PyYAML. Does not emulate or contact a Tekton controller.
"""
import os
from pathlib import Path
import subprocess
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = ROOT / 'automation/gitops/components'
pipeline = yaml.safe_load((COMPONENTS / 'gitea/files/seed/overlay/tekton/pipeline.yaml').read_text())['spec']
tasks = {t['name']: t for t in pipeline['tasks']}
finals = {t['name']: t for t in pipeline['finally']}
assert 'acs-image-check' not in tasks, 'ACS must not race signing in the regular DAG'
acs = finals['acs-image-check']
assert 'runAfter' not in acs, 'finally tasks cannot use runAfter'
assert acs['when'] == [{'input': '$(tasks.openshift-build.status)', 'operator': 'in', 'values': ['Succeeded']}]
assert acs.get('onError', 'stopAndFail') == 'stopAndFail', 'ACS failures must fail the run'
assert tasks['syft-sbom-rhtpa']['runAfter'] == ['openshift-build']
assert tasks['cosign-sign-keyless']['runAfter'] == ['syft-sbom-rhtpa']
assert all(dep in tasks for task in tasks.values() for dep in task.get('runAfter', []))
assert {p['name']: p['value'] for p in acs['taskRef']['params']} == {
    'kind': 'task', 'name': 'acs-image-check', 'namespace': 'stackrox'}
assert {p['name']: p['value'] for p in acs['params']} == {
    'image': '$(params.image-url)', 'fail-on-skipped': 'false'}

# Exercise the real rendered ACS script: policy failures retain a failing exit
# status, while Track 7's strict missing-credential setting also fails closed.
docs = list(yaml.safe_load_all(subprocess.check_output(
    ['helm', 'template', 'test', str(COMPONENTS / 'rhacs')], text=True)))
task = next(d for d in docs if d and d['kind'] == 'Task' and d['metadata']['name'] == 'acs-image-check')
step = task['spec']['steps'][0]
assert step.get('onError', 'stopAndFail') == 'stopAndFail'
with tempfile.TemporaryDirectory(prefix='acs-final-check-') as tmp:
    base = Path(tmp)
    secrets = base / 'secrets'; secrets.mkdir()
    shared = base / 'shared'; shared.mkdir()
    bins = base / 'bin'; bins.mkdir()
    result = base / 'result'
    script = step['script'].replace('/rox-secret', str(secrets)).replace('/steps-shared-folder', str(shared))
    script = script.replace('$(results.check-status.path)', str(result))
    (base / 'check.sh').write_text(script)
    (secrets / 'rox-api-endpoint').write_text('central.example.invalid:443')
    (secrets / 'rox-api-token').write_text('test-only')
    # curl supplies a mock roxctl binary, so the gate itself still runs unchanged.
    curl = bins / 'curl'
    mock_roxctl = """#!/usr/bin/env bash
echo '{"summary":{},"fixture":true}'
exit "$TEST_ROX_STATUS"
"""
    curl.write_text(
        '#!/usr/bin/env python3\nimport pathlib,sys\n'
        "p=pathlib.Path(sys.argv[sys.argv.index('--output')+1])\n"
        + 'p.write_text(' + repr(mock_roxctl) + ')\n')
    curl.chmod(0o755)
    env = dict(os.environ, PATH=str(bins)+os.pathsep+os.environ['PATH'],
               PARAM_IMAGE='registry.example.invalid/app@sha256:'+'a'*64,
               PARAM_INSECURE_SKIP_TLS_VERIFY='false', PARAM_FAIL_ON_SKIPPED='true')
    for status, expected in [('0', 'passed'), ('1', 'failed')]:
        output = subprocess.run(['bash', 'check.sh'], cwd=base,
                                env=dict(env, TEST_ROX_STATUS=status), capture_output=True, text=True)
        assert output.returncode == int(status), output.stdout + output.stderr
        assert result.read_text() == expected
        assert '"fixture":true' in output.stdout, 'Keep the scan report visible'
    (secrets / 'rox-api-token').unlink()
    output = subprocess.run(['bash', 'check.sh'], cwd=base, env=env, capture_output=True, text=True)
    assert output.returncode != 0 and result.read_text() == 'skipped'
print('PASS: final ACS ordering, successful-build guard, preserved policy failure and strict missing-credential failure')
