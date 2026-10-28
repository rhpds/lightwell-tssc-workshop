#!/usr/bin/env bash
# 6.2 — prod GitOps remote has the signed digest; Argo still sources the prod repo.
set -euo pipefail
org="$(learner_org)"
prod_repo="$(learner_prod_gitops_repo)"
argo="$(lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" student_prod_argocd_app)"
gitea_repo_ok "$org" "$prod_repo"
values="$(gitea_raw "$org" "$prod_repo" values.yaml)"
deny_contains "${org}/${prod_repo} values.yaml" "$values" "REPLACE_ME_PROD_DIGEST"
require_contains "${org}/${prod_repo} values.yaml" "$values" "sha256:"
require_contains "${org}/${prod_repo} values.yaml" "$values" "replicas: 1"
repo_url="$(oc -n openshift-gitops get applications.argoproj.io "$argo" \
  -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)"
[[ -n "$repo_url" ]] || fail "Application ${argo} is missing in openshift-gitops."
case "$repo_url" in
  *gitops-prod-spring-boot-lw-poc*) ;;
  *) fail "Application ${argo} repoURL is '${repo_url}' — it must keep the prod remote, not stage." ;;
esac
require_contains "${argo} repoURL" "$repo_url" "gitops-prod-"
health="$(oc -n openshift-gitops get applications.argoproj.io "$argo" \
  -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
[[ "$health" == "Healthy" ]] || fail "Application ${argo} health is '${health:-missing}', not Healthy."
prod="$(prod_ns)"
replicas="$(oc -n "$prod" get deploy spring-boot-lw-poc -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
[[ "$replicas" == "1" ]] || fail "Deployment ${prod}/spring-boot-lw-poc replicas is '${replicas:-missing}', not 1. Hard-refresh Argo after pushing the prod remote."
policy="$(lab_config tssc-admission lab-admission policy_name)"
oc -n "$prod" get imagepolicy.config.openshift.io "$policy" >/dev/null 2>&1 \
  || fail "ImagePolicy ${prod}/${policy} from 6.1 is missing."
report_require_token how_promote prod-remote
pass "lw-poc-prod sources the prod remote, the seed digest is gone, and unsigned deny is still live."
