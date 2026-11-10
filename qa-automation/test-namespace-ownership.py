#!/usr/bin/env python3
"""Render bootstrap and its effective child values to check namespace ownership."""
from pathlib import Path
import subprocess
import tempfile
import yaml
ROOT = Path(__file__).resolve().parents[1] / "automation/gitops"
def render(path, *args):
    return [d for d in yaml.safe_load_all(subprocess.check_output(["helm", "template", "test", str(path), *args], text=True)) if d]
for network, admission in [(True, True), (True, False), (False, True)]:
    apps = render(ROOT / "bootstrap-infra", "--set", f"components.networkPolicy.enabled={str(network).lower()},components.admission.enabled={str(admission).lower()}")
    owners = []
    for app in apps:
        path = app["spec"]["source"]["path"]
        if path.split("/")[-1] not in ("networkpolicy", "admission"):
            continue
        values = app["spec"]["source"]["helm"]["valuesObject"]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as f:
            yaml.safe_dump(values, f); f.flush()
            docs = render(ROOT.parent.parent / path, "-f", f.name)
        for doc in docs:
            if doc["kind"] == "Namespace" and doc["metadata"]["name"] == "lw-poc-prod":
                owners.append(app["metadata"]["name"])
                assert doc["metadata"]["annotations"]["argocd.argoproj.io/sync-options"] == "Prune=false,Delete=false"
    assert owners == ["test-networkpolicy" if network else "test-admission"], owners
print("PASS: exactly one protected production namespace owner in standard and standalone configurations")
