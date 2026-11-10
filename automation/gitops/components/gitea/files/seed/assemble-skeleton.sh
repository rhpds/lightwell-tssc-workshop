#!/usr/bin/env bash
# Isolate RHDH Software Template skeleton into a Gitea template repo root.
# Operators clone the workshop GitOps URL; learners / RHDH fetch from workshop-templates.
set -euo pipefail

ROOT="${1:-/tmp/gitea-seed/skeleton}"
mkdir -p "${ROOT}"

SOURCE_MODE="${SOURCE_MODE:-live}"
SOURCE_REPO_URL="${SOURCE_REPO_URL:-}"
SOURCE_REVISION="${SOURCE_REVISION:-main}"
SKELETON_PATH="${SKELETON_PATH:-charts/components/rhdh/files/skeletons/lightwell-java-service}"
SEED_MOUNT="${SEED_MOUNT:-/seed}"

if [[ "${SOURCE_MODE}" != "live" ]]; then
  echo "WARNING: skeleton assemble requires SOURCE_MODE=live (skipping)" >&2
  exit 0
fi

if [[ -z "${SOURCE_REPO_URL}" ]]; then
  echo "ERROR: assemble-skeleton requires SOURCE_REPO_URL" >&2
  exit 1
fi

clone_dir="$(mktemp -d)"
trap 'rm -rf "${clone_dir}"' EXIT

echo "Cloning ${SOURCE_REPO_URL} @ ${SOURCE_REVISION} for RHDH skeleton (operator seed only) ..."
url="${SOURCE_REPO_URL}"
if [[ -n "${SOURCE_GIT_USERNAME:-}" && -n "${SOURCE_GIT_PASSWORD:-}" ]]; then
  hostpath="${SOURCE_REPO_URL#https://}"
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

src="${clone_dir}/src/${SKELETON_PATH}"
if [[ ! -d "${src}" ]]; then
  echo "ERROR: skeleton path not found: ${SKELETON_PATH}" >&2
  exit 1
fi

echo "Isolating ${SKELETON_PATH} → template skeleton repo root"
cp -a "${src}/." "${ROOT}/"

# GitHub keeps lab manifests as *.example so Dependabot does not bump scored
# pins. RHDH fetch:template needs pom.xml (Java) or requirements.txt (Python).
if [[ -f "${ROOT}/pom.xml.example" ]]; then
  mv -f "${ROOT}/pom.xml.example" "${ROOT}/pom.xml"
fi
if [[ -f "${ROOT}/requirements.txt.example" ]]; then
  mv -f "${ROOT}/requirements.txt.example" "${ROOT}/requirements.txt"
fi
if [[ ! -f "${ROOT}/pom.xml" && ! -f "${ROOT}/requirements.txt" ]]; then
  echo "ERROR: assembled skeleton has neither pom.xml nor requirements.txt (expected *.example in workshop clone)" >&2
  exit 1
fi

# Use the same exercise inputs as the prepared Java app. Keep a single source
# for pins, known-bad fixture, and pipeline so Track 3/4 behavior cannot diverge.
# Python skeletons do not receive the Java overlay.
if [[ -f "${ROOT}/pom.xml" ]]; then
  mkdir -p "${ROOT}/.tekton"
  for mapping in \
    'overlay-renovate.json:renovate.json' \
    'overlay-lightwell-pins.properties:lightwell-pins.properties' \
    'overlay-Dockerfile.known-bad:Dockerfile.known-bad' \
    'overlay-tekton-pipeline.yaml:.tekton/pipeline.yaml' \
    'overlay-tekton-pipelinerun.yaml:.tekton/pipelinerun.yaml' \
    'overlay-tekton-rbac.yaml:.tekton/rbac.yaml'; do
    source_file="${SEED_MOUNT}/${mapping%%:*}"
    [[ -f "$source_file" ]] || { echo "ERROR: missing Java exercise overlay $source_file" >&2; exit 1; }
    cp "$source_file" "${ROOT}/${mapping#*:}"
  done
fi

echo "Assembled RHDH skeleton at ${ROOT}:"
find "${ROOT}" -maxdepth 3 -type f | sort | head -40
