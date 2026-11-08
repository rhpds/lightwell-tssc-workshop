#!/usr/bin/env python3
"""Exercise the seed script with real temporary Git repos and a fake Gitea API."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / 'automation/gitops/components/gitea/files/seed/seed-lightwell-dependencies.sh'
STARTER = 'content/modules/ROOT/examples/lightwell-dependencies'
ADVISORY = 'automation/gitops/components/lightwell-repo/files/seed/LW-DEMO-0002.json'

def run(*args, env=None):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT).strip()

with tempfile.TemporaryDirectory(prefix='track2-seed-test-') as tmp:
    base = Path(tmp)
    source = base / 'source'
    source.mkdir()
    shutil.copytree(ROOT / STARTER, source / STARTER)
    (source / ADVISORY).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / ADVISORY, source / ADVISORY)
    run('git', 'init', '-q', str(source))
    run('git', '-C', str(source), 'add', '.')
    def commit(message):
        run('git', '-C', str(source), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qam', message)
        return run('git', '-C', str(source), 'rev-parse', 'HEAD')
    revision = commit('Initial fixture')
    target = base / 'gitea/workshop-templates/lightwell-dependencies.git'
    target.parent.mkdir(parents=True)
    binpath = base / 'bin'
    binpath.mkdir()
    curl = binpath / 'curl'
    curl.write_text('''#!/usr/bin/env python3
import os,sys,subprocess
from pathlib import Path
a=sys.argv[1:]; url=a[-1]; repo=Path(os.environ['TEST_TARGET'])
if url.endswith('/api/healthz'): sys.exit(0)
if '/api/v1/repos/' in url:
    Path(a[a.index('-o')+1]).write_text('{}')
    print('200' if repo.exists() else '404',end='')
elif url.endswith('/api/v1/orgs/workshop-templates/repos'):
    subprocess.check_call(['git','init','--bare','-q',str(repo)])
    print('{}')
else: sys.exit('Unexpected API URL: '+url)
''')
    curl.chmod(0o755)
    env = dict(os.environ, PATH=str(binpath)+os.pathsep+os.environ['PATH'],
               SOURCE_REPO_URL=str(source), SOURCE_REVISION=revision,
               GITEA_URL='https://track2-test.invalid', ADMIN_USER='test', ADMIN_PASSWORD='test',
               TEST_TARGET=str(target), GIT_CONFIG_COUNT='1',
               GIT_CONFIG_KEY_0='url.'+(base/'gitea').as_uri()+'/.insteadOf',
               GIT_CONFIG_VALUE_0='https://track2-test.invalid/')
    run('bash', str(SEED), env=env)
    first = run('git', '--git-dir='+str(target), 'rev-parse', 'main')
    assert run('git', '--git-dir='+str(target), 'show', 'main:WORKSHOP_REVISION') == revision
    assert run('git', '--git-dir='+str(target), 'show', 'main:advisories/LW-DEMO-0002.json') == (ROOT/ADVISORY).read_text().strip()
    run('bash', str(SEED), env=env)
    assert run('git', '--git-dir='+str(target), 'rev-parse', 'main') == first
    student = base / 'student'
    run('git', 'clone', '-q', '--branch', 'main', str(target), str(student))
    (student/'pom.xml').write_text('student local edit\n')
    with (source/STARTER/'README.md').open('a') as f:
        f.write('\nUpdated fixture.\n')
    env['SOURCE_REVISION'] = commit('Update fixture')
    run('bash', str(SEED), env=env)
    assert run('git', '--git-dir='+str(target), 'rev-parse', 'main') != first
    assert (student/'pom.xml').read_text() == 'student local edit\n'
    assert run('git', '-C', str(student), 'rev-parse', 'HEAD') == first
    assert run('git', '--git-dir='+str(target), 'show', 'main:WORKSHOP_REVISION') == env['SOURCE_REVISION']
    # A missing required starter file must fail before mutating the remote.
    before = run('git', '--git-dir='+str(target), 'rev-parse', 'main')
    (source/STARTER/'pom.xml').unlink()
    env['SOURCE_REVISION'] = commit('Broken fixture')
    try:
        run('bash', str(SEED), env=env)
        raise AssertionError('Missing POM was accepted')
    except subprocess.CalledProcessError:
        pass
    assert run('git', '--git-dir='+str(target), 'rev-parse', 'main') == before
print('PASS: initial, repeated, updated and invalid seeds; canonical advisory; student edits preserved')
