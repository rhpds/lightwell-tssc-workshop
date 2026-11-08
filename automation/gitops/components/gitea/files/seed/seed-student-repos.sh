#!/usr/bin/env bash
# Operator seed: admin + student *user*, plus prepared *template* remotes only.
# The learner creates org lw-student and repos in Showroom Module 2, then runs
# student-seed-from-templates.sh to copy template content into those remotes.
set -euo pipefail

: "${GITEA_URL:?}"
: "${GITEA_NAMESPACE:?}"
: "${GITEA_DEPLOYMENT:?}"
: "${ADMIN_USER:?}"
: "${ADMIN_PASSWORD:?}"
: "${ADMIN_EMAIL:?}"
: "${REPO_NAME:?}"
: "${REPO_DESCRIPTION:?}"
: "${DEFAULT_BRANCH:?}"
: "${STUDENT_USERNAME:?}"
: "${STUDENT_PASSWORD:?}"
: "${STUDENT_EMAIL:=${STUDENT_USERNAME}@workshop.local}"
: "${STUDENT_FULL_NAME:=Workshop Student}"
: "${SEED_DIR:=/seed}"
: "${TEMPLATES_ORG:=workshop-templates}"
: "${TEMPLATES_ORG_FULL_NAME:=Workshop Templates}"
: "${TEMPLATES_ORG_DESCRIPTION:=Operator-prepared Lightwell TSSC template remotes}"

GITOPS_REPO_NAME="${GITOPS_REPO_NAME:-}"
GITOPS_REPO_DESCRIPTION="${GITOPS_REPO_DESCRIPTION:-Lightwell TSSC student GitOps chart (Module 6 promote)}"
GITOPS_SEED_SUBDIR="${GITOPS_SEED_SUBDIR:-gitops-repo}"
GITOPS_PROD_REPO_NAME="${GITOPS_PROD_REPO_NAME:-}"
GITOPS_PROD_REPO_DESCRIPTION="${GITOPS_PROD_REPO_DESCRIPTION:-Lightwell TSSC student prod GitOps chart (Track 6.2)}"
GITOPS_PROD_SEED_SUBDIR="${GITOPS_PROD_SEED_SUBDIR:-gitops-prod-repo}"
SKELETON_REPO_NAME="${SKELETON_REPO_NAME:-}"
SKELETON_REPO_DESCRIPTION="${SKELETON_REPO_DESCRIPTION:-RHDH Software Template skeleton (Module 3)}"
SKELETON_SEED_SUBDIR="${SKELETON_SEED_SUBDIR:-skeleton}"

# Python track (#147) — optional; set when assemble produced python-repo / python-gitops-repo
PYTHON_REPO_NAME="${PYTHON_REPO_NAME:-}"
PYTHON_REPO_DESCRIPTION="${PYTHON_REPO_DESCRIPTION:-Lightwell TSSC student FastAPI lab repository (Modules 7–9)}"
PYTHON_SEED_SUBDIR="${PYTHON_SEED_SUBDIR:-python-repo}"
PYTHON_GITOPS_REPO_NAME="${PYTHON_GITOPS_REPO_NAME:-}"
PYTHON_GITOPS_REPO_DESCRIPTION="${PYTHON_GITOPS_REPO_DESCRIPTION:-Lightwell TSSC student FastAPI GitOps chart (Module 9)}"
PYTHON_GITOPS_SEED_SUBDIR="${PYTHON_GITOPS_SEED_SUBDIR:-python-gitops-repo}"

# RHDH Python skeleton (#148) — fetch:template source for lightwell-python-service
PYTHON_SKELETON_REPO_NAME="${PYTHON_SKELETON_REPO_NAME:-}"
PYTHON_SKELETON_REPO_DESCRIPTION="${PYTHON_SKELETON_REPO_DESCRIPTION:-RHDH Software Template skeleton (Module 7+)}"
PYTHON_SKELETON_SEED_SUBDIR="${PYTHON_SKELETON_SEED_SUBDIR:-skeleton-python}"

