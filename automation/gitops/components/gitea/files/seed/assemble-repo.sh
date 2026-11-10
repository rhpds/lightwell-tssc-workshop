#!/usr/bin/env bash
# Build a student Gitea app tree: isolate monorepo app path + overlay lab files (.tekton, etc.).
# Students never see the workshop GitOps monorepo — only the assembled repo root.
#
# Env:
#   SOURCE_MODE, SOURCE_REPO_URL, SOURCE_REVISION, SOURCE_PATH
#   INCLUDE_OSV_EVAL=true|false (default true — Java Module 3 helpers)
#   OVERLAY_PREFIX=overlay|overlay-python (ConfigMap key prefix; default overlay)
set -euo pipefail

ROOT="${1:-/tmp/gitea-seed/repo}"
mkdir -p "${ROOT}"

SOURCE_MODE="${SOURCE_MODE:-live}"
SOURCE_REPO_URL="${SOURCE_REPO_URL:-}"
SOURCE_REVISION="${SOURCE_REVISION:-main}"
SOURCE_PATH="${SOURCE_PATH:-charts/components/spring-boot-lw-poc/app}"
SEED_MOUNT="${SEED_MOUNT:-/seed}"
INCLUDE_OSV_EVAL="${INCLUDE_OSV_EVAL:-true}"
OVERLAY_PREFIX="${OVERLAY_PREFIX:-overlay}"

# GitHub keeps lab manifests as *.example so Dependabot does not bump scored
# pins (Maven commons-lang3 3.14.0 / PyPI httpx==0.27.2). Student Gitea must
# have pom.xml or requirements.txt at the repository root.
promote_lab_manifest_examples() {
  local root="${1}"
  if [[ -f "${root}/pom.xml.example" ]]; then
    mv -f "${root}/pom.xml.example" "${root}/pom.xml"
  fi
  if [[ -f "${root}/requirements.txt.example" ]]; then
    mv -f "${root}/requirements.txt.example" "${root}/requirements.txt"
  fi
}

require_student_manifest() {
  local root="${1}"
  if [[ "${OVERLAY_PREFIX}" == overlay-python* ]]; then
    if [[ ! -f "${root}/requirements.txt" ]]; then
      echo "ERROR: assembled Python tree has no requirements.txt (expected requirements.txt.example in workshop clone)" >&2
      exit 1
    fi
  elif [[ ! -f "${root}/pom.xml" ]]; then
    echo "ERROR: assembled tree has no pom.xml (expected pom.xml.example in workshop clone)" >&2
    exit 1
  fi
}

copy_embedded_fallback() {
  echo "WARNING: using embedded fallback tree (pom/README only) — set SOURCE_REPO_URL for live isolation" >&2
  cp "${SEED_MOUNT}/repo-README.md" "${ROOT}/README.md"
  cp "${SEED_MOUNT}/repo-pom.xml" "${ROOT}/pom.xml"
  cp "${SEED_MOUNT}/repo-gitignore" "${ROOT}/.gitignore"
}

