#!/usr/bin/env bash
# Learner helper: after you create org lw-student and empty repos in the Gitea UI,
# copy operator-prepared template content into your remotes (never clone GitHub).
#
# Usage (Showroom terminal):
#   oc -n gitea get configmap gitea-student-repo-seed \
#     -o jsonpath='{.data.student-seed-from-templates\.sh}' > /tmp/student-seed.sh
#   chmod +x /tmp/student-seed.sh
#   export STUDENT_USER=student STUDENT_PASS=...   # password from lab-gitea
#   /tmp/student-seed.sh
#
# Env (optional overrides; defaults read from lab-gitea when oc works):
#   GITEA_URL, STUDENT_USER, STUDENT_PASS, LEARNER_ORG, REPO_NAME, GITOPS_REPO_NAME
#   GITOPS_PROD_REPO_NAME, TEMPLATE_APP_URL, TEMPLATE_GITOPS_URL
#   TEMPLATE_PROD_GITOPS_URL, DEFAULT_BRANCH
set -euo pipefail

cm_get() {
  oc -n gitea get configmap lab-gitea -o jsonpath="$1" 2>/dev/null || true
}

: "${GITEA_URL:=$(cm_get '{.data.gitea_url}')}"
: "${STUDENT_USER:=student}"
: "${STUDENT_PASS:=$(cm_get '{.data.student_password}')}"
: "${LEARNER_ORG:=$(cm_get '{.data.student_gitea_org}')}"
: "${REPO_NAME:=$(cm_get '{.data.student_repo_name}')}"
: "${GITOPS_REPO_NAME:=$(cm_get '{.data.student_gitops_repo_name}')}"
: "${GITOPS_PROD_REPO_NAME:=$(cm_get '{.data.student_prod_gitops_repo_name}')}"
: "${TEMPLATE_APP_URL:=$(cm_get '{.data.template_app_repo_url}')}"
: "${TEMPLATE_GITOPS_URL:=$(cm_get '{.data.template_gitops_repo_url}')}"
: "${TEMPLATE_PROD_GITOPS_URL:=$(cm_get '{.data.template_prod_gitops_repo_url}')}"
: "${DEFAULT_BRANCH:=$(cm_get '{.data.student_repo_revision}')}"

: "${GITEA_URL:?Set GITEA_URL or ensure lab-gitea exists}"
: "${STUDENT_USER:?Set STUDENT_USER}"
: "${STUDENT_PASS:?Set STUDENT_PASS}"
: "${LEARNER_ORG:=lw-${STUDENT_USER}}"
: "${REPO_NAME:=spring-boot-lw-poc}"
: "${GITOPS_REPO_NAME:=gitops-spring-boot-lw-poc}"
: "${GITOPS_PROD_REPO_NAME:=gitops-prod-spring-boot-lw-poc}"
: "${DEFAULT_BRANCH:=main}"
: "${TEMPLATE_APP_URL:=${GITEA_URL%/}/workshop-templates/${REPO_NAME}.git}"
: "${TEMPLATE_GITOPS_URL:=${GITEA_URL%/}/workshop-templates/${GITOPS_REPO_NAME}.git}"
: "${TEMPLATE_PROD_GITOPS_URL:=${GITEA_URL%/}/workshop-templates/${GITOPS_PROD_REPO_NAME}.git}"
: "${GITEA_SCAFFOLDER_USER:=gitea-admin}"
: "${RENOVATE_BOT_USER:=$(cm_get '{.data.renovate_bot_username}')}"
: "${RENOVATE_BOT_USER:=renovate-bot}"

API="${GITEA_URL%/}/api/v1"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

auth_header() {
  printf 'Authorization: Basic %s' "$(printf '%s:%s' "$1" "$2" | base64 -w0 2>/dev/null || printf '%s:%s' "$1" "$2" | base64)"
}

ensure_scaffolder_on_org() {
  # RHDH publish:gitea uses workshop admin credentials; admin must be an org owner.
  local teams_code team_id code
  teams_code="$(curl -sk -o /tmp/gitea-learner-teams.json -w '%{http_code}' \
    -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
    "${API}/orgs/${LEARNER_ORG}/teams" || true)"
  if [[ "${teams_code}" != "200" ]]; then
    echo "WARN: cannot list teams for ${LEARNER_ORG} (HTTP ${teams_code}) — Module 3 publish may fail until gitea-admin is an org owner" >&2
    return 0
  fi
  team_id="$(python3 - <<'PY'
