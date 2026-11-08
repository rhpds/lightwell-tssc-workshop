# Scaffolded by the Lightwell TSSC RHDH Software Template (Showroom Module 7+).
#
# Publishes to in-cluster Gitea as lw-student/fastapi-lw-poc
# (lab-gitea → student_python_repo_url). Never use GitHub as a learner
# remote; lab git is in-cluster Gitea.
#
# Layout at repo root (parity with Gitea seed for Modules 7–9):
#   requirements.txt, pip.conf, pip-remediated.conf, Dockerfile, main.py, .tekton/
# GitHub skeleton copy is requirements.txt.example; assemble-skeleton.sh renames to requirements.txt.

## Prerequisites

```bash
export LIGHTWELL_NEXUS_URL='https://nexus-lightwell-repo.apps.<domain>'
export LW_USERNAME='...'   # never commit
export LW_PASSWORD='...'
```

## Pip Validated (Module 7)

```bash
oc -n lightwell-repo extract configmap/lightwell-pip-settings --keys=pip.conf --to=.
# Or rewrite NEXUS_BASE / NEXUS_HOST in this repo's pip.conf
PIP_CONFIG_FILE=$PWD/pip.conf pip install -r requirements.txt
```

## Pip Remediated (Module 8 — always on)

```bash
oc -n lightwell-repo extract configmap/lightwell-pip-settings --keys=pip-remediated.conf --to=.
PIP_CONFIG_FILE=$PWD/pip-remediated.conf pip install lw-workshop-pypi==1.0.0+rhlw.00001
# Also add lw-workshop-pypi==1.0.0+rhlw.00001 to requirements.txt for Module 9 dep-gate
```

## Pipeline (Module 9)

```bash
STUDENT_PYTHON_REPO_URL="$(oc -n gitea get configmap lab-gitea \
  -o jsonpath='{.data.student_python_repo_url}')"

# Edit .tekton/pipelinerun.yaml: lab image-url + RHTAS Fulcio/Rekor/TUF URLs
oc apply -f .tekton/rbac.yaml -f .tekton/pipeline.yaml
sed "s|STUDENT_REPO_URL_PLACEHOLDER|${STUDENT_PYTHON_REPO_URL}|g" \
  .tekton/pipelinerun.yaml | oc create -f -
```

Digest promote: `student_python_gitops_repo_url` / `student_python_argocd_app`
(see companion gitops remote `PROMOTE.md`). Showroom Module 9 (#152) has the full lab.