isolate_from_git() {
  if [[ -z "${SOURCE_REPO_URL}" ]]; then
    echo "ERROR: SOURCE_MODE=live requires SOURCE_REPO_URL (workshop GitOps URL for operators — not a learner step)" >&2
    exit 1
  fi

  local clone_dir
  clone_dir="$(mktemp -d)"
  echo "Cloning ${SOURCE_REPO_URL} @ ${SOURCE_REVISION} (operator seed only) ..."
  # Optional Basic auth via SOURCE_GIT_USERNAME / SOURCE_GIT_PASSWORD from a Secret
  # (never commit credentials). Public repos leave these unset.
  local url="${SOURCE_REPO_URL}"
  if [[ -n "${SOURCE_GIT_USERNAME:-}" && -n "${SOURCE_GIT_PASSWORD:-}" ]]; then
    local hostpath="${SOURCE_REPO_URL#https://}"
    hostpath="${hostpath#http://}"
    url="https://${SOURCE_GIT_USERNAME}:${SOURCE_GIT_PASSWORD}@${hostpath}"
  fi

  git init -q "${clone_dir}/src"
  git -C "${clone_dir}/src" remote add origin "${url}"
  GIT_TERMINAL_PROMPT=0 git -C "${clone_dir}/src" -c http.sslVerify="${SOURCE_GIT_SSL_VERIFY:-true}" \
    fetch --depth 1 origin "${SOURCE_REVISION}"
  git -C "${clone_dir}/src" checkout -q --detach FETCH_HEAD
  printf 'Workshop source resolved revision: '
  git -C "${clone_dir}/src" rev-parse HEAD

  local src="${clone_dir}/src/${SOURCE_PATH}"
  if [[ ! -d "${src}" ]]; then
    echo "ERROR: source path not found in clone: ${SOURCE_PATH}" >&2
    exit 1
  fi

  echo "Isolating ${SOURCE_PATH} → student repo root"
  cp -a "${src}/." "${ROOT}/"

  # Module 3 OSV helpers/fixtures — Java only; keep under tools/ so learners never clone the monorepo.
  if [[ "${INCLUDE_OSV_EVAL}" == "true" ]]; then
    local osv="${clone_dir}/src/tools/osv-eval"
    if [[ -d "${osv}" ]]; then
      echo "Including tools/osv-eval for Module 3"
      mkdir -p "${ROOT}/tools"
      cp -a "${osv}" "${ROOT}/tools/osv-eval"
    else
      echo "WARNING: tools/osv-eval missing from workshop clone — Module 3 fixture helpers will be absent" >&2
    fi
  fi

  # Prefer workshop student README when overlay provides one; else keep app README if any.
  rm -rf "${clone_dir}"
}

apply_overlay() {
  # ConfigMap mount is flat keys (see seed-configmap.yaml) — rebuild lab paths here.
  echo "Applying lab overlay (${OVERLAY_PREFIX}: .tekton + student README + Renovate pins)"
  mkdir -p "${ROOT}/.tekton"
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-README.md" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-README.md" "${ROOT}/README.md"
  fi
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-pipeline.yaml" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-pipeline.yaml" "${ROOT}/.tekton/pipeline.yaml"
  fi
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-pipelinerun.yaml" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-pipelinerun.yaml" "${ROOT}/.tekton/pipelinerun.yaml"
  fi
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-rbac.yaml" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-tekton-rbac.yaml" "${ROOT}/.tekton/rbac.yaml"
  fi
  # V2-24 — Java app only (overlay-*, not overlay-python-*). Stale pins for the live bot.
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-renovate.json" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-renovate.json" "${ROOT}/renovate.json"
  fi
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-lightwell-pins.properties" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-lightwell-pins.properties" "${ROOT}/lightwell-pins.properties"
  fi
  # V2-53 known-bad leftover (4.1 / 4.4). Keep in git; never the BuildConfig Dockerfile.
  if [[ -f "${SEED_MOUNT}/${OVERLAY_PREFIX}-Dockerfile.known-bad" ]]; then
    cp "${SEED_MOUNT}/${OVERLAY_PREFIX}-Dockerfile.known-bad" "${ROOT}/Dockerfile.known-bad"
  fi
}

case "${SOURCE_MODE}" in
  live)
    isolate_from_git
    promote_lab_manifest_examples "${ROOT}"
    require_student_manifest "${ROOT}"
    ;;
  embedded)
    if [[ "${OVERLAY_PREFIX}" != "overlay" ]]; then
      echo "ERROR: embedded fallback is Java-only; Python seed requires SOURCE_MODE=live" >&2
      exit 1
    fi
    copy_embedded_fallback
    ;;
  *)
    echo "ERROR: unknown SOURCE_MODE=${SOURCE_MODE} (use live|embedded)" >&2
    exit 1
    ;;
esac

apply_overlay

# Ensure a student-facing README exists
if [[ ! -f "${ROOT}/README.md" && -f "${SEED_MOUNT}/repo-README.md" ]]; then
  cp "${SEED_MOUNT}/repo-README.md" "${ROOT}/README.md"
fi

echo "Assembled student repo at ${ROOT}:"
find "${ROOT}" -maxdepth 3 -type f | sort | head -80
