#!/usr/bin/env bash
# Shared Validate Job helper. Teaching fails only. No Solve.
# Live cluster/git state plus per-module report tokens (V2-59).

set -euo pipefail

VALIDATE_NS="${VALIDATE_NS:-lw-poc-validate}"
GITEA_NS="${GITEA_NS:-gitea}"
REPO_NS="${REPO_NS:-lightwell-repo}"
GITEA_LAB_CONFIG="${GITEA_LAB_CONFIG:-lab-gitea}"
REPO_LAB_CONFIG="${REPO_LAB_CONFIG:-lab-lightwell-repo}"
GITEA_INCLUSTER="${GITEA_INCLUSTER:-http://gitea.gitea.svc:3000}"

fail() {
  echo "CHECK FAILED: $*" >&2
  echo "Honor system: fix the named object, then re-run this Job (delete + create from validate-job-templates). There is no Solve." >&2
  exit 1
}

pass() {
  echo "CHECK PASSED: $*"
  exit 0
}

not_implemented() {
  fail "$* This Check is not implemented."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command '$1' in the Validate Job image."
}

cm_get() {
  local ns="$1" name="$2" key="$3" value
  # #59: jsonpath {.data['dotted.key']} is empty on oc; go-template index works.
  value="$(oc -n "$ns" get configmap "$name" \
    -o go-template="{{ index .data \"${key}\" }}" 2>/dev/null || true)"
  case "$value" in
    '<no value>') printf '' ;;
    *) printf '%s' "$value" ;;
  esac
}

lab_config() {
  local ns="$1" name="$2" key="$3"
  local value
  value="$(cm_get "$ns" "$name" "$key")"
  [[ -n "$value" ]] || fail "ConfigMap ${ns}/${name} is missing key '${key}'."
  printf '%s' "$value"
}

report_name() {
  echo "${REPORT_NAME:?REPORT_NAME is not set}"
}

report_get() {
  local key="$1"
  cm_get "$VALIDATE_NS" "$(report_name)" "$key"
}

report_require_key() {
  local key="$1"
  local value
  value="$(report_get "$key")"
  [[ -n "$value" ]] || fail "Report $(report_name) is missing key '${key}'. oc -n ${VALIDATE_NS} edit configmap $(report_name)"
  case "$value" in
    REPLACE_ME*) fail "Report $(report_name) key '${key}' is still a placeholder. Replace REPLACE_ME; do not copy validate-docs." ;;
  esac
}

normalize_token() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]_' '-' | sed 's/^-//;s/-$//'
}

report_require_token() {
  local key="$1"
  shift
  report_require_key "$key"
  local value norm tok t
  value="$(report_get "$key")"
  norm="$(normalize_token "$value")"
  for tok in "$@"; do
    t="$(normalize_token "$tok")"
    [[ "$norm" == "$t" ]] && return 0
  done
  fail "Report $(report_name) key '${key}' is '${value}'. Allowed token(s): $*"
}

module_begin() {
  require_cmd oc
  require_cmd curl
  echo "=== Validate Job ${MODULE_ID:-?} — ${MODULE_TITLE:-unknown} ==="
  oc -n "$VALIDATE_NS" get configmap "$(report_name)" >/dev/null \
    || fail "Report ConfigMap $(report_name) is missing in ${VALIDATE_NS}."
}

deny_placeholder() {
  local label="$1" body="$2"
  case "$body" in
    *REPLACE_ME*) fail "${label} still contains REPLACE_ME. Fill the scored object; do not copy validate-docs." ;;
  esac
}

require_contains() {
  local label="$1" body="$2" needle="$3"
  [[ "$body" == *"$needle"* ]] || fail "${label} does not contain '${needle}'."
}

deny_contains() {
  local label="$1" body="$2" needle="$3"
  [[ "$body" != *"$needle"* ]] || fail "${label} still contains '${needle}'."
}