API="${GITEA_URL%/}/api/v1"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

echo "Waiting for Gitea at ${GITEA_URL} ..."
for i in $(seq 1 90); do
  if curl -fsS "${GITEA_URL%/}/api/healthz" >/dev/null 2>&1; then
    echo "Gitea is healthy."
    break
  fi
  if [[ "${i}" -eq 90 ]]; then
    echo "ERROR: Gitea did not become healthy in time" >&2
    exit 1
  fi
  sleep 5
done

POD="$(oc -n "${GITEA_NAMESPACE}" get pod -l "app=${GITEA_DEPLOYMENT}" \
  -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "${POD}" ]]; then
  echo "ERROR: no Gitea pod found in ${GITEA_NAMESPACE}" >&2
  exit 1
fi

auth_header() {
  printf 'Authorization: Basic %s' "$(printf '%s:%s' "$1" "$2" | base64 -w0 2>/dev/null || printf '%s:%s' "$1" "$2" | base64)"
}

admin_auth() {
  auth_header "${ADMIN_USER}" "${ADMIN_PASSWORD}"
}

gitea_cli() {
  local cmd
  printf -v cmd '%q ' "$@"
  oc -n "${GITEA_NAMESPACE}" exec "${POD}" -- \
    su git -s /bin/sh -c "gitea ${cmd}"
}

ensure_user() {
  local user="$1" pass="$2" email="$3" full_name="$4" admin_flag="$5"
  if [[ "${admin_flag}" == "true" ]]; then
    local out
    if out="$(gitea_cli admin user create --admin --username "${user}" --password "${pass}" --email "${email}" --must-change-password=false 2>&1)"; then
      echo "Created admin user ${user}"
      return 0
    fi
    if echo "${out}" | grep -qiE 'already exists|has been taken|duplicate'; then
      echo "Admin user ${user} already exists — continuing"
      return 0
    fi
    echo "ERROR: failed to create admin ${user}: ${out}" >&2
    exit 1
  fi

  local code
  code="$(curl -sS -o /tmp/gitea-user.json -w '%{http_code}' \
    -H "$(admin_auth)" \
    "${API}/admin/users/${user}" || true)"
  if [[ "${code}" == "200" ]]; then
    echo "User ${user} already exists"
    return 0
  fi
  local payload
  payload="$(python3 - <<PY
import json
print(json.dumps({
  "username": "${user}",
  "password": "${pass}",
  "email": "${email}",
  "full_name": "${full_name}",
  "must_change_password": False,
  "send_notify": False,
}))
PY
)"
  code="$(curl -sS -o /tmp/gitea-user-create.json -w '%{http_code}' \
    -X POST \
    -H "$(admin_auth)" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    "${API}/admin/users")"
  if [[ "${code}" == "201" ]]; then
    echo "Created user ${user}"
    return 0
  fi
  if [[ "${code}" == "422" ]] && grep -qiE 'already exists|user already exists' /tmp/gitea-user-create.json 2>/dev/null; then
    echo "User ${user} already exists — continuing"
    return 0
  fi
  echo "ERROR: create user ${user} failed HTTP ${code}" >&2
  cat /tmp/gitea-user-create.json >&2 || true
  exit 1
}

