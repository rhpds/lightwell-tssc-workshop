#!/usr/bin/env bash
# 1.2 — ImageSet filled, oc-mirror-student Completed, dest has signature tags.
set -euo pipefail
body="$(cm_get "$REPO_NS" imageset-configuration imageset-config.yaml)"
[[ -n "$body" ]] || fail "ConfigMap ${REPO_NS}/imageset-configuration is empty."
deny_placeholder "imageset-configuration" "$body"
deny_contains "imageset-configuration" "$body" "ubi-minimal"
pin="$(userinfo "$REPO_NS" "$REPO_USERINFO" hummingbird_source_pullspec)"
require_contains "imageset-configuration" "$body" "$pin"
job_succeeded "$REPO_NS" oc-mirror-student
# #63: oc-mirror copies the image; dest signatures are tag-based (.sig) after cosign copy.
host="$(userinfo "$REPO_NS" "$REPO_USERINFO" dest_registry_host)"
repo="${pin#*/}"
repo="${repo%%:*}"
tags="$(curl -skS --max-time 20 "https://${host}/v2/${repo}/tags/list" || true)"
echo "$tags" | grep -q '\.sig' \
  || fail "Dest ${host}/v2/${repo} has no .sig tags. Job must copy signatures onto Nexus (tag protocol)."
report_require_token student_runs_mirror student-mirror
pass "ImageSet is the Hummingbird pin, Job oc-mirror-student Completed, and dest has signature tags."
