#!/usr/bin/env bash
# 5.3 — key-based signature on the app digest, checked with the published PEM.
# Issue #129: TaskRun cosign-sign-keyless is Check 5.1 (check-12.sh).
# ~/lab-trust stays on the Showroom terminal. This Job reads ConfigMap
# tssc-admission/lab-cosign-pubkey and runs cosign verify --key.
set -euo pipefail

cosign_bin="/opt/cosign/cosign"
[[ -x "$cosign_bin" ]] || fail "cosign is missing at ${cosign_bin}. Job template job-14.yaml copies it from the RHTAS cosign image."

# ose-cli sets HOME=/ . Restricted SCC cannot create /.docker there.
export HOME=/tmp
export DOCKER_CONFIG=/tmp/.docker
mkdir -p "${DOCKER_CONFIG}"

ns="$(build_ns)"
pub="$(cm_get tssc-admission lab-cosign-pubkey cosign.pub)"
[[ -n "$pub" ]] || fail "ConfigMap tssc-admission/lab-cosign-pubkey is missing key cosign.pub. Publish /home/lab-user/lab-trust/cosign.pub."
deny_placeholder "ConfigMap tssc-admission/lab-cosign-pubkey key cosign.pub" "$pub"
require_contains "ConfigMap tssc-admission/lab-cosign-pubkey key cosign.pub" "$pub" "BEGIN PUBLIC KEY"
require_contains "ConfigMap tssc-admission/lab-cosign-pubkey key cosign.pub" "$pub" "END PUBLIC KEY"

image="$(oc -n "$ns" get istag spring-boot-lw-poc:latest \
  -o jsonpath='{.image.dockerImageReference}' 2>/dev/null || true)"
[[ "$image" == *@sha256:* ]] \
  || fail "ImageStreamTag ${ns}/spring-boot-lw-poc:latest has no sha256 digest. Finish 4.4 so there is an image to sign with --key."

registry="${image%%/*}"
token_file="/var/run/secrets/kubernetes.io/serviceaccount/token"
[[ -s "$token_file" ]] || fail "Validate Job ServiceAccount token is missing. The Job cannot log in to ${registry}."

login_log="$(mktemp)"
if ! "$cosign_bin" login -u unused -p "$(cat "$token_file")" "$registry" >"$login_log" 2>&1; then
  detail="$(tr '\n' ' ' < "$login_log" | head -c 400)"
  fail "cosign login to ${registry} failed: ${detail}. ServiceAccount validate-jobs needs system:image-puller in ${ns}."
fi

key="$(mktemp)"
trap 'rm -f "$key"' EXIT
printf '%s\n' "$pub" > "$key"

echo "cosign verify --key ConfigMap tssc-admission/lab-cosign-pubkey ${image}"
if ! "$cosign_bin" verify --key "$key" \
  --insecure-ignore-tlog \
  --allow-http-registry --allow-insecure-registry \
  "$image"; then
  fail "cosign verify --key failed for ${image}. Sign that digest with /home/lab-user/lab-trust/cosign.key (--tlog-upload=false) and publish the matching cosign.pub to ConfigMap tssc-admission/lab-cosign-pubkey."
fi

report_require_token diode_honest not-air-gap
pass "Key-based signature on ${image} verifies with ConfigMap tssc-admission/lab-cosign-pubkey."
