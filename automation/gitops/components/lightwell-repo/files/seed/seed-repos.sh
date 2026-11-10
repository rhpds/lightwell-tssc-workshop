#!/usr/bin/env bash
# Bootstrap Nexus repos + seed Validated / Remediated / OSV / CycloneDX content.
# Intended to run in Job lightwell-repo-seed (ServiceAccount with pods/exec).
# Never embeds LW_* or Nexus admin passwords in Git.
set -euo pipefail

NAMESPACE="${NAMESPACE:-lightwell-repo}"
NEXUS_SVC="${NEXUS_SVC:-http://nexus:8081}"
MODE="${LIGHTWELL_REPO_MODE:-seeded}"
SEED_DIR="${SEED_DIR:-/seed}"
OSV_ID="${OSV_ID:-LW-DEMO-0001}"
OSV_PATH="osv/java/remediated/${OSV_ID}.json"

log() { echo "[lightwell-repo-seed] $*"; }

wait_nexus() {
  log "Waiting for Nexus REST at ${NEXUS_SVC} ..."
  for _ in $(seq 1 90); do
    if curl -sf "${NEXUS_SVC}/service/rest/v1/status" >/dev/null 2>&1; then
      log "Nexus is Ready"
      return 0
    fi
    sleep 10
  done
  log "ERROR: Nexus did not become Ready"
  exit 1
}

resolve_admin_password() {
  if [[ -n "${NEXUS_ADMIN_PASSWORD:-}" ]]; then
    log "Using NEXUS_ADMIN_PASSWORD from environment / Secret"
    return 0
  fi
  log "Capturing Nexus admin password from pod (first-boot file) ..."
  local pod
  for _ in $(seq 1 60); do
    pod="$(oc get pods -n "${NAMESPACE}" -l app=nexus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "${pod}" ]]; then
      if NEXUS_ADMIN_PASSWORD="$(oc exec -n "${NAMESPACE}" "${pod}" -- cat /nexus-data/admin.password 2>/dev/null)"; then
        export NEXUS_ADMIN_PASSWORD
        log "Captured admin password from ${pod}"
        return 0
      fi
    fi
    sleep 10
  done
  log "ERROR: could not read /nexus-data/admin.password — set Secret nexus-admin-credentials"
  exit 1
}

AUTH=()
setup_auth() {
  AUTH=(-u "${NEXUS_ADMIN_USER:-admin}:${NEXUS_ADMIN_PASSWORD}")
}

# Ignore HTTP 400 (already exists) so Job is re-runnable
curl_ok() {
  local code
  code="$(curl -sS -o /tmp/nexus-out -w '%{http_code}' "${AUTH[@]}" "$@" || true)"
  if [[ "${code}" =~ ^2 ]] || [[ "${code}" == "400" ]]; then
    return 0
  fi
  log "WARN: HTTP ${code} for $* — body:"
  cat /tmp/nexus-out || true
  return 0
}

create_maven_proxy() {
  local name="$1" url="$2"
  log "Maven proxy repo: ${name} -> ${url}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/maven/proxy" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"ALLOW\"},\"proxy\":{\"remoteUrl\":\"${url}\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"authentication\":{\"type\":\"username\",\"username\":\"${LW_USERNAME}\",\"password\":\"${LW_PASSWORD}\"}},\"maven\":{\"versionPolicy\":\"RELEASE\",\"layoutPolicy\":\"PERMISSIVE\"}}"
}

create_maven_hosted() {
  local name="$1"
  log "Maven hosted repo: ${name}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/maven/hosted" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"ALLOW\"},\"maven\":{\"versionPolicy\":\"RELEASE\",\"layoutPolicy\":\"PERMISSIVE\"}}"
}

create_raw_hosted() {
  local name="$1"
  log "Raw hosted repo: ${name}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/raw/hosted" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":false,\"writePolicy\":\"ALLOW\"},\"raw\":{\"contentDisposition\":\"ATTACHMENT\"}}"
}

