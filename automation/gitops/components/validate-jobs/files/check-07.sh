#!/usr/bin/env bash
# 3.3 — renovate-bot moved pins off the stale seed.
set -euo pipefail
org="$(learner_org)"
repo="$(learner_app_repo)"
gitea_repo_ok "$org" "$repo"
pins="$(gitea_raw "$org" "$repo" lightwell-pins.properties)"
deny_contains "${org}/${repo} lightwell-pins.properties" "$pins" "rhlw-00000"
deny_contains "${org}/${repo} lightwell-pins.properties" "$pins" "sha256:0000000000000000000000000000000000000000000000000000000000000000"
bot="$(lab_config "$GITEA_NS" "$GITEA_LAB_CONFIG" renovate_bot_username)"
base="$(gitea_base)"
commits="$(curl -skS --max-time 20 \
  "${base}/api/v1/repos/${org}/${repo}/commits?path=lightwell-pins.properties&limit=20" || true)"
[[ -n "$commits" ]] || fail "Cannot list commits for lightwell-pins.properties on ${org}/${repo}."
require_contains "lightwell-pins.properties commits" "$commits" "$bot"
report_require_token who_changed_pins renovate-bot
pass "lightwell-pins.properties left the seed values and a ${bot} commit is on that file."
