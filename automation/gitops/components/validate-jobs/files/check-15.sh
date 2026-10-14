#!/usr/bin/env bash
# 6.1 — TrustPolicy filled+enforce; ImagePolicy live on stage and prod;
# MachineConfigPools finished applying it; the Ready pod was created after
# that ImagePolicy. A cached pull from before the node enforced the policy
# stays in CreateContainerError and does not pass.
set -euo pipefail
org="$(learner_org)"
gitops="$(learner_gitops_repo)"
stage="$(stage_ns)"
prod="$(prod_ns)"
argo="$(userinfo "$GITEA_NS" "$GITEA_USERINFO" student_argocd_app)"
policy="$(userinfo tssc-admission demo-userinfo-admission policy_name)"
gitea_repo_ok "$org" "$gitops"
tp="$(gitea_raw "$org" "$gitops" admission/trust-policy.yaml)"
deny_placeholder "${org}/${gitops} admission/trust-policy.yaml" "$tp"
require_contains "${org}/${gitops} TrustPolicy" "$tp" "enforce: true"
deny_contains "${org}/${gitops} TrustPolicy" "$tp" "enforce: false"
deny_contains "${org}/${gitops} TrustPolicy" "$tp" "example.invalid"
oc -n "$stage" get imagepolicy.config.openshift.io "$policy" >/dev/null 2>&1 \
  || fail "ImagePolicy ${stage}/${policy} is missing. Wait for CronJob trust-policy-apply."
oc -n "$prod" get imagepolicy.config.openshift.io "$policy" >/dev/null 2>&1 \
  || fail "ImagePolicy ${prod}/${policy} is missing. Wait for CronJob trust-policy-apply."
policy_ts="$(oc -n "$stage" get imagepolicy.config.openshift.io "$policy" \
  -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)"
[[ -n "$policy_ts" ]] || fail "ImagePolicy ${stage}/${policy} has no creationTimestamp."
# ImagePolicy is enforced only after MCO writes CRI-O policy onto the nodes.
updating="$(oc get machineconfigpool -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Updating")].status}{"\n"}{end}' 2>/dev/null || true)"
if [[ "$updating" == *True* ]]; then
  fail "ImagePolicy ${policy} exists, and a MachineConfigPool is still Updating (${updating//$'\n'/ }). Wait until oc get mcp shows UPDATING False on master and worker, then set replicas: 1. A pod started while the pool is updating stores the image before the node checks the signature."
fi
replicas="$(oc -n "$stage" get deploy spring-boot-lw-poc -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
[[ "$replicas" == "1" ]] || fail "Deployment ${stage}/spring-boot-lw-poc replicas is '${replicas:-missing}', not 1. Push digest + replicas: 1 and hard-refresh Argo (Healthy at 0 replicas is the seed)."
# Newest pod. A Ready pod created before ImagePolicy was admitted while the gate was off.
pod_names="$(oc -n "$stage" get pods -l app=spring-boot-lw-poc \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"
pod_name="$(printf '%s\n' "$pod_names" | awk 'NF { last=$0 } END { print last }')"
[[ -n "$pod_name" ]] || fail "No pod with label app=spring-boot-lw-poc in ${stage}. Push replicas: 1, hard-refresh Argo, then restart the Deployment after ImagePolicy exists."
pod_ts="$(oc -n "$stage" get pod "$pod_name" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)"
[[ -n "$pod_ts" ]] || fail "Pod ${stage}/${pod_name} has no creationTimestamp."
# API timestamps are RFC3339 UTC, so lexicographic order is time order.
if [[ ! "$pod_ts" > "$policy_ts" ]]; then
  fail "Pod ${stage}/${pod_name} was created at ${pod_ts}. ImagePolicy ${stage}/${policy} was created at ${policy_ts}. That pod started before the policy object existed. Keep replicas at 0 until oc get mcp is finished, then set replicas: 1 so the first pull happens with the policy on the node."
fi
phase="$(oc -n "$stage" get pod "$pod_name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
ready="$(oc -n "$stage" get pod "$pod_name" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)"
reason="$(oc -n "$stage" get pod "$pod_name" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
if [[ "$phase" != "Running" || "$ready" != "true" ]]; then
  fail "Pod ${stage}/${pod_name} was created at ${pod_ts}, after ImagePolicy ${policy_ts}, and is phase=${phase:-unknown} ready=${ready:-false} reason=${reason:-none}. If the event is 'already present on machine' and 'no signature exists', this node stored the image before it enforced the policy. Waiting does not start that container. The first pull has to happen after oc get mcp shows UPDATING False."
fi
health="$(oc -n openshift-gitops get applications.argoproj.io "$argo" \
  -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
[[ "$health" == "Healthy" ]] || fail "Application ${argo} health is '${health:-missing}', not Healthy. Pod ${pod_name} is Ready and was created after ImagePolicy. Wait until the Application is Healthy, then re-run this Check."
report_require_token live_api imagepolicy image-policy
pass "TrustPolicy is enforced, ImagePolicy is live on stage and prod, ${pod_name} started after the policy, and ${argo} is Healthy."