create_raw_proxy() {
  local name="$1" url="$2"
  log "Raw proxy repo: ${name} -> ${url}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/raw/proxy" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":false,\"writePolicy\":\"ALLOW\"},\"proxy\":{\"remoteUrl\":\"${url}\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"authentication\":{\"type\":\"username\",\"username\":\"${LW_USERNAME}\",\"password\":\"${LW_PASSWORD}\"}},\"raw\":{\"contentDisposition\":\"ATTACHMENT\"}}"
}

create_pypi_hosted() {
  local name="$1"
  log "PyPI hosted repo: ${name}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/pypi/hosted" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"ALLOW\"}}"
}

create_pypi_proxy() {
  local name="$1" url="$2"
  log "PyPI proxy repo: ${name} -> ${url}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/pypi/proxy" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true},\"proxy\":{\"remoteUrl\":\"${url}\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"authentication\":{\"type\":\"username\",\"username\":\"${LW_USERNAME}\",\"password\":\"${LW_PASSWORD}\"}}}"
}

# V2-10: empty Docker dest for learner oc-mirror. Do not upload HUMMINGBIRD_JAVA_RUNTIME.
create_docker_hosted() {
  local name="$1"
  local port="${2:-5000}"
  log "Docker hosted repo (empty dest): ${name} httpPort=${port}"
  curl_ok -H 'Content-Type: application/json' \
    -X POST "${NEXUS_SVC}/service/rest/v1/repositories/docker/hosted" \
    -d "{\"name\":\"${name}\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":false,\"writePolicy\":\"ALLOW\"},\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false,\"httpPort\":${port}}}"
}

# Workshop prefetch uses mirrorOf * → maven-public. Include Lightwell hosted repos
# so .rhlw-* pins resolve (issue #81). Preserve existing Central/releases members.
ensure_maven_public_group() {
  local extra="${VALIDATED_REPO:-lightwell-java-validated},${REMEDIATED_REPO:-lightwell-java-remediated},${VALIDATED_HOSTED:-lightwell-java-validated-hosted},${REMEDIATED_HOSTED:-lightwell-java-remediated-hosted}"
  log "Ensuring maven-public group includes Lightwell Maven repos"
  export NEXUS_SVC NEXUS_ADMIN_PASSWORD
  export NEXUS_ADMIN_USER="${NEXUS_ADMIN_USER:-admin}"
  PY=""
  command -v python3 >/dev/null 2>&1 && PY=python3
  command -v python >/dev/null 2>&1 && PY="${PY:-python}"
  if [[ -z "${PY}" ]]; then
    log "WARN: python3 missing — cannot merge maven-public members"
    return 0
  fi
  EXTRA_MEMBERS="${extra}" "${PY}" - <<'PY' || log "WARN: maven-public group update failed"
import base64, json, os, urllib.error, urllib.request

nexus = os.environ["NEXUS_SVC"].rstrip("/")
user = os.environ.get("NEXUS_ADMIN_USER", "admin")
password = os.environ["NEXUS_ADMIN_PASSWORD"]
basic = base64.b64encode(f"{user}:{password}".encode()).decode()
url = f"{nexus}/service/rest/v1/repositories/maven/group/maven-public"
wanted = ["maven-releases", "maven-snapshots", "maven-central"]
wanted += [n.strip() for n in os.environ.get("EXTRA_MEMBERS", "").split(",") if n.strip()]
headers = {"Authorization": f"Basic {basic}", "Content-Type": "application/json"}

def open_req(req):
    return urllib.request.urlopen(req, timeout=30)

exists, members = False, []
req = urllib.request.Request(url, headers=headers)
try:
    with open_req(req) as resp:
        body = json.loads(resp.read().decode())
    exists = True
    members = list((body.get("group") or {}).get("memberNames") or [])
except urllib.error.HTTPError as exc:
    if exc.code != 404:
        raise SystemExit(f"GET maven-public failed: {exc.code}") from exc
for name in wanted:
    if name not in members:
        members.append(name)
payload = json.dumps({
    "name": "maven-public",
    "online": True,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": True},
    "group": {"memberNames": members},
}).encode()
if exists:
    req = urllib.request.Request(url, data=payload, method="PUT", headers=headers)
else:
    req = urllib.request.Request(
        f"{nexus}/service/rest/v1/repositories/maven/group",
        data=payload, method="POST", headers=headers,
    )
try:
    open_req(req).read()
    print("maven-public members=" + ",".join(members))
except urllib.error.HTTPError as exc:
    raise SystemExit(f"write maven-public failed: {exc.code} {exc.read().decode()[:300]}") from exc
PY
}

