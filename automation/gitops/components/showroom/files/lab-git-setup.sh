#!/usr/bin/env bash
# Showroom terminal: git author + Gitea HTTPS credentials so `git commit` /
# `git push origin HEAD` work without a TTY (#77). Never print the password.
set -u
HOME="${HOME:-/home/lab-user}"
export HOME
mkdir -p "$HOME"
ok() { echo "lab-git-setup: $*" >&2; }
warn() { echo "lab-git-setup: WARN: $*" >&2; }

if ! command -v git >/dev/null 2>&1; then
  warn "git not on PATH; skip"
  exit 0
fi

git config --global user.name student
git config --global user.email student@workshop.local
git config --global credential.helper store

if ! command -v oc >/dev/null 2>&1; then
  warn "oc not on PATH; git author is set, Gitea credentials skipped"
  exit 0
fi

student_user=""
student_pass=""
gitea_url=""
i=0
while [ "$i" -lt 15 ]; do
  student_user="$(oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_username}' 2>/dev/null || true)"
  student_pass="$(oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_password}' 2>/dev/null || true)"
  gitea_url="$(oc -n gitea get configmap lab-gitea -o jsonpath='{.data.gitea_url}' 2>/dev/null || true)"
  if [ -n "$student_user" ] && [ -n "$student_pass" ] && [ -n "$gitea_url" ]; then
    break
  fi
  i=$((i + 1))
  sleep 2
done
if [ -z "$student_user" ] || [ -z "$student_pass" ] || [ -z "$gitea_url" ]; then
  warn "lab-gitea not readable; git author is set, push will need the 3.2 fallback"
  exit 0
fi

host="${gitea_url#https://}"
host="${host#http://}"
host="${host%/}"

# Credential protocol (not a URL) so git encodes special characters itself.
if ! printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' \
  "$host" "$student_user" "$student_pass" | git credential approve; then
  warn "git credential approve failed; push will need the 3.2 fallback"
  exit 0
fi

if [ "$(id -u 2>/dev/null || echo 0)" = "0" ]; then
  chown 1000:1000 "$HOME/.gitconfig" "$HOME/.git-credentials" 2>/dev/null || true
fi

ok "git author=student; Gitea HTTPS credentials stored for ${host}"
exit 0
