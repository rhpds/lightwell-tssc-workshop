# fastapi-lw-poc (student lab repository)

Learner-owned **FastAPI / Python** application repository for the Lightwell TSSC
workshop (hosted on in-cluster **Gitea**).

Use this repository for Modules 7–9 (PyPI Validated → Remediated pin →
pipeline / GitOps). Discover your remote from ConfigMap `lab-gitea`
(`student_python_repo_url`).

## Layout

| Path | Purpose |
|------|---------|
| `requirements.txt` / `main.py` / `Dockerfile` | App sources at repository root |
| `pip.conf` / `pip-remediated.conf` | Lightwell Validated / Remediated PyPI indexes |
| `.tekton/` | Hybrid pipeline: python-dep-gate → BuildConfig → ACS → SBOM → cosign |
| `README.md` | This file |

## Clone path

```bash
# requirements.txt must be at repo root (not nested under app/)
cd /tmp/fastapi-lw-poc
```

## Module 9 — build / sign (claim)

```bash
# Discover your Gitea remote
STUDENT_PYTHON_REPO_URL="$(oc -n gitea get configmap lab-gitea \
  -o jsonpath='{.data.student_python_repo_url}')"

# Policy gate expects the Remediated marker pin (Module 8) in requirements.txt:
#   lw-workshop-pypi==1.0.0+rhlw.00001

oc apply -f .tekton/rbac.yaml -f .tekton/pipeline.yaml
sed "s|STUDENT_REPO_URL_PLACEHOLDER|${STUDENT_PYTHON_REPO_URL}|g" \
  .tekton/pipelinerun.yaml | oc create -f -
```

Also set `<lab-namespace>` and RHTAS Fulcio/Rekor/TUF URLs in the PipelineRun
(from `lab-rhtas` / cluster domain). Digest promote uses
`student_python_gitops_repo_url` — see the companion gitops remote `PROMOTE.md`.

Never clone GitHub for lab work — use the in-cluster Gitea remote.