# Strict REST helper: 2xx only. Do not reuse curl_ok — that treats HTTP 400 as
# success (repo already exists), which hid a bad realm PUT (#62).
curl_strict() {
  local code
  code="$(curl -sS -o /tmp/nexus-out -w '%{http_code}' "${AUTH[@]}" "$@" || true)"
  if [[ "${code}" =~ ^2 ]]; then
    return 0
  fi
  log "ERROR: HTTP ${code} for $*"
  cat /tmp/nexus-out || true
  return 1
}

enable_docker_token_realm() {
  # Nexus 3.70 available IDs do not include NexusAuthorizingRealm. The previous
  # PUT of that id returned 400; curl_ok swallowed it, DockerToken never
  # activated, and oc-mirror dest login failed (#62).
  log "Enabling DockerToken security realm (Nexus 3.70 ids; not NexusAuthorizingRealm)"
  curl_strict -H 'Content-Type: application/json' \
    -X PUT "${NEXUS_SVC}/service/rest/v1/security/realms/active" \
    -d '["NexusAuthenticatingRealm","DefaultRole","DockerToken"]'
  local active
  active="$(curl -sf "${AUTH[@]}" "${NEXUS_SVC}/service/rest/v1/security/realms/active")" || {
    log "ERROR: could not read active realms after PUT"
    exit 1
  }
  if ! grep -q 'DockerToken' <<<"${active}"; then
    log "ERROR: DockerToken not in active realms: ${active}"
    exit 1
  fi
  log "Active security realms: ${active}"
}

write_docker_push_secret() {
  local host="${REGISTRY_HOST:-}"
  if [[ -z "${host}" ]] || ! command -v oc >/dev/null 2>&1; then
    log "Skipping docker-push secret (REGISTRY_HOST or oc missing)"
    return 0
  fi
  local secret="${DOCKER_SECRET_NAME:-nexus-docker-push}"
  log "Writing Secret ${secret} for dest ${host} (admin push; do not commit)"
  oc -n "${NAMESPACE}" create secret docker-registry "${secret}" \
    --docker-server="${host}" \
    --docker-username="${NEXUS_ADMIN_USER:-admin}" \
    --docker-password="${NEXUS_ADMIN_PASSWORD}" \
    --dry-run=client -o yaml | oc -n "${NAMESPACE}" apply -f -
}

upload_pypi() {
  local repo="$1" wheel="$2"
  log "Upload PyPI wheel $(basename "${wheel}") -> ${repo}"
  curl_ok -H 'accept: application/json' \
    -F "pypi.asset=@${wheel}" \
    "${NEXUS_SVC}/service/rest/v1/components?repository=${repo}"
}

