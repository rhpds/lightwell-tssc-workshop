#!/usr/bin/env bash
# Track 1: independently verify the destination, not a Job name or a .sig tag.
set -euo pipefail
cosign_bin=/opt/cosign/cosign
[[ -x "$cosign_bin" ]] || fail "Cosign is missing from this Check. Recreate job-02.yaml."
export HOME=/tmp DOCKER_CONFIG=/tmp/.docker
mkdir -p "$DOCKER_CONFIG"
pin="$(lab_config "$REPO_NS" "$REPO_LAB_CONFIG" hummingbird_source_pullspec)"
host="$(lab_config "$REPO_NS" "$REPO_LAB_CONFIG" dest_registry_host)"
expected="${host}/${pin#*/}"
[[ "$pin" =~ @sha256:[0-9a-f]{64}$ ]] || fail "The published index is not digest pinned."
[[ "$(report_get status)" == verified ]] || fail "Run the Ansible workflow successfully before this Check."
[[ "$(report_get executor)" == ansible-bastion ]] || fail "The report is not a bastion workflow result."
[[ "$(report_get source_pullspec)" == "$pin" ]] || fail "The report names a different source."
[[ "$(report_get destination_pullspec)" == "$expected" ]] || fail "The report names a different destination or digest."
[[ "$(report_get index_digest)" == "${pin##*@}" ]] || fail "The report index digest does not match the claim."
[[ "$(report_get source_verified)" == true && "$(report_get destination_verified)" == true ]] || fail "Both workflow verification results are required."
report_require_key run_id
# Trust is supplied by the Check, never by a learner-controlled key in the report.
"$cosign_bin" verify --key https://security.access.redhat.com/data/63405576.txt \
  --insecure-ignore-tlog "$pin" > /tmp/source-verification.json \
  || fail "The published index does not verify with Red Hat's key."
"$cosign_bin" verify --allow-insecure-registry \
  --key https://security.access.redhat.com/data/63405576.txt \
  --insecure-ignore-tlog "$expected" > /tmp/destination-verification.json \
  || fail "The internal index does not verify with Red Hat's key."
pass "Published and internal index signatures verify with Red Hat's key: ${expected}"
