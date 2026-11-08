#!/usr/bin/env bash
# Run after the Gitea seed has prepared the admin and workshop template org.
# Import only the dependencies subtree from the exact requested workshop Git revision.
set -euo pipefail
: "${SOURCE_REPO_URL:?Workshop Git URL is required}"
: "${SOURCE_REVISION:?Workshop Git revision is required}"
: "${GITEA_URL:?}"
: "${ADMIN_USER:?}"
: "${ADMIN_PASSWORD:?}"
: "${TEMPLATES_ORG:=workshop-templates}"
: "${DEFAULT_BRANCH:=main}"
: "${DEPENDENCIES_REPO_NAME:=lightwell-dependencies}"
: "${DEPENDENCIES_SOURCE_PATH:=content/modules/ROOT/examples/lightwell-dependencies}"
export ADMIN_USER ADMIN_PASSWORD SOURCE_REPO_URL SOURCE_REVISION
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_TERMINAL_PROMPT=0
# Askpass reads environment variables; neither Git remote URLs nor logs contain passwords.
cat > "$work/source-askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "${SOURCE_GIT_USERNAME:-}" ;;
  *Password*) printf '%s\n' "${SOURCE_GIT_PASSWORD:-}" ;;
esac
EOF
chmod 700 "$work/source-askpass"
git init -q "$work/source"
git -C "$work/source" remote add origin "$SOURCE_REPO_URL"
GIT_ASKPASS="$work/source-askpass" git -C "$work/source" \
  -c http.sslVerify="${SOURCE_GIT_SSL_VERIFY:-true}" fetch -q --depth=1 origin "$SOURCE_REVISION"
source_commit=$(git -C "$work/source" rev-parse FETCH_HEAD)
mkdir "$work/tree"
git -C "$work/source" archive "${source_commit}:${DEPENDENCIES_SOURCE_PATH}" | tar -x -C "$work/tree"
for file in settings.xml pom.xml README.md .gitignore; do
  test -s "$work/tree/$file" || { echo "Missing dependencies seed file: $file" >&2; exit 1; }
done
mkdir -p "$work/tree/advisories"
git -C "$work/source" show "${source_commit}:automation/gitops/components/lightwell-repo/files/seed/LW-DEMO-0002.json" > "$work/tree/advisories/LW-DEMO-0002.json"
python3 -m json.tool "$work/tree/advisories/LW-DEMO-0002.json" >/dev/null
printf '%s\n' "$source_commit" > "$work/tree/WORKSHOP_REVISION"
# Protected curl config avoids credentials in process arguments.
python3 - "$work/auth" <<'PY'
import base64,os,sys
from pathlib import Path
value=base64.b64encode((os.environ['ADMIN_USER']+':'+os.environ['ADMIN_PASSWORD']).encode()).decode()
Path(sys.argv[1]).write_text('header = "Authorization: Basic '+value+'"\n')
PY
api="${GITEA_URL%/}/api/v1"
for i in $(seq 1 90); do
  if curl -fsS "${GITEA_URL%/}/api/healthz" >/dev/null 2>&1; then break; fi
  if [[ "$i" == 90 ]]; then echo 'Gitea did not become healthy' >&2; exit 1; fi
  sleep 5
done
code=$(curl -sS --config "$work/auth" -o "$work/repo.json" -w '%{http_code}' "$api/repos/$TEMPLATES_ORG/$DEPENDENCIES_REPO_NAME")
case "$code" in
  200) ;;
  404)
    python3 - "$DEPENDENCIES_REPO_NAME" "$DEFAULT_BRANCH" > "$work/create.json" <<'PY'
import json,sys
print(json.dumps({'name':sys.argv[1], 'default_branch':sys.argv[2], 'description':'Track 2: configure Maven and select an exact Lightwell dependency', 'private':False, 'auto_init':False}))
PY
    curl -fsS --config "$work/auth" -H 'Content-Type: application/json' \
      --data-binary @"$work/create.json" "$api/orgs/$TEMPLATES_ORG/repos" > "$work/repo.json"
    ;;
  *) echo "Cannot inspect dependencies repository: HTTP $code" >&2; exit 1 ;;
esac
cat > "$work/target-askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "$ADMIN_USER" ;;
  *Password*) printf '%s\n' "$ADMIN_PASSWORD" ;;
esac
EOF
chmod 700 "$work/target-askpass"
export GIT_ASKPASS="$work/target-askpass"
remote="${GITEA_URL%/}/$TEMPLATES_ORG/$DEPENDENCIES_REPO_NAME.git"
git clone -q "$remote" "$work/target"
if git -C "$work/target" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH"; then
  git -C "$work/target" checkout -q -B "$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"
else
  git -C "$work/target" checkout -q --orphan "$DEFAULT_BRANCH"
fi
# This is an operator-managed seed remote, never a student work repository.
git -C "$work/target" rm -q -r --ignore-unmatch .
cp -a "$work/tree/." "$work/target/"
git -C "$work/target" add .
if ! git -C "$work/target" diff --cached --quiet; then
  git -C "$work/target" -c user.name='Workshop seed' -c user.email='seed@workshop.local' \
    commit -q -m "Seed Lightwell dependencies from workshop $source_commit"
  git -C "$work/target" push -q origin "$DEFAULT_BRANCH"
  echo "Updated $TEMPLATES_ORG/$DEPENDENCIES_REPO_NAME from $source_commit"
else
  echo "Dependencies seed already matches workshop $source_commit"
fi