upload_maven() {
  local repo="$1" group_id="$2" artifact_id="$3" version="$4" pom="$5" jar="$6"
  local cdx="${7:-}" vex="${8:-}"
  log "Upload Maven ${group_id}:${artifact_id}:${version} -> ${repo}"
  local form=(
    -F "maven2.groupId=${group_id}"
    -F "maven2.artifactId=${artifact_id}"
    -F "maven2.version=${version}"
    -F "maven2.asset1=@${jar}"
    -F "maven2.asset1.extension=jar"
    -F "maven2.asset2=@${pom}"
    -F "maven2.asset2.extension=pom"
  )
  local n=3
  if [[ -n "${cdx}" ]]; then
    log "  sidecar classifier=cdx ${cdx}"
    form+=(-F "maven2.asset${n}=@${cdx}" -F "maven2.asset${n}.classifier=cdx" -F "maven2.asset${n}.extension=json")
    n=$((n + 1))
  fi
  if [[ -n "${vex}" ]]; then
    log "  sidecar classifier=vex ${vex}"
    form+=(-F "maven2.asset${n}=@${vex}" -F "maven2.asset${n}.classifier=vex" -F "maven2.asset${n}.extension=json")
  fi
  curl_ok -H 'accept: application/json' \
    "${form[@]}" \
    "${NEXUS_SVC}/service/rest/v1/components?repository=${repo}"
}

upload_raw() {
  local repo="$1" path="$2" file="$3"
  log "Upload raw ${repo}/${path}"
  curl_ok -X PUT --data-binary @"${file}" \
    -H 'Content-Type: application/octet-stream' \
    "${NEXUS_SVC}/repository/${repo}/${path}"
}

prepare_stub_jar() {
  local out="$1"
  if [[ -f "${SEED_DIR}/workshop-stub.jar" ]]; then
    cp "${SEED_DIR}/workshop-stub.jar" "${out}"
  elif [[ -f "${SEED_DIR}/workshop-stub.jar.b64" ]]; then
    base64 -d < "${SEED_DIR}/workshop-stub.jar.b64" > "${out}"
  else
    log "ERROR: missing workshop-stub.jar(.b64) in ${SEED_DIR}"
    exit 1
  fi
}

# Deterministic PyPI Validated wheel (httpx) for Module 7 pip install proof / FastAPI sample.
# Fetched at seed time (same pattern as commons-lang3) — not embedded in the ConfigMap.
prepare_pypi_validated_wheel() {
  local out="$1"
  local pkg="${PYPI_SEED_PACKAGE:-httpx}"
  local ver="${PYPI_SEED_VERSION:-0.27.2}"
  # Default: content-addressed files.pythonhosted.org URL for httpx-0.27.2 (override via env)
  local url="${PYPI_SEED_WHEEL_URL:-https://files.pythonhosted.org/packages/56/95/9377bcb415797e44274b51d46e3249eba641711cf3348050f76ee7b15ffc/httpx-0.27.2-py3-none-any.whl}"
  local min_bytes="${PYPI_SEED_MIN_BYTES:-20000}"
  log "Fetching PyPI Validated seed wheel ${pkg}==${ver} from ${url}"
  if curl -fsSL --retry 3 --retry-delay 2 -o "${out}" "${url}"; then
    local size
    size="$(wc -c < "${out}" | tr -d ' ')"
    if [[ "${size}" -ge "${min_bytes}" ]]; then
      log "PyPI seed wheel ready (${size} bytes)"
      return 0
    fi
    log "WARN: downloaded wheel too small (${size} bytes); expected >= ${min_bytes}"
  else
    log "WARN: download failed for ${url}"
  fi
  log "ERROR: PyPI Validated seed wheel required for Module 7 pip install"
  exit 1
}

