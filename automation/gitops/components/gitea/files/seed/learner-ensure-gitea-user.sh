#!/usr/bin/env bash
# Learner helper: discover Gitea URL/credentials and ensure the workshop user exists.
# Provisioning Job gitea-student-repo-seed normally creates user `student` from values.student.
# If login fails, this script creates/updates the account via Secret gitea-admin.
#
# Usage (Showroom terminal):
#   oc -n gitea get configmap gitea-student-repo-seed \
#     -o jsonpath='{.data.learner-ensure-gitea-user\.sh}' > /tmp/learner-ensure-gitea-user.sh
#   chmod +x /tmp/learner-ensure-gitea-user.sh
#   export STUDENT_USER=student   # optional; this is the default
#   /tmp/learner-ensure-gitea-user.sh
#
# Env (optional):
#   GITEA_URL, STUDENT_USER, STUDENT_PASS, STUDENT_EMAIL, STUDENT_FULL_NAME
#   GITEA_ADMIN_USER, GITEA_ADMIN_PASS  (default: Secret gitea/gitea-admin)
set -euo pipefail

cm_get() {
  oc -n gitea get configmap demo-userinfo-gitea -o jsonpath="$1" 2>/dev/null || true
}

b64decode() {
  # GNU coreutils: -d ; macOS: -D / --decode
  base64 --decode 2>/dev/null || base64 -d 2>/dev/null || base64 -D 2>/dev/null
}

secret_get() {
  oc -n gitea get secret gitea-admin -o jsonpath="$1" 2>/dev/null | b64decode || true
}

: "${GITEA_URL:=$(cm_get '{.data.gitea_url}')}"
: "${STUDENT_USER:=student}"
: "${STUDENT_PASS:=$(cm_get '{.data.student_password}')}"
: "${STUDENT_EMAIL:=${STUDENT_USER}@workshop.local}"
: "${STUDENT_FULL_NAME:=Workshop User ${STUDENT_USER}}"
: "${GITEA_ADMIN_USER:=$(secret_get '{.data.username}')}"
: "${GITEA_ADMIN_PASS:=$(secret_get '{.data.password}')}"

: "${GITEA_URL:?Set GITEA_URL or ensure ConfigMap demo-userinfo-gitea exists in ns gitea}"
: "${STUDENT_USER:?Set STUDENT_USER}"
: "${STUDENT_PASS:?Set STUDENT_PASS (demo-userinfo-gitea → student_password)}"
: "${GITEA_ADMIN_USER:?Cannot read admin username from Secret gitea/gitea-admin}"
: "${GITEA_ADMIN_PASS:?Cannot read admin password from Secret gitea/gitea-admin}"

API="${GITEA_URL%/}/api/v1"

b64() {
  printf '%s:%s' "$1" "$2" | base64 -w0 2>/dev/null || printf '%s:%s' "$1" "$2" | base64
}

auth_header() {
  printf 'Authorization: Basic %s' "$(b64 "$1" "$2")"
}

echo "Gitea URL:     ${GITEA_URL}"
echo "Student user:  ${STUDENT_USER}"

# Fast path: credentials already work
login_code="$(curl -sk -o /tmp/gitea-user-me.json -w '%{http_code}' \
  -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
  "${API}/user" || true)"
if [[ "${login_code}" == "200" ]]; then
  echo "OK: ${STUDENT_USER} can already sign in."
  echo "Open: ${GITEA_URL}"
  echo "Sign in as: ${STUDENT_USER}  (password: value of demo-userinfo-gitea key student_password)"
  exit 0
fi

echo "Login as ${STUDENT_USER} failed (HTTP ${login_code}) — ensuring account via gitea-admin…"

exists_code="$(curl -sk -o /tmp/gitea-user-get.json -w '%{http_code}' \
  -H "$(auth_header "${GITEA_ADMIN_USER}" "${GITEA_ADMIN_PASS}")" \
  "${API}/users/${STUDENT_USER}" || true)"

if [[ "${exists_code}" == "200" ]]; then
  # User exists but password may not match ConfigMap — reset via admin API
  payload="$(python3 - <<PY
import json
print(json.dumps({
  "login_name": "${STUDENT_USER}",
  "password": "${STUDENT_PASS}",
  "email": "${STUDENT_EMAIL}",
  "full_name": "${STUDENT_FULL_NAME}",
  "must_change_password": False,
}))
PY
)"
  code="$(curl -sk -o /tmp/gitea-user-patch.json -w '%{http_code}' \
    -X PATCH \
    -H "$(auth_header "${GITEA_ADMIN_USER}" "${GITEA_ADMIN_PASS}")" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    "${API}/admin/users/${STUDENT_USER}")"
  if [[ "${code}" != "200" ]]; then
    echo "ERROR: failed to update ${STUDENT_USER} HTTP ${code}" >&2
    cat /tmp/gitea-user-patch.json >&2 || true
    exit 1
  fi
  echo "Updated password for existing user ${STUDENT_USER}"
else
  payload="$(python3 - <<PY
import json
print(json.dumps({
  "username": "${STUDENT_USER}",
  "password": "${STUDENT_PASS}",
  "email": "${STUDENT_EMAIL}",
  "full_name": "${STUDENT_FULL_NAME}",
  "must_change_password": False,
  "send_notify": False,
}))
PY
)"
  code="$(curl -sk -o /tmp/gitea-user-create.json -w '%{http_code}' \
    -X POST \
    -H "$(auth_header "${GITEA_ADMIN_USER}" "${GITEA_ADMIN_PASS}")" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    "${API}/admin/users")"
  if [[ "${code}" == "201" ]]; then
    echo "Created user ${STUDENT_USER}"
  elif [[ "${code}" == "422" ]] && grep -qiE 'already exists|user already exists' /tmp/gitea-user-create.json 2>/dev/null; then
    echo "User ${STUDENT_USER} already exists — continuing"
  else
    echo "ERROR: create user ${STUDENT_USER} failed HTTP ${code}" >&2
    cat /tmp/gitea-user-create.json >&2 || true
    exit 1
  fi
fi

login_code="$(curl -sk -o /tmp/gitea-user-me.json -w '%{http_code}' \
  -H "$(auth_header "${STUDENT_USER}" "${STUDENT_PASS}")" \
  "${API}/user" || true)"
if [[ "${login_code}" != "200" ]]; then
  echo "ERROR: ${STUDENT_USER} still cannot sign in (HTTP ${login_code})" >&2
  exit 1
fi

echo "OK: ${STUDENT_USER} is ready."
echo "Open: ${GITEA_URL}"
echo "Sign in as: ${STUDENT_USER}  (password: value of demo-userinfo-gitea key student_password)"
