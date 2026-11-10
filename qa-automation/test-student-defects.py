#!/usr/bin/env python3
"""Regression checks for the claim's student acceptance failures."""
import sys
sys.dont_write_bytecode = True
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile
import yaml

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = ROOT / "automation/gitops/components"

def render(chart, *args):
    return [d for d in yaml.safe_load_all(subprocess.check_output(
        ["helm", "template", "test", str(chart), *args], text=True)) if d]

def named(docs, kind, name):
    return next(d for d in docs if d["kind"] == kind and d["metadata"]["name"] == name)

# The production assessment needs only image pull access, never namespace edit.
acs = render(COMPONENTS / "rhacs")
bindings = [d for d in acs if d["kind"] == "RoleBinding" and d["metadata"]["name"] == "rhacs-registry-puller-image-puller"]
assert {d["metadata"]["namespace"] for d in bindings} == {"lw-poc-build", "lw-poc-prod"}
assert all(d["roleRef"]["name"] == "system:image-puller" and d["subjects"] == [{"kind": "ServiceAccount", "name": "rhacs-registry-puller", "namespace": "stackrox"}] for d in bindings)
custom = render(COMPONENTS / "rhacs", "--set", "pipelineHooks.buildNamespace=custom-build", "--set", "pipelineHooks.registryIntegration.additionalNamespaces={custom-prod,custom-build}")
assert {d["metadata"]["namespace"] for d in custom if d["kind"] == "RoleBinding" and d["metadata"]["name"] == "rhacs-registry-puller-image-puller"} == {"custom-build", "custom-prod"}

# WFFC gets a consumer in the same wave, with no mirroring or PVC deletion.
nexus = render(COMPONENTS / "lightwell-repo")
job = named(nexus, "Job", "oc-mirror-workspace-bind")
pvc = named(nexus, "PersistentVolumeClaim", "oc-mirror-workspace")
assert job["metadata"]["annotations"]["argocd.argoproj.io/sync-wave"] == pvc["metadata"]["annotations"]["argocd.argoproj.io/sync-wave"]
assert job["spec"]["template"]["spec"]["containers"][0]["command"] == ["/bin/true"]
assert job["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] == pvc["metadata"]["name"]

# Catalog references resolve through mounted, explicitly allowed entity locations.
hub = render(COMPONENTS / "rhdh")
catalog = named(hub, "ConfigMap", "rhdh-software-templates")["data"]
entities = list(yaml.safe_load_all(catalog["workshop-entities.yaml"]))
assert {(e["kind"], e["metadata"]["name"]) for e in entities} == {("Group", "lightwell-workshop"), ("System", "lightwell-tssc-workshop")}
config = yaml.safe_load(named(hub, "ConfigMap", "app-config-rhdh")["data"]["app-config-rhdh.yaml"])
location = next(l for l in config["catalog"]["locations"] if l["target"].endswith("workshop-entities.yaml"))
assert location["rules"] == [{"allow": ["Group", "System"]}]

# Content pin tracks a resolved revision only for matching repo/ref configurations.
bootstrap = ROOT / "automation/gitops/bootstrap-infra"
app = named(render(bootstrap), "Application", "test-showroom")
assert app["spec"]["source"]["helm"]["parameters"][0]["value"] == "$ARGOCD_APP_REVISION"
app = named(render(bootstrap, "--set", "components.showroom.content.repoRef=independent"), "Application", "test-showroom")
assert "parameters" not in app["spec"]["source"]["helm"]

spec = importlib.util.spec_from_file_location("fixture", COMPONENTS / "lightwell-repo/files/seed/build-demo-jar.py")
fixture = importlib.util.module_from_spec(spec); spec.loader.exec_module(fixture)
with tempfile.TemporaryDirectory(prefix="student-defects-") as tmp:
    base = Path(tmp)
    original, output = base / "upstream.jar", base / "demo.jar"
    payload = {"example.class": b"unchanged bytecode", "META-INF/LICENSE.txt": b"license",
               fixture.MAVEN + "pom.properties": b"version=3.14.0", fixture.MAVEN + "pom.xml": b"upstream POM",
               "META-INF/MANIFEST.MF": b"Manifest-Version: 1.0\r\nImplementation-Version: 3.14.0\r\n\r\n"}
    with zipfile.ZipFile(original, "w") as jar:
        for name, data in payload.items(): jar.writestr(name, data)
    before = original.read_bytes()
    fixture.build(original, output, COMPONENTS / "lightwell-repo/files/seed/commons-lang3-3.14.0.rhlw-00001.pom")
    assert original.read_bytes() == before
    with zipfile.ZipFile(output) as jar:
        assert jar.read("example.class") == payload["example.class"]
        assert jar.read("META-INF/LICENSE.txt") == payload["META-INF/LICENSE.txt"]
        assert b"version=3.14.0.rhlw-00001" in jar.read(fixture.MAVEN + "pom.properties")
        assert b"not a Red Hat build" in jar.read("META-INF/lightwell-workshop-simulation.txt")
    with zipfile.ZipFile(original, "a") as jar: jar.writestr("META-INF/UPSTREAM.SF", "signature")
    try: fixture.build(original, base / "signed.jar", COMPONENTS / "lightwell-repo/files/seed/commons-lang3-3.14.0.rhlw-00001.pom")
    except ValueError: pass
    else: raise AssertionError("Modified signed upstream artifact")

    # Execute the rendered prefetch script: a misleading source pin must not pass
    # when Maven's effective graph resolves upstream. Stub only Maven/network IO.
    task = named(render(COMPONENTS / "pipelines"), "Task", "prefetch-dependencies")
    script = task["spec"]["steps"][0]["script"].replace("$(results.prefetch-status.path)", str(base / "status")).replace("$(workspaces.source.path)", str(base))
    (base / "run.sh").write_text(script)
    (base / "pom.xml").write_text("<commons.lang3.version>3.14.0.rhlw-00001</commons.lang3.version>")
    (base / "settings.xml").write_text("<mirrorOf>*</mirrorOf>http://nexus.lightwell-repo.svc/repository/lightwell</url>")
    binpath = base / "bin"; binpath.mkdir()
    mvn = binpath / "mvn"
    mvn.write_text("#!/usr/bin/env python3\nimport os,sys,pathlib\nfor a in sys.argv:\n if a.startswith('-DoutputFile='): pathlib.Path(a.split('=',1)[1]).write_text('org.apache.commons:commons-lang3:jar:'+os.environ['TEST_VERSION']+':compile\\n')\n if a.startswith('-Dmaven.repo.local='): p=pathlib.Path(a.split('=',1)[1]);p.mkdir(exist_ok=True);(p/'dep.jar').write_bytes(b'fixture')\n")
    mvn.chmod(0o755)
    import os
    env = dict(os.environ, PATH=str(binpath)+os.pathsep+os.environ["PATH"], POM_PATH="pom.xml", SETTINGS_PATH="settings.xml", PREFETCH_DIR="cache", MAVEN_PROFILE="", EXPECTED_COMMONS_LANG3_VERSION="3.14.0.rhlw-00001")
    for version, success in [("3.14.0", False), ("3.14.0.rhlw-00001", True)]:
        result = subprocess.run(["bash", "run.sh"], cwd=base, env=dict(env, TEST_VERSION=version), capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        assert (base / "status").exists(), result.stdout + result.stderr
        assert (base / "status").read_text() == ("passed" if success else "failed")
print("PASS: scoped ACS permissions, WFFC consumer, catalog entities, Showroom revision, honest fixture and effective dependency rejection")