# Minimal workshop marker wheel (Remediated proof; not a live backport).
# Python/pip require PEP 440 — use local version 1.0.0+rhlw.00001 (Java keeps .rhlw-0000X).
# ConfigMap keys cannot contain '+' — embed as ${norm}-remediated.whl(.b64); upload uses PEP 427 name.
prepare_pypi_remediated_wheel() {
  local out="$1"
  local pkg="${PYPI_REMEDIATED_PACKAGE:-lw-workshop-pypi}"
  local ver="${PYPI_REMEDIATED_VERSION:-1.0.0+rhlw.00001}"
  local norm
  norm="$(echo "${pkg}" | tr '-' '_')"
  local wheel_name="${norm}-${ver}-py3-none-any.whl"
  local embedded="${norm}-remediated.whl"
  if [[ -f "${SEED_DIR}/${embedded}" ]]; then
    cp "${SEED_DIR}/${embedded}" "${out}"
    log "Using embedded Remediated marker wheel ${pkg}==${ver}"
    return 0
  fi
  if [[ -f "${SEED_DIR}/${embedded}.b64" ]]; then
    base64 -d < "${SEED_DIR}/${embedded}.b64" > "${out}"
    log "Decoded Remediated marker wheel ${pkg}==${ver}"
    return 0
  fi
  # Legacy filename fallback (pre-PEP440 workshop marker)
  if [[ -f "${SEED_DIR}/${wheel_name}" ]]; then
    cp "${SEED_DIR}/${wheel_name}" "${out}"
    log "Using embedded Remediated marker wheel ${pkg}==${ver}"
    return 0
  fi
  if [[ -f "${SEED_DIR}/${wheel_name}.b64" ]]; then
    base64 -d < "${SEED_DIR}/${wheel_name}.b64" > "${out}"
    log "Decoded Remediated marker wheel ${pkg}==${ver}"
    return 0
  fi
  local work
  work="$(mktemp -d)"
  mkdir -p "${work}/${norm}" "${work}/${norm}-${ver}.dist-info"
  printf '%s\n' '"""Workshop Lightwell PyPI Remediated marker (seeded mirror)."""' \
    "__version__ = \"${ver}\"" > "${work}/${norm}/__init__.py"
  cat > "${work}/${norm}-${ver}.dist-info/METADATA" <<EOF
Metadata-Version: 2.1
Name: ${pkg}
Version: ${ver}
Summary: Workshop seeded Lightwell PyPI Remediated marker (PEP 440 local +rhlw.*)
EOF
  cat > "${work}/${norm}-${ver}.dist-info/WHEEL" <<EOF
Wheel-Version: 1.0
Generator: lightwell-repo-seed
Root-Is-Purelib: true
Tag: py3-none-any
EOF
  printf '%s\n' \
    "${norm}/__init__.py,," \
    "${norm}-${ver}.dist-info/METADATA,," \
    "${norm}-${ver}.dist-info/WHEEL,," \
    "${norm}-${ver}.dist-info/RECORD,," > "${work}/${norm}-${ver}.dist-info/RECORD"
  if command -v zip >/dev/null 2>&1; then
    (cd "${work}" && zip -q -r "${wheel_name}" "${norm}" "${norm}-${ver}.dist-info")
    cp "${work}/${wheel_name}" "${out}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
import zipfile, pathlib
root = pathlib.Path("${work}")
out = pathlib.Path("${out}")
with zipfile.ZipFile(out, "w") as zf:
    for p in root.rglob("*"):
        if p.is_file():
            zf.write(p, p.relative_to(root).as_posix())
PY
  else
    log "ERROR: missing ${embedded}(.b64) in ${SEED_DIR} and no zip/python3 to build it"
    exit 1
  fi
  log "Built Remediated marker wheel ${pkg}==${ver}"
}

