#!/usr/bin/env python3
"""Release rendering and preflight regressions, no live claim required."""
import copy
import importlib.util
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True
import yaml
ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "automation/gitops/bootstrap-infra"
REF = "lightwell-tssc-workshop-test"
SHA = "1" * 40

def render(*args):
    return subprocess.run(["helm", "template", "bootstrap", str(CHART), *args], text=True, capture_output=True)
assert render().returncode != 0
base = ("--set", "gitops.revision=" + REF, "--set", "components.gitea.enabled=true")
valid = render(*base)
assert valid.returncode == 0, valid.stderr
apps = [d for d in yaml.safe_load_all(valid.stdout) if d]
for override in ("components.showroom.content.repoRef=old-release", "components.showroom.content.repoUrl=https://example.invalid/other.git", "components.fastapiLwPoc.enabled=true", "components.springBootLwPoc.enabled=true"):
    assert render(*base, "--set", override).returncode != 0, override
repo = apps[0]["spec"]["source"]["repoURL"]
apps.insert(0, {"metadata": {"name": "bootstrap"}, "spec": {"source": {"repoURL": repo, "targetRevision": REF}}})
for app in apps:
    app["status"] = {"sync": {"revision": SHA, "status": "Synced"}, "health": {"status": "Healthy"}}
module_spec = importlib.util.spec_from_file_location("preflight", ROOT / "qa-automation/release-preflight.py")
preflight = importlib.util.module_from_spec(module_spec); module_spec.loader.exec_module(preflight)
def check(data, actual=SHA):
    return preflight.verify(data, "bootstrap", lambda repo, ref: SHA, lambda values: actual)[1]
assert not check(apps)
assert check(apps, "2" * 40)
for mutate in (lambda app: app["spec"]["source"].update(targetRevision="main"), lambda app: app["status"]["sync"].update(revision="2" * 40)):
    bad = copy.deepcopy(apps); mutate(bad[1]); assert check(bad)
bad = copy.deepcopy(apps)
showroom = next(a for a in bad if a["metadata"]["name"] == "bootstrap-showroom")
showroom["spec"]["source"]["helm"]["parameters"] = [{"name": "showroom.content.repoRef", "value": "$ARGOCD_APP_REVISION"}]
assert check(bad)
try:
    preflight.verify(apps, "bootstrap", lambda repo, ref: None, lambda values: SHA)
except ValueError:
    pass
else:
    raise AssertionError("Missing release tag accepted")
print("PASS: required release, inheritance, mismatch/legacy rejection, resolved revision and actual guide checks")

# Exercise the checkout probe against Git's ownership protection, not just a
# stubbed revision. The test-only Git flag simulates the shared-volume owner.
import os
import tempfile
from unittest.mock import patch
with tempfile.TemporaryDirectory() as directory:
    subprocess.run(["git", "init", "-q", directory], check=True)
    subprocess.run(["git", "-C", directory, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "fixture"], check=True)
    expected = subprocess.check_output(["git", "-C", directory, "rev-parse", "HEAD"], text=True).strip()
    env = dict(os.environ, GIT_TEST_ASSUME_DIFFERENT_OWNER="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    rejected = subprocess.run(["git", "-C", directory, "rev-parse", "HEAD"], env=env, text=True, capture_output=True)
    assert rejected.returncode != 0 and "dubious ownership" in rejected.stderr
    def execute_probe(*args):
        assert args[:9] == ("oc", "-n", "showroom", "exec", "deploy/showroom", "-c", "content", "--", "git")
        command = [arg.replace("/showroom/repo", directory) for arg in args[8:]]
        return subprocess.check_output(command, env=env, text=True).strip()
    with patch.object(preflight, "run", side_effect=execute_probe):
        assert preflight.showroom_revision({"namespace": "showroom", "name": "showroom"}) == expected
print("PASS: shared checkout probe uses command-scoped Git trust")
