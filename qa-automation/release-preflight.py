#!/usr/bin/env python3
"""Read-only catalog readiness: report and reject mixed workshop revisions."""
import argparse
import json
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def verify(apps, bootstrap, resolve_tag, showroom_revision):
    errors = []
    report = []
    parent = next((a for a in apps if a["metadata"]["name"] == bootstrap), None)
    if not parent:
        raise ValueError("Bootstrap Application not found")
    source = parent["spec"]["source"]
    repo, ref = source["repoURL"], source["targetRevision"]
    sha = resolve_tag(repo, ref)
    if not sha:
        raise ValueError("Bootstrap target must resolve to a published release tag")
    report.append({"application": bootstrap, "ref": ref, "resolved": parent.get("status", {}).get("sync", {}).get("revision"), "expected": sha})
    selected = [a for a in apps if a["metadata"]["name"].startswith(bootstrap + "-")]
    if not selected:
        errors.append("No child Applications found")
    seen = set()
    for app in [parent] + selected:
        name = app["metadata"]["name"]
        src = app["spec"]["source"]
        status = app.get("status", {})
        sync = status.get("sync", {})
        if src.get("repoURL") != repo or src.get("targetRevision") != ref or sync.get("revision") != sha:
            errors.append(name + ": requested or resolved release differs")
        if sync.get("status") != "Synced" or status.get("health", {}).get("status") != "Healthy":
            errors.append(name + ": not Synced and Healthy")
        if app is parent:
            continue
        report.append({"application": name, "ref": src.get("targetRevision"), "resolved": sync.get("revision")})
        chart = src.get("path", "").split("/")[-1]
        seen.add(chart)
        if chart in ("spring-boot-lw-poc", "fastapi-lw-poc"):
            errors.append(name + ": legacy application enabled")
        helm = src.get("helm", {})
        values = helm.get("valuesObject", {})
        if chart == "showroom":
            content = values.get("showroom", {}).get("content", {})
            if content.get("repoUrl") != repo or content.get("repoRef") != ref:
                errors.append(name + ": guide values differ")
            if any(p.get("name") in ("showroom.content.repoRef", "showroom.content.repoUrl") and p.get("value") != (ref if p["name"].endswith("repoRef") else repo) for p in helm.get("parameters", [])):
                errors.append(name + ": guide parameter override differs")
            actual = showroom_revision(values["showroom"])
            report.append({"showroom_checkout": actual})
            if actual != sha:
                errors.append(name + ": actual guide checkout differs")
        if chart == "gitea":
            seed = values.get("seed", {}).get("source", {})
            if seed.get("repoUrl") != repo or seed.get("revision") != ref:
                errors.append(name + ": starter import source differs")
            if any(p.get("name", "").startswith("seed.source.") for p in helm.get("parameters", [])):
                errors.append(name + ": unexpected starter import override")
    if not {"showroom", "gitea"}.issubset(seen):
        errors.append("Required Showroom or Gitea child missing")
    return report, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bootstrap", default="bootstrap")
    parser.add_argument("--namespace", default="openshift-gitops")
    args = parser.parse_args()
    def resolve_tag(repo, ref):
        if ref.startswith("-") or any(c.isspace() for c in ref):
            raise ValueError("Invalid release tag")
        tag = ref if ref.startswith("refs/tags/") else "refs/tags/" + ref
        refs = dict(line.split()[::-1] for line in run("git", "ls-remote", "--tags", "--", repo, tag, tag + "^{}").splitlines())
        return refs.get(tag + "^{}", refs.get(tag))
    def showroom_revision(values):
        # git-cloner uses a single-branch checkout; report the actual mounted source.
        return run("oc", "-n", values["namespace"], "exec", "deploy/" + values["name"], "-c", "content", "--", "git", "-C", "/showroom/repo", "rev-parse", "HEAD")
    try:
        apps = json.loads(run("oc", "-n", args.namespace, "get", "applications.argoproj.io", "-o", "json"))["items"]
        report, errors = verify(apps, args.bootstrap, resolve_tag, showroom_revision)
        print(json.dumps({"revisions": report, "errors": errors}, indent=2))
        return bool(errors)
    except (ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print("Release preflight failed: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