# Compile-capable Apache Commons Lang (ASL 2.0) for Spring Boot PoC clean verify.
# Re-uploaded under Validated + Remediated coordinates so Module 2 can exercise both
# resolution stubs (spring-core) and real consumption (commons-lang3).
prepare_commons_lang3_jar() {
  local out="$1"
  local url="${COMMONS_LANG3_JAR_URL:-https://repo.maven.apache.org/maven2/org/apache/commons/commons-lang3/3.14.0/commons-lang3-3.14.0.jar}"
  local min_bytes="${COMMONS_LANG3_MIN_BYTES:-100000}"
  log "Fetching compile-capable commons-lang3 from ${url}"
  if curl -fsSL --retry 3 --retry-delay 2 -o "${out}" "${url}"; then
    local size
    size="$(wc -c < "${out}" | tr -d ' ')"
    if [[ "${size}" -ge "${min_bytes}" ]]; then
      log "commons-lang3 jar ready (${size} bytes)"
      return 0
    fi
    log "WARN: downloaded jar too small (${size} bytes); expected >= ${min_bytes}"
  else
    log "WARN: download failed for ${url}"
  fi
  log "ERROR: compile-capable commons-lang3 required for Module 2 clean verify"
  exit 1
}

# Hosted repos use writePolicy ALLOW; delete prior GAV paths so re-seed replaces stubs.
delete_maven_gavi() {
  local repo="$1" group_id="$2" artifact_id="$3" version="$4"
  local group_path
  group_path="$(echo "${group_id}" | tr '.' '/')"
  local base="${NEXUS_SVC}/repository/${repo}/${group_path}/${artifact_id}/${version}"
  local f
  for f in \
    "${artifact_id}-${version}.jar" \
    "${artifact_id}-${version}.pom" \
    "${artifact_id}-${version}.jar.sha1" \
    "${artifact_id}-${version}.pom.sha1" \
    "${artifact_id}-${version}.jar.md5" \
    "${artifact_id}-${version}.pom.md5" \
    "${artifact_id}-${version}-cdx.json" \
    "${artifact_id}-${version}-vex.json"; do
    curl_ok -X DELETE "${base}/${f}"
  done
}