ensure_org() {
  local org="$1" full_name="$2" description="$3"
  local code
  code="$(curl -sS -o /tmp/gitea-org.json -w '%{http_code}' \
    -H "$(admin_auth)" \
    "${API}/orgs/${org}" || true)"
  if [[ "${code}" == "200" ]]; then
    echo "Org ${org} already exists"
    return 0
  fi
  local payload
  payload="$(python3 - <<PY
import json
print(json.dumps({
  "username": "${org}",
  "full_name": "${full_name}",
  "description": "${description}",
  "visibility": "public",
}))
PY
)"
  code="$(curl -sS -o /tmp/gitea-org-create.json -w '%{http_code}' \
    -X POST \
    -H "$(admin_auth)" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    "${API}/orgs")"
  if [[ "${code}" == "201" ]]; then
    echo "Created org ${org}"
    return 0
  fi
  if [[ "${code}" == "422" ]] && grep -qiE 'already exists|has been taken' /tmp/gitea-org-create.json 2>/dev/null; then
    echo "Org ${org} already exists — continuing"
    return 0
  fi
  echo "ERROR: create org ${org} failed HTTP ${code}" >&2
  cat /tmp/gitea-org-create.json >&2 || true
  exit 1
}

ensure_org_repo() {
  local org="$1" repo_name="$2" repo_desc="$3"
  local code
  code="$(curl -sS -o /tmp/gitea-repo.json -w '%{http_code}' \
    -H "$(admin_auth)" \
    "${API}/repos/${org}/${repo_name}" || true)"
  if [[ "${code}" == "200" ]]; then
    echo "Repo ${org}/${repo_name} already exists"
    return 0
  fi
  code="$(curl -sS -o /tmp/gitea-repo-create.json -w '%{http_code}' \
    -X POST \
    -H "$(admin_auth)" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"name":"%s","description":"%s","private":false,"auto_init":false,"default_branch":"%s"}' \
      "${repo_name}" "${repo_desc}" "${DEFAULT_BRANCH}")" \
    "${API}/orgs/${org}/repos")"
  if [[ "${code}" != "201" ]]; then
    echo "ERROR: create repo ${org}/${repo_name} failed HTTP ${code}" >&2
    cat /tmp/gitea-repo-create.json >&2 || true
    exit 1
  fi
  echo "Created repo ${org}/${repo_name}"
}

push_seed_tree() {
  local org="$1" repo_name="$2" seed_subdir="$3" commit_msg="$4"
  local src="${SEED_DIR}/${seed_subdir}"
  if [[ ! -d "${src}" ]]; then
    echo "ERROR: seed tree missing: ${src}" >&2
    exit 1
  fi
  local repo_dir="${WORKDIR}/${org}-${repo_name}"
  rm -rf "${repo_dir}"
  mkdir -p "${repo_dir}"
  cp -a "${src}/." "${repo_dir}/"
  (
    cd "${repo_dir}"
    git init -b "${DEFAULT_BRANCH}"
    git config user.email "${ADMIN_USER}@workshop.local"
    git config user.name "${ADMIN_USER}"
    git add .
    git commit -m "${commit_msg}"
    git remote add origin "https://${ADMIN_USER}:${ADMIN_PASSWORD}@${GITEA_URL#https://}/${org}/${repo_name}.git"
    export GIT_TERMINAL_PROMPT=0
    export GIT_SSL_NO_VERIFY="${GIT_SSL_NO_VERIFY:-true}"
    for i in $(seq 1 12); do
      if git -c http.sslVerify=false push -u --force origin "${DEFAULT_BRANCH}"; then
        echo "Pushed template to ${org}/${repo_name}"
        return 0
      fi
      sleep 5
    done
    echo "ERROR: git push failed for ${org}/${repo_name}" >&2
    exit 1
  )
}

ensure_user "${ADMIN_USER}" "${ADMIN_PASSWORD}" "${ADMIN_EMAIL}" "Gitea Admin" "true"

ensure_user "${STUDENT_USERNAME}" "${STUDENT_PASSWORD}" "${STUDENT_EMAIL}" "${STUDENT_FULL_NAME}" "false"
echo "Learner ${STUDENT_USERNAME} ready — org lw-${STUDENT_USERNAME} + repos are created by the student in Module 2"

