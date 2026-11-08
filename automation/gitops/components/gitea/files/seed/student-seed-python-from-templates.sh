#!/usr/bin/env bash
# Learner helper (Module 7): after you create empty FastAPI + gitops repos under lw-student,
# copy operator-prepared Python templates into your remotes (never clone GitHub).
#
# Usage (Showroom terminal):
#   oc -n gitea get configmap gitea-student-repo-seed \
#     -o jsonpath='{.data.student-seed-python-from-templates\.sh}' > /tmp/student-seed-python.sh
#   chmod +x /tmp/student-seed-python.sh
#   export STUDENT_USER=student STUDENT_PASS=...   # password from lab-gitea
#   /tmp/student-seed-python.sh
#
# Env (optional overrides; defaults read from lab-gitea when oc works):
#   GITEA_URL, STUDENT_USER, STUDENT_PASS, LEARNER_ORG
#   REPO_NAME, GITOPS_REPO_NAME (python names)
#   TEMPLATE_APP_URL, TEMPLATE_GITOPS_URL, DEFAULT_BRANCH
set -euo pipefail

cm_get() {
  oc -n gitea get configmap lab-gitea -o jsonpath="$1" 2>/dev/null || true
}

: "${GITEA_URL:=$(cm_get '{.data.gitea_url}')}"
: "${STUDENT_USER:=student}"
: "${STUDENT_PASS:=$(cm_get '{.data.student_password}')}"
: "${LEARNER_ORG:=$(cm_get '{.data.student_gitea_org}')}"
: "${REPO_NAME:=$(cm_get '{.data.student_python_repo_name}')}"
: "${GITOPS_REPO_NAME:=$(cm_get '{.data.student_python_gitops_repo_name}')}"
: "${TEMPLATE_APP_URL:=$(cm_get '{.data.template_python_app_repo_url}')}"
: "${TEMPLATE_GITOPS_URL:=$(cm_get '{.data.template_python_gitops_repo_url}')}"
: "${DEFAULT_BRANCH:=$(cm_get '{.data.student_repo_revision}')}"

: "${GITEA_URL:?Set GITEA_URL or ensure lab-gitea exists}"
: "${STUDENT_USER:?Set STUDENT_USER}"
: "${STUDENT_PASS:?Set STUDENT_PASS}"
: "${LEARNER_ORG:=lw-${STUDENT_USER}}"
: "${REPO_NAME:=fastapi-lw-poc}"
: "${GITOPS_REPO_NAME:=gitops-fastapi-lw-poc}"
: "${DEFAULT_BRANCH:=main}"
: "${TEMPLATE_APP_URL:=${GITEA_URL%/}/workshop-templates/${REPO_NAME}.git}"
: "${TEMPLATE_GITOPS_URL:=${GITEA_URL%/}/workshop-templates/${GITOPS_REPO_NAME}.git}"

API="${GITEA_URL%/}/api/v1"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

auth_header() {
  printf 'Authorization: Basic %s' "$(printf '%s:%s' "$1" "$2" | base64 -w0 2>/dev/null || printf '%s:%s' "$1" "$2" | base64)"
}

require_repo() {
  local owner="$1" repo="$2"
  local code
  code="$(curl -sk -o /tmp/gitea-repo-check.json -w '%{http_code}' \
    -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
    "${API}/repos/${owner}/${repo}" || true)"
  if [[ "${code}" != "200" ]]; then
    echo "ERROR: ${owner}/${repo} not found (HTTP ${code})." >&2
    echo "Create the empty repository in the Gitea UI under organization ${owner}, then re-run." >&2
    exit 1
  fi
}

mirror_push() {
  local template_url="$1" owner="$2" repo="$3"
  local dest="${WORKDIR}/${owner}-${repo}"
  rm -rf "${dest}"
  echo "Cloning template ${template_url} ..."
  # Full clone required: Gitea rejects "shallow update not allowed" from --depth 1 pushes.
  GIT_SSL_NO_VERIFY=true git -c http.sslVerify=false clone \
    "${template_url}" "${dest}"
  (
    cd "${dest}"
    git remote remove origin 2>/dev/null || true
    git remote add origin \
      "https://${STUDENT_USER}:${STUDENT_PASS}@${GITEA_URL#https://}/${owner}/${repo}.git"
    export GIT_TERMINAL_PROMPT=0
    if git -c http.sslVerify=false push -u --force origin "HEAD:${DEFAULT_BRANCH}"; then
      echo "Seeded ${owner}/${repo} from template"
      return 0
    fi
    echo "ERROR: push to ${owner}/${repo} failed" >&2
    exit 1
  )
}

echo "Learner org:     ${LEARNER_ORG}"
echo "App repo:        ${LEARNER_ORG}/${REPO_NAME}"
echo "GitOps repo:     ${LEARNER_ORG}/${GITOPS_REPO_NAME}"
echo "Template app:    ${TEMPLATE_APP_URL}"
echo "Template gitops: ${TEMPLATE_GITOPS_URL}"

org_code="$(curl -sk -o /tmp/gitea-org-check.json -w '%{http_code}' \
  -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
  "${API}/orgs/${LEARNER_ORG}" || true)"
if [[ "${org_code}" != "200" ]]; then
  echo "ERROR: organization ${LEARNER_ORG} not found (HTTP ${org_code})." >&2
  echo "In Gitea: + → New Organization → name exactly ${LEARNER_ORG} (Module 2), then create empty FastAPI repos and re-run." >&2
  exit 1
fi

require_repo "${LEARNER_ORG}" "${REPO_NAME}"
mirror_push "${TEMPLATE_APP_URL}" "${LEARNER_ORG}" "${REPO_NAME}"

if [[ -n "${GITOPS_REPO_NAME}" && -n "${TEMPLATE_GITOPS_URL}" ]]; then
  require_repo "${LEARNER_ORG}" "${GITOPS_REPO_NAME}"
  mirror_push "${TEMPLATE_GITOPS_URL}" "${LEARNER_ORG}" "${GITOPS_REPO_NAME}"
fi

echo "Done. App remote: ${GITEA_URL%/}/${LEARNER_ORG}/${REPO_NAME}.git"
echo "Confirm: oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_python_repo_url}{\"\\n\"}'"