seed_content() {
  local work
  work="$(mktemp -d)"
  prepare_stub_jar "${work}/stub.jar"
  prepare_commons_lang3_jar "${work}/commons-lang3.jar"
  # Synthetic coordinate, not a security patch. Keep the validated JAR untouched.
  python3 "${SEED_DIR}/build-demo-jar.py" "${work}/commons-lang3.jar" \
    "${work}/commons-lang3-demo.jar" "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.pom"

  # Learner-facing repo keys (same names as Maven settings.xml)
  local validated_repo="${VALIDATED_REPO:-lightwell-java-validated}"
  local remediated_repo="${REMEDIATED_REPO:-lightwell-java-remediated}"
  local osv_repo="${OSV_REPO:-lightwell-osv-java-remediated}"

  # Experiment A — resolution stubs (Module 2 / 3 dependency:get; not for compile)
  upload_maven "${validated_repo}" "org.springframework" "spring-core" "5.3.18" \
    "${SEED_DIR}/spring-core-5.3.18.pom" "${work}/stub.jar"
  upload_maven "${remediated_repo}" "org.springframework" "spring-core" "5.3.18.rhlw-00003" \
    "${SEED_DIR}/spring-core-5.3.18.rhlw-00003.pom" "${work}/stub.jar"

  # Experiment B — compile-capable consumption (Spring Boot PoC clean verify)
  # V2-18 / C+: attach GAV-bound CDX (+ OpenVEX on remediated) beside the Track 2 pin.
  delete_maven_gavi "${validated_repo}" "org.apache.commons" "commons-lang3" "3.14.0"
  delete_maven_gavi "${remediated_repo}" "org.apache.commons" "commons-lang3" "3.14.0.rhlw-00001"
  upload_maven "${validated_repo}" "org.apache.commons" "commons-lang3" "3.14.0" \
    "${SEED_DIR}/commons-lang3-3.14.0.pom" "${work}/commons-lang3.jar" \
    "${SEED_DIR}/commons-lang3-3.14.0.cdx.json"
  upload_maven "${remediated_repo}" "org.apache.commons" "commons-lang3" "3.14.0.rhlw-00001" \
    "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.pom" "${work}/commons-lang3-demo.jar" \
    "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.cdx.json" \
    "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.vex.json"

  upload_raw "${osv_repo}" "${OSV_PATH}" "${SEED_DIR}/${OSV_ID}.json"
  local vex_osv_id="${VEX_OSV_ID:-LW-DEMO-0002}"
  upload_raw "${osv_repo}" "osv/java/remediated/${vex_osv_id}.json" \
    "${SEED_DIR}/${vex_osv_id}.json"
  upload_raw "${osv_repo}" "sbom/java/validated/org.springframework/spring-core/5.3.18.cdx.json" \
    "${SEED_DIR}/spring-core-5.3.18.cdx.json"
  upload_raw "${osv_repo}" "sbom/java/remediated/org.springframework/spring-core/5.3.18.rhlw-00003.cdx.json" \
    "${SEED_DIR}/spring-core-5.3.18.rhlw-00003.cdx.json"
  upload_raw "${osv_repo}" "sbom/java/validated/org.apache.commons/commons-lang3/3.14.0.cdx.json" \
    "${SEED_DIR}/commons-lang3-3.14.0.cdx.json"
  upload_raw "${osv_repo}" "sbom/java/remediated/org.apache.commons/commons-lang3/3.14.0.rhlw-00001.cdx.json" \
    "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.cdx.json"
  upload_raw "${osv_repo}" "vex/java/remediated/org.apache.commons/commons-lang3/3.14.0.rhlw-00001.vex.json" \
    "${SEED_DIR}/commons-lang3-3.14.0.rhlw-00001.vex.json"

  # Python / PyPI — Validated always (when channel enabled); Remediated required (enabled=true)
  # Wheel filenames MUST be PEP 427 (e.g. httpx-0.27.2-py3-none-any.whl). Nexus simple
  # index exposes the upload basename; pip ignores non-conforming names (versions: none).
  if [[ "${PYPI_VALIDATED_ENABLED:-true}" == "true" ]]; then
    local pypi_validated="${PYPI_VALIDATED_REPO:-lightwell-python-validated}"
    local pkg="${PYPI_SEED_PACKAGE:-httpx}"
    local ver="${PYPI_SEED_VERSION:-0.27.2}"
    local validated_wheel="${work}/${pkg}-${ver}-py3-none-any.whl"
    prepare_pypi_validated_wheel "${validated_wheel}"
    upload_pypi "${pypi_validated}" "${validated_wheel}"
  fi
  if [[ "${PYPI_REMEDIATED_ENABLED:-true}" == "true" ]]; then
    local pypi_remediated="${PYPI_REMEDIATED_REPO:-lightwell-python-remediated}"
    local rpkg="${PYPI_REMEDIATED_PACKAGE:-lw-workshop-pypi}"
    local rver="${PYPI_REMEDIATED_VERSION:-1.0.0+rhlw.00001}"
    local rnorm
    rnorm="$(echo "${rpkg}" | tr '-' '_')"
    # Upload basename must be PEP 427 (pip simple index); '+' is valid in wheel filenames.
    local remediated_wheel="${work}/${rnorm}-${rver}-py3-none-any.whl"
    prepare_pypi_remediated_wheel "${remediated_wheel}"
    upload_pypi "${pypi_remediated}" "${remediated_wheel}"
  fi

  log "Seeded Maven (stubs + commons-lang3 CDX/VEX) + OSV (${OSV_PATH}, ${vex_osv_id}) + CycloneDX + PyPI"
  log "Do not pre-ingest VEX into TPA — learner pulls from Nexus in Track 7. Do not enable live CSAF as the Check."
}