gitea_base() {
  if curl -fsS --max-time 5 "${GITEA_INCLUSTER}/api/healthz" >/dev/null 2>&1; then
    printf '%s' "$GITEA_INCLUSTER"
    return
  fi
  local url
  url="$(lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" gitea_url)"
  printf '%s' "${url%/}"
}

gitea_raw() {
  local org="$1" repo="$2" path="$3"
  local branch="${4:-main}"
  local base url body code tmp
  base="$(gitea_base)"
  url="${base}/api/v1/repos/${org}/${repo}/raw/${path}?ref=${branch}"
  tmp="$(mktemp)"
  code="$(curl -skS --max-time 20 -o "$tmp" -w '%{http_code}' "$url" || true)"
  if [[ "$code" != "200" ]]; then
    rm -f "$tmp"
    fail "Cannot read ${org}/${repo} ${path} on ${branch} (HTTP ${code}). Create the lw-student remote and commit the scored file."
  fi
  cat "$tmp"
  rm -f "$tmp"
}

gitea_repo_ok() {
  local org="$1" repo="$2"
  local base code
  base="$(gitea_base)"
  code="$(curl -skS --max-time 15 -o /dev/null -w '%{http_code}' \
    "${base}/api/v1/repos/${org}/${repo}" || true)"
  [[ "$code" == "200" ]] || fail "Gitea repo ${org}/${repo} is not reachable (HTTP ${code}). Seed lw-student from templates (3.1)."
}

learner_org() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_gitea_org
}

learner_app_repo() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_repo_name
}

learner_gitops_repo() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_gitops_repo_name
}

learner_prod_gitops_repo() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_prod_gitops_repo_name
}

build_ns() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_build_namespace
}

stage_ns() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_promote_namespace
}

prod_ns() {
  lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_prod_namespace
}

job_succeeded() {
  local ns="$1" name="$2"
  local ok
  ok="$(oc -n "$ns" get job "$name" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
  [[ "$ok" == "1" ]] || fail "Job ${ns}/${name} has not Completed. Start it and wait until it succeeds."
}

taskrun_succeeded() {
  local ns="$1" task="$2"
  local statuses
  statuses="$(oc -n "$ns" get taskrun -l "tekton.dev/pipelineTask=${task}" \
    -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Succeeded")].status}{"\n"}{end}' 2>/dev/null || true)"
  [[ "$statuses" == *True* ]] || fail "No Succeeded TaskRun for pipelineTask=${task} in ${ns}."
}

# Newest TaskRun result for a pipeline task. Tekton v1 stores values on
# .status.results; some clusters still expose .status.taskResults. Sorted by
# creationTimestamp so a later passed/failed run wins over an earlier skip.
taskrun_latest_result() {
  local ns="$1" task="$2" name="$3"
  oc -n "$ns" get taskrun -l "tekton.dev/pipelineTask=${task}" \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath="{range .items[*]}{.status.results[?(@.name==\"${name}\")].value}{.status.taskResults[?(@.name==\"${name}\")].value}{\"\\n\"}{end}" \
    2>/dev/null || true
}

pipeline_yaml() {
  local ns="$1" name="$2"
  oc -n "$ns" get pipeline "$name" -o yaml 2>/dev/null \
    || fail "Pipeline ${ns}/${name} is missing. Apply .tekton/pipeline.yaml from the learner app remote."
}

task_before() {
  local yaml="$1" first="$2" second="$3" label="$4"
  local a b
  a="$(printf '%s\n' "$yaml" | grep -n "name: ${first}" | head -1 | cut -d: -f1 || true)"
  b="$(printf '%s\n' "$yaml" | grep -n "name: ${second}" | head -1 | cut -d: -f1 || true)"
  [[ -n "$a" ]] || fail "${label} is missing task '${first}'."
  [[ -n "$b" ]] || fail "${label} is missing task '${second}'."
  [[ "$a" -lt "$b" ]] || fail "${label}: '${first}' must run before '${second}'."
}
