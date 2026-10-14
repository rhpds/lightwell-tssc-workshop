#!/usr/bin/env bash
# 7.1 — CycloneDX document in Trusted Profile Analyzer for the prod GitOps digest.
# Syft 1.18 writes the image manifest digest as metadata.component.version when
# the pull spec tag is latest. Trustify stores that as described_by.version and
# labels.type=cyclonedx. A library component that merely mentions the digest
# does not describe the document.
set -euo pipefail
require_cmd python3
org="$(learner_org)"
prod_repo="$(learner_prod_gitops_repo)"
gitea_repo_ok "$org" "$prod_repo"
values="$(gitea_raw "$org" "$prod_repo" values.yaml)"
deny_contains "${org}/${prod_repo} values.yaml" "$values" "REPLACE_ME_PROD_DIGEST"
require_contains "${org}/${prod_repo} values.yaml" "$values" "sha256:"
digest_line="$(printf '%s\n' "$values" | grep -E '^[[:space:]]*digest:' | head -1 || true)"
digest="$(printf '%s\n' "$digest_line" | grep -oE 'sha256:[0-9a-fA-F]{64}' | head -1 || true)"
if [[ -z "$digest" ]]; then
  digest="$(printf '%s\n' "$values" | grep -oE 'sha256:[0-9a-fA-F]{64}' | head -1 || true)"
fi
digest="$(printf '%s' "$digest" | tr '[:upper:]' '[:lower:]')"
[[ -n "$digest" ]] || fail "${org}/${prod_repo} values.yaml has no sha256 digest of 64 hex characters."

csaf="$(cm_get trusted-profile-analyzer rhtpa-ingestion-info live_csaf_gate)"
[[ "$csaf" == "false" ]] || fail "live_csaf_gate must stay false (do not enable the Red Hat CSAF importer)."

tpa="$(cm_get trusted-profile-analyzer rhtpa-ingestion-info server_url)"
tpa="${tpa%/}"
[[ -n "$tpa" ]] || fail "ConfigMap trusted-profile-analyzer/rhtpa-ingestion-info is missing server_url."
issuer="$(userinfo sso demo-userinfo-keycloak oidc_issuer)"
issuer="${issuer%/}"
tpa_user="$(userinfo sso demo-userinfo-keycloak workshop_username)"
tpa_pass="$(userinfo sso demo-userinfo-keycloak workshop_password)"
cli_secret="$(oc -n trusted-profile-analyzer get secret tpa-realm-cli-clients -o jsonpath='{.data.cli}' 2>/dev/null | base64 -d 2>/dev/null || true)"
cli_secret="${cli_secret%$'\n'}"
[[ -n "$cli_secret" ]] || fail "Secret trusted-profile-analyzer/tpa-realm-cli-clients key cli is unreadable."

tok_body="$(mktemp)"
tok_code="$(curl -skS --max-time 20 -o "$tok_body" -w '%{http_code}' -X POST \
  "${issuer}/protocol/openid-connect/token" \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=cli \
  --data-urlencode client_secret="${cli_secret}" \
  --data-urlencode username="${tpa_user}" \
  --data-urlencode password="${tpa_pass}" \
  --data-urlencode scope=openid || true)"
access="$(python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get("access_token") or "")
except Exception:
    print("")
' "$tok_body" 2>/dev/null || true)"
rm -f "$tok_body"
unset cli_secret tpa_pass
[[ "$tok_code" == "200" && -n "$access" ]] || fail "Could not obtain a Trusted Profile Analyzer token (HTTP ${tok_code:-none})."

set +e
grade_msg="$(PROMOTED_DIGEST="$digest" TPA_URL="$tpa" TPA_TOKEN="$access" python3 - <<'PY'
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

digest = os.environ["PROMOTED_DIGEST"].strip().lower()
base = os.environ["TPA_URL"].rstrip("/")
token = os.environ["TPA_TOKEN"]
ctx = ssl._create_unverified_context()


def request(path):
    req = urllib.request.Request(
        base + path,
        headers={"Authorization": "Bearer " + token},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=25) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except Exception as exc:
        sys.stdout.write(f"Trusted Profile Analyzer request failed: {exc}\n")
        raise SystemExit(1)


def described_versions(item):
    found = []
    for described in item.get("described_by") or []:
        version = described.get("version")
        if isinstance(version, str) and version.strip():
            found.append(version.strip().lower())
    return found


def cyclonedx_label(item):
    label = ((item.get("labels") or {}).get("type") or "").strip().lower()
    if not label:
        return True
    return label in ("cyclonedx", "cdx")


def root_version(document):
    component = ((document.get("metadata") or {}).get("component") or {})
    version = component.get("version")
    if isinstance(version, str):
        return version.strip().lower()
    return ""


seen = 0
offset = 0
limit = 50
while offset <= 1000:
    status, raw = request(f"/api/v3/sbom?limit={limit}&offset={offset}")
    if status != 200:
        sys.stdout.write(f"GET /api/v3/sbom failed (HTTP {status}).\n")
        raise SystemExit(1)
    try:
        page = json.loads(raw.decode() or "{}")
    except json.JSONDecodeError:
        sys.stdout.write("GET /api/v3/sbom did not return JSON.\n")
        raise SystemExit(1)
    items = page.get("items") or []
    if not items:
        break
    for item in items:
        seen += 1
        if digest not in described_versions(item) or not cyclonedx_label(item):
            continue
        doc_id = item.get("id") or item.get("sha256")
        if not doc_id:
            continue
        encoded = urllib.parse.quote(str(doc_id), safe="")
        down_status, body = request(f"/api/v3/sbom/{encoded}/download")
        if down_status == 401:
            sys.stdout.write("Trusted Profile Analyzer rejected the workshop token while downloading the SBOM.\n")
            raise SystemExit(1)
        if down_status != 200:
            continue
        try:
            document = json.loads(body.decode())
        except json.JSONDecodeError:
            continue
        if str(document.get("bomFormat") or "").lower() != "cyclonedx":
            continue
        if root_version(document) != digest:
            continue
        components = document.get("components") or []
        if isinstance(components, list) and len(components) > 0:
            raise SystemExit(0)
    if len(items) < limit:
        break
    offset += limit

if seen == 0:
    sys.stdout.write(
        "Trusted Profile Analyzer has no ingested SBOM. "
        f"POST ~/sbom.cyclonedx.json to {base}/api/v3/sbom for digest {digest}.\n"
    )
else:
    sys.stdout.write(
        f"Trusted Profile Analyzer has {seen} SBOM(s). "
        f"None is a CycloneDX document whose root component version is {digest} "
        "and whose component list is non-empty. "
        "Ingest the file from ConfigMap lab-sbom-cyclonedx.\n"
    )
raise SystemExit(1)
PY
)"
grade_rc=$?
set -e
unset access
[[ "$grade_rc" -eq 0 ]] || fail "${grade_msg:-Trusted Profile Analyzer did not return the promoted CycloneDX SBOM.}"

report_require_token sor_object promoted-digest
pass "Trusted Profile Analyzer has a CycloneDX SBOM for promoted digest ${digest}."