import json
teams = json.load(open("/tmp/gitea-learner-teams.json"))
for prefer in ("Owners", "owners"):
    for t in teams:
        if t.get("name") == prefer:
            print(t["id"])
            raise SystemExit
if teams:
    print(teams[0]["id"])
PY
)"
  if [[ -z "${team_id}" ]]; then
    echo "WARN: no teams on ${LEARNER_ORG}" >&2
    return 0
  fi
  code="$(curl -sk -o /tmp/gitea-scaffolder-member.json -w '%{http_code}' \
    -X PUT \
    -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
    "${API}/teams/${team_id}/members/${GITEA_SCAFFOLDER_USER}" || true)"
  if [[ "${code}" == "204" || "${code}" == "200" ]]; then
    echo "Added ${GITEA_SCAFFOLDER_USER} to ${LEARNER_ORG} (team ${team_id}) for Module 3 publish:gitea"
    return 0
  fi
  echo "WARN: add ${GITEA_SCAFFOLDER_USER} to team failed HTTP ${code}" >&2
  cat /tmp/gitea-scaffolder-member.json >&2 || true
}

add_repo_collaborator() {
  local owner="$1" repo="$2" user="$3"
  local code
  code="$(curl -sk -o /tmp/gitea-collab.json -w '%{http_code}' \
    -X PUT \
    -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
    -H 'Content-Type: application/json' \
    -d '{"permission":"write"}' \
    "${API}/repos/${owner}/${repo}/collaborators/${user}" || true)"
  if [[ "${code}" == "204" || "${code}" == "200" ]]; then
    echo "Added ${user} as write collaborator on ${owner}/${repo} (Track 3.3 Renovate)"
    return 0
  fi
  echo "WARN: add collaborator ${user} on ${owner}/${repo} failed HTTP ${code} — re-run after renovate-bot exists" >&2
  cat /tmp/gitea-collab.json >&2 || true
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
    # URL-encode is skipped for workshop usernames/passwords (alphanumeric).
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
echo "Stage GitOps:    ${LEARNER_ORG}/${GITOPS_REPO_NAME}"
echo "Prod GitOps:     ${LEARNER_ORG}/${GITOPS_PROD_REPO_NAME}"
echo "Template app:    ${TEMPLATE_APP_URL}"
echo "Template stage:  ${TEMPLATE_GITOPS_URL}"
echo "Template prod:   ${TEMPLATE_PROD_GITOPS_URL}"

# Org must already exist (created in Gitea UI per Module 2)
org_code="$(curl -sk -o /tmp/gitea-org-check.json -w '%{http_code}' \
  -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
  "${API}/orgs/${LEARNER_ORG}" || true)"
if [[ "${org_code}" != "200" ]]; then
  echo "ERROR: organization ${LEARNER_ORG} not found (HTTP ${org_code})." >&2
  echo "In Gitea: + → New Organization → name exactly ${LEARNER_ORG}, then re-run." >&2
  exit 1
fi

ensure_scaffolder_on_org

require_repo "${LEARNER_ORG}" "${REPO_NAME}"
mirror_push "${TEMPLATE_APP_URL}" "${LEARNER_ORG}" "${REPO_NAME}"
add_repo_collaborator "${LEARNER_ORG}" "${REPO_NAME}" "${RENOVATE_BOT_USER}"

if [[ -n "${GITOPS_REPO_NAME}" && -n "${TEMPLATE_GITOPS_URL}" ]]; then
  require_repo "${LEARNER_ORG}" "${GITOPS_REPO_NAME}"
  mirror_push "${TEMPLATE_GITOPS_URL}" "${LEARNER_ORG}" "${GITOPS_REPO_NAME}"
fi

if [[ -n "${GITOPS_PROD_REPO_NAME}" && -n "${TEMPLATE_PROD_GITOPS_URL}" ]]; then
  require_repo "${LEARNER_ORG}" "${GITOPS_PROD_REPO_NAME}"
  mirror_push "${TEMPLATE_PROD_GITOPS_URL}" "${LEARNER_ORG}" "${GITOPS_PROD_REPO_NAME}"
fi

echo "Done. App remote: ${GITEA_URL%/}/${LEARNER_ORG}/${REPO_NAME}.git"
echo "Confirm: oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_repo_url}{\"\\n\"}'"
