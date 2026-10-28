#!/usr/bin/env bash
# 1.1 — published verify snippet ConfigMap (cosign itself is Showroom).
set -euo pipefail
body="$(cm_get "$REPO_NS" stub-01-hummingbird-verify published-verify.sh)"
[[ -n "$body" ]] || fail "ConfigMap ${REPO_NS}/stub-01-hummingbird-verify key published-verify.sh is empty."
deny_placeholder "stub-01-hummingbird-verify" "$body"
deny_contains "stub-01-hummingbird-verify" "$body" "ubi-minimal"
deny_contains "stub-01-hummingbird-verify" "$body" "example.invalid"
pin="$(lab_config "$REPO_NS" "$REPO_LAB_CONFIG" hummingbird_source_pullspec)"
require_contains "stub-01-hummingbird-verify" "$body" "$pin"
report_require_token consume_published consume-published
pass "Published verify snippet matches ConfigMap lab-lightwell-repo and has no placeholders."