# Prepared file systems from monorepo isolation → template remotes only
ensure_org "${TEMPLATES_ORG}" "${TEMPLATES_ORG_FULL_NAME}" "${TEMPLATES_ORG_DESCRIPTION}"
ensure_org_repo "${TEMPLATES_ORG}" "${REPO_NAME}" "${REPO_DESCRIPTION} (template)"
push_seed_tree "${TEMPLATES_ORG}" "${REPO_NAME}" "repo" \
  "Operator template: Lightwell app tree for learner seed (Modules 2–6)"
echo "TEMPLATE_APP_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${REPO_NAME}.git"

if [[ -n "${GITOPS_REPO_NAME}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${GITOPS_REPO_NAME}" "${GITOPS_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${GITOPS_REPO_NAME}" "${GITOPS_SEED_SUBDIR}" \
    "Operator template: Lightwell stage GitOps chart for learner seed (Track 6.1)"
  echo "TEMPLATE_GITOPS_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${GITOPS_REPO_NAME}.git"
fi

if [[ -n "${GITOPS_PROD_REPO_NAME}" && -d "${SEED_DIR}/${GITOPS_PROD_SEED_SUBDIR}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${GITOPS_PROD_REPO_NAME}" "${GITOPS_PROD_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${GITOPS_PROD_REPO_NAME}" "${GITOPS_PROD_SEED_SUBDIR}" \
    "Operator template: Lightwell prod GitOps chart (Track 6.2; digest seed is wrong)"
  echo "TEMPLATE_PROD_GITOPS_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${GITOPS_PROD_REPO_NAME}.git"
fi

if [[ -n "${SKELETON_REPO_NAME}" && -d "${SEED_DIR}/${SKELETON_SEED_SUBDIR}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${SKELETON_REPO_NAME}" "${SKELETON_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${SKELETON_REPO_NAME}" "${SKELETON_SEED_SUBDIR}" \
    "Operator template: RHDH lightwell-java-service skeleton (Module 3 fetch:template)"
  echo "TEMPLATE_SKELETON_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${SKELETON_REPO_NAME}.git"
fi

if [[ -n "${PYTHON_REPO_NAME}" && -d "${SEED_DIR}/${PYTHON_SEED_SUBDIR}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${PYTHON_REPO_NAME}" "${PYTHON_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${PYTHON_REPO_NAME}" "${PYTHON_SEED_SUBDIR}" \
    "Operator template: Lightwell FastAPI tree for learner seed (Modules 7–9)"
  echo "TEMPLATE_PYTHON_APP_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${PYTHON_REPO_NAME}.git"
fi

if [[ -n "${PYTHON_GITOPS_REPO_NAME}" && -d "${SEED_DIR}/${PYTHON_GITOPS_SEED_SUBDIR}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${PYTHON_GITOPS_REPO_NAME}" "${PYTHON_GITOPS_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${PYTHON_GITOPS_REPO_NAME}" "${PYTHON_GITOPS_SEED_SUBDIR}" \
    "Operator template: Lightwell FastAPI GitOps chart for learner seed (Module 9)"
  echo "TEMPLATE_PYTHON_GITOPS_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${PYTHON_GITOPS_REPO_NAME}.git"
fi

if [[ -n "${PYTHON_SKELETON_REPO_NAME}" && -d "${SEED_DIR}/${PYTHON_SKELETON_SEED_SUBDIR}" ]]; then
  ensure_org_repo "${TEMPLATES_ORG}" "${PYTHON_SKELETON_REPO_NAME}" "${PYTHON_SKELETON_REPO_DESCRIPTION} (template)"
  push_seed_tree "${TEMPLATES_ORG}" "${PYTHON_SKELETON_REPO_NAME}" "${PYTHON_SKELETON_SEED_SUBDIR}" \
    "Operator template: RHDH lightwell-python-service skeleton (Module 7+ fetch:template)"
  echo "TEMPLATE_PYTHON_SKELETON_URL=${GITEA_URL%/}/${TEMPLATES_ORG}/${PYTHON_SKELETON_REPO_NAME}.git"
fi

echo "gitea-student-repo-seed: complete (users + templates; learner orgs not created)"