create_repos() {
  if [[ "${MODE}" == "proxy" ]]; then
    : "${LW_USERNAME:?set LW_USERNAME for proxy mode}"
    : "${LW_PASSWORD:?set LW_PASSWORD for proxy mode}"
    create_maven_proxy "${VALIDATED_REPO:-lightwell-java-validated}" \
      "${VALIDATED_REMOTE:-https://packages.redhat.com/lightwell/java/validated}/"
    create_maven_proxy "${REMEDIATED_REPO:-lightwell-java-remediated}" \
      "${REMEDIATED_REMOTE:-https://packages.redhat.com/lightwell/java/remediated}/"
    create_raw_proxy "${OSV_REPO:-lightwell-osv-java-remediated}" \
      "${OSV_REMOTE:-https://packages.redhat.com/lightwell/osv/java/remediated}/"
    if [[ "${PYPI_VALIDATED_ENABLED:-true}" == "true" ]]; then
      create_pypi_proxy "${PYPI_VALIDATED_REPO:-lightwell-python-validated}" \
        "${PYPI_VALIDATED_REMOTE:-https://packages.redhat.com/lightwell/python/validated}/"
    fi
    # Gate: skip Remediated PyPI proxy when membership / live stream is unavailable
    if [[ "${PYPI_REMEDIATED_ENABLED:-true}" == "true" ]]; then
      create_pypi_proxy "${PYPI_REMEDIATED_REPO:-lightwell-python-remediated}" \
        "${PYPI_REMEDIATED_REMOTE:-https://packages.redhat.com/lightwell/python/remediated}/"
    else
      log "Skipping PyPI Remediated proxy (channels.pypiRemediated.enabled=false)"
    fi
    log "Proxy repos created — live LWN content (credentials from Secret)"
  else
    create_maven_hosted "${VALIDATED_REPO:-lightwell-java-validated}"
    create_maven_hosted "${REMEDIATED_REPO:-lightwell-java-remediated}"
    create_raw_hosted "${OSV_REPO:-lightwell-osv-java-remediated}"
    # Also create *-hosted aliases documented in channels ConfigMap
    create_maven_hosted "${VALIDATED_HOSTED:-lightwell-java-validated-hosted}"
    create_maven_hosted "${REMEDIATED_HOSTED:-lightwell-java-remediated-hosted}"
    create_raw_hosted "${OSV_HOSTED:-lightwell-osv-java-remediated-hosted}"
    if [[ "${PYPI_VALIDATED_ENABLED:-true}" == "true" ]]; then
      create_pypi_hosted "${PYPI_VALIDATED_REPO:-lightwell-python-validated}"
      create_pypi_hosted "${PYPI_VALIDATED_HOSTED:-lightwell-python-validated-hosted}"
    fi
    if [[ "${PYPI_REMEDIATED_ENABLED:-true}" == "true" ]]; then
      create_pypi_hosted "${PYPI_REMEDIATED_REPO:-lightwell-python-remediated}"
      create_pypi_hosted "${PYPI_REMEDIATED_HOSTED:-lightwell-python-remediated-hosted}"
    else
      log "Skipping PyPI Remediated hosted (channels.pypiRemediated.enabled=false)"
    fi
  fi
  if [[ "${DOCKER_MIRROR_ENABLED:-true}" == "true" ]]; then
    create_docker_hosted "${DOCKER_MIRROR_REPO:-hummingbird-mirror}" "${DOCKER_HTTP_PORT:-5000}"
    enable_docker_token_realm
    write_docker_push_secret
    log "Docker dest ${DOCKER_MIRROR_REPO:-hummingbird-mirror} is empty — do not pre-mirror Hummingbird"
  fi
  ensure_maven_public_group
}

main() {
  log "mode=${MODE} nexus=${NEXUS_SVC} namespace=${NAMESPACE}"
  wait_nexus
  resolve_admin_password
  setup_auth
  create_repos
  if [[ "${MODE}" == "seeded" ]]; then
    seed_content
  elif [[ "${SEED_OSV_IN_PROXY:-false}" == "true" ]]; then
    log "Proxy mode with optional local OSV/SBOM overlay skipped (SEED_OSV_IN_PROXY)"
  fi
  log "Done"
}

main "$@"
