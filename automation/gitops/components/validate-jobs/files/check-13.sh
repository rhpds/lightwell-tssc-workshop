#!/usr/bin/env bash
# 5.2 — tightened Conforma copy in build ns; task after sign; not the seed.
set -euo pipefail
org="$(learner_org)"
repo="$(learner_app_repo)"
ns="$(build_ns)"
gitea_repo_ok "$org" "$repo"
skip="$(cm_get "$ns" conforma-policy skip-image-sig-check)"
[[ "$skip" == "false" ]] || fail "ConfigMap ${ns}/conforma-policy skip-image-sig-check must be false (copy and tighten; do not edit lightwell-tasks)."
skip_att="$(cm_get "$ns" conforma-policy skip-att-sig-check)"
[[ "$skip_att" == "true" ]] || fail "ConfigMap ${ns}/conforma-policy skip-att-sig-check must stay true (no Chains / no cosign attest on this claim)."
ident="$(cm_get "$ns" conforma-policy certificate-identity-regexp)"
[[ -n "$ident" ]] || fail "ConfigMap ${ns}/conforma-policy is missing certificate-identity-regexp."
[[ "$ident" != ".*" ]] || fail "certificate-identity-regexp is still '.*'. Use the pipeline SA identity."
deny_contains "${ns}/conforma-policy identity" "$ident" "example.invalid"
cve="$(cm_get "$ns" conforma-policy data.yaml)"
deny_contains "${ns}/conforma-policy data.yaml" "$cve" "restrict_max_cve_score: 999"
policy_yaml="$(cm_get "$ns" conforma-policy policy.yaml)"
deny_contains "${ns}/conforma-policy policy.yaml still excludes everything" "$policy_yaml" 'exclude:
            - "*"'
git_pl="$(gitea_raw "$org" "$repo" .tekton/pipeline.yaml)"
task_before "$git_pl" cosign-sign-keyless conforma-policy "${org}/${repo} .tekton/pipeline.yaml"
printf '%s\n' "$git_pl" | grep -A40 'name: conforma-policy' | grep -q 'name: tuf-url' \
  || fail "conforma-policy in git must pass tuf-url (in-cluster TUF after 4.3)."
printf '%s\n' "$git_pl" | grep -A40 'name: conforma-policy' | grep -q 'name: rekor-url' \
  || fail "conforma-policy in git must pass rekor-url (in-cluster Rekor after 4.3)."
live="$(pipeline_yaml "$ns" spring-boot-lw-poc-build-sign)"
task_before "$live" cosign-sign-keyless conforma-policy "Pipeline ${ns}/spring-boot-lw-poc-build-sign"
printf '%s\n' "$live" | grep -A3 'policy-namespace' | grep -q "$ns" \
  || fail "conforma-policy policy-namespace must be ${ns} (the tightened copy), not lightwell-tasks."
printf '%s\n' "$live" | grep -A40 'name: conforma-policy' | grep -q 'name: tuf-url' \
  || fail "live Pipeline conforma-policy must pass tuf-url (in-cluster TUF)."
printf '%s\n' "$live" | grep -A40 'name: conforma-policy' | grep -q 'name: rekor-url' \
  || fail "live Pipeline conforma-policy must pass rekor-url (in-cluster Rekor)."
report_require_token policy_owner learner-copy
pass "Conforma copy in ${ns} is tightened and runs after cosign-sign-keyless."
