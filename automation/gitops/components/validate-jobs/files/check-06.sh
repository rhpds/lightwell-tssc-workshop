#!/usr/bin/env bash
# 3.2 — committed Dockerfile runtime FROM dest + hi/openjdk + digest; default pin; pins still stale.
set -euo pipefail
org="$(learner_org)"
repo="$(learner_app_repo)"
gitea_repo_ok "$org" "$repo"
df="$(gitea_raw "$org" "$repo" Dockerfile)"
from_lines="$(printf '%s\n' "$df" | grep -E '^FROM ' || true)"
[[ -n "$from_lines" ]] || fail "${org}/${repo} Dockerfile has no FROM lines."
runtime_from="$(printf '%s\n' "$from_lines" | grep -v ' AS ' | tail -1)"
[[ -n "$runtime_from" ]] || fail "${org}/${repo} Dockerfile has no runtime FROM (non-AS) line."
dest="$(userinfo "$REPO_NS" "$REPO_USERINFO" dest_registry_host)"
require_contains "${org}/${repo} runtime FROM" "$runtime_from" "$dest"
require_contains "${org}/${repo} runtime FROM" "$runtime_from" "sha256:"
require_contains "${org}/${repo} runtime FROM" "$runtime_from" "hi/openjdk"
deny_contains "${org}/${repo} runtime FROM" "$runtime_from" "hummingbird-mirror"
deny_contains "${org}/${repo} runtime FROM" "$runtime_from" "ubi9/openjdk-21-runtime"
deny_contains "${org}/${repo} runtime FROM" "$runtime_from" "eclipse-temurin"
deny_contains "${org}/${repo} runtime FROM" "$runtime_from" "registry.access.redhat.com"
pom="$(gitea_raw "$org" "$repo" pom.xml)"
# The seed already stores 3.14.0.rhlw-00001 inside profile lightwell-remediated-pins.
# Maven uses that value only when the profile is active. The dependency reads the
# first <properties> block, which the seed leaves on 3.14.0. Grade that block.
default_props="$(printf '%s\n' "$pom" | awk '
  /<properties>/ { found = 1 }
  found { print }
  found && /<\/properties>/ { exit }
')"
[[ -n "$default_props" ]] || fail "${org}/${repo} pom.xml has no <properties> block."
deny_contains "${org}/${repo} pom.xml default properties" "$default_props" \
  "<commons.lang3.version>3.14.0</commons.lang3.version>"
require_contains "${org}/${repo} pom.xml default properties" "$default_props" \
  "<commons.lang3.version>3.14.0.rhlw-00001</commons.lang3.version>"
report_require_token runtime_from dest-digest
pass "Learner Dockerfile runtime FROM is dest/hi/openjdk@digest and the default pom pin is the scored GAV."
