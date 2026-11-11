#!/usr/bin/env python3
"""Both starter importers must record commits, including for annotated tags."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SEEDS = ROOT / 'automation/gitops/components/gitea/files/seed'
CASES = [('hummingbird-mirror-pipeline', 'seed-hummingbird-mirror.sh'),
         ('lightwell-dependencies', 'seed-lightwell-dependencies.sh')]
ADVISORY = 'automation/gitops/components/lightwell-repo/files/seed/LW-DEMO-0002.json'


def run(*args, env=None):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT).strip()


with tempfile.TemporaryDirectory(prefix='starter-release-test-') as tmp:
    base = Path(tmp)
    source = base / 'source'
    for name, _ in CASES:
        path = 'content/modules/ROOT/examples/' + name
        shutil.copytree(ROOT / path, source / path)
    (source / ADVISORY).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / ADVISORY, source / ADVISORY)
    run('git', 'init', '-q', '-b', 'main', str(source))
    run('git', '-C', str(source), 'config', 'user.name', 'Test')
    run('git', '-C', str(source), 'config', 'user.email', 'test@example.invalid')
    run('git', '-C', str(source), 'add', '.')
    run('git', '-C', str(source), 'commit', '-qm', 'Fixture')
    commit = run('git', '-C', str(source), 'rev-parse', 'HEAD')
    run('git', '-C', str(source), 'tag', 'lightweight')
    run('git', '-C', str(source), 'tag', '-a', 'annotated', '-m', 'Release candidate')
    assert run('git', '-C', str(source), 'rev-parse', 'annotated') != commit
    binpath = base / 'bin'
    binpath.mkdir()
    curl = binpath / 'curl'
    curl.write_text('''#!/usr/bin/env python3
import os, sys, subprocess
from pathlib import Path
a = sys.argv[1:]; url = a[-1]; repo = Path(os.environ['TEST_TARGET'])
if url.endswith('/api/healthz'): sys.exit(0)
if '/api/v1/repos/' in url:
    Path(a[a.index('-o') + 1]).write_text('{}')
    print('200' if repo.exists() else '404', end='')
elif url.endswith('/api/v1/orgs/workshop-templates/repos'):
    subprocess.check_call(['git', 'init', '--bare', '-q', str(repo)])
    print('{}')
else: sys.exit('Unexpected API URL: ' + url)
''')
    curl.chmod(0o755)
    for name, script in CASES:
        target = base / 'gitea/workshop-templates' / (name + '.git')
        target.parent.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, PATH=str(binpath) + os.pathsep + os.environ['PATH'],
                   SOURCE_REPO_URL=str(source), GITEA_URL='https://seed-test.invalid',
                   ADMIN_USER='test', ADMIN_PASSWORD='test', TEST_TARGET=str(target),
                   GIT_CONFIG_COUNT='1',
                   GIT_CONFIG_KEY_0='url.' + (base / 'gitea').as_uri() + '/.insteadOf',
                   GIT_CONFIG_VALUE_0='https://seed-test.invalid/')
        first = None
        for ref in ('annotated', 'lightweight', 'main', commit):
            env['SOURCE_REVISION'] = ref
            run('bash', str(SEEDS / script), env=env)
            actual = run('git', '--git-dir=' + str(target), 'show', 'main:WORKSHOP_REVISION')
            assert actual == commit, (name, ref, actual, commit)
            head = run('git', '--git-dir=' + str(target), 'rev-parse', 'main')
            if first is None:
                first = head
            assert head == first, 'Equivalent refs must not create new seed commits'
            expected = (source / 'content/modules/ROOT/examples' / name / 'README.md').read_text().strip()
            assert run('git', '--git-dir=' + str(target), 'show', 'main:README.md') == expected
        print('PASS:', name, 'records the same commit for annotated/lightweight tags, branch and SHA')
