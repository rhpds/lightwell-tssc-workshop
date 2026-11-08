#!/usr/bin/env bash
# 4.1 — active Dockerfile/settings have no public FROM/Central/curl; known-bad remains.
set -euo pipefail
org="$(learner_org)"
repo="$(learner_app_repo)"
gitea_repo_ok "$org" "$repo"
df="$(gitea_raw "$org" "$repo" Dockerfile)"
from_lines="$(printf '%s\n' "$df" | grep -E '^FROM ' || true)"
[[ -n "$from_lines" ]] || fail "${org}/${repo} Dockerfile has no FROM lines."
deny_contains "active Dockerfile FROM" "$from_lines" "registry.access.redhat.com"
deny_contains "active Dockerfile FROM" "$from_lines" "registry.redhat.io"
deny_contains "active Dockerfile FROM" "$from_lines" "docker.io"
dest="$(lab_config "$REPO_NS" "$REPO_LAB_CONFIG" dest_registry_host)"
if [[ -n "$dest" ]]; then
  deny_contains "active Dockerfile FROM (dest Route after 4.1)" "$from_lines" "$dest"
fi
require_contains "active Dockerfile FROM" "$from_lines" "image-registry.openshift-image-registry.svc"
deny_contains "active Dockerfile" "$df" "curl "
settings="$(gitea_raw "$org" "$repo" settings.xml)"
deny_contains "${org}/${repo} settings.xml" "$settings" "repo.maven.apache.org"
bad="$(gitea_raw "$org" "$repo" Dockerfile.known-bad)"
require_contains "Dockerfile.known-bad" "$bad" "docker.io"
report_require_token hermetic_starts source
pass "Active Dockerfile/settings are hermetic and Dockerfile.known-bad is still a leftover."
