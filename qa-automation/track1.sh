#!/usr/bin/env bash
# Run inside Showroom after completing ~/track-1/inventory.yml and mirror-base.yml.
# This writes the lab registry and Track 1 report. Use an allocated test claim.
set -euo pipefail
export PATH="$HOME/.venvs/track1/bin:$PATH"
cd "${TRACK1_DIR:-$HOME/track-1}"
mkdir -p qa-evidence
status() { oc -n lw-poc-validate get cm report-02-hummingbird-mirror -o jsonpath='{.data.status}'; }
destination() { oc -n lw-poc-validate get cm report-02-hummingbird-mirror -o jsonpath='{.data.destination_pullspec}'; }
expect_source_failure() {
  local label="$1" key="$2"
  if ansible-playbook -i inventory.yml mirror-base.yml -e "verification_key=$key" > "qa-evidence/$label.log" 2>&1; then
    echo "FAIL: $label unexpectedly succeeded" >&2; exit 1
  fi
  grep -q 'TASK \[Verify the published index before copying anything\]' "qa-evidence/$label.log"
  if grep -q 'TASK \[Mirror the pinned image' "qa-evidence/$label.log"; then
    echo "FAIL: copying ran after a failed source verification" >&2; exit 1
  fi
  test "$(status)" = failed
  test -z "$(destination)"
  echo "PASS: $label stops copying and clears the destination"
}
ansible-playbook -i inventory.yml mirror-base.yml --syntax-check
ansible -i inventory.yml bastion -m ansible.builtin.ping
expect_source_failure missing-key /nonexistent/track1-negative-test.pub
# Generate a real but incorrect public key. Its private key never leaves Showroom.
python3 - <<'PY'
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
from pathlib import Path
key=ec.generate_private_key(ec.SECP256R1())
Path('qa-evidence/wrong-key.pub').write_bytes(key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
PY
ansible -i inventory.yml bastion -m ansible.builtin.copy -a "src=$PWD/qa-evidence/wrong-key.pub dest=/tmp/track1-qa-wrong-key.pub mode=0600"
expect_source_failure wrong-key /tmp/track1-qa-wrong-key.pub
ansible-playbook -i inventory.yml mirror-base.yml > qa-evidence/positive.log 2>&1
test "$(status)" = verified
test -n "$(destination)"
echo 'PASS: complete workflow publishes a verified destination'
# Prove a subsequent failed attempt cannot reuse the successful destination.
expect_source_failure stale-success /tmp/track1-qa-wrong-key.pub
ansible-playbook -i inventory.yml mirror-base.yml > qa-evidence/rerun.log 2>&1
test "$(status)" = verified
oc -n lw-poc-validate delete job validate-02-hummingbird-mirror --ignore-not-found
oc -n lw-poc-validate get cm validate-job-templates -o go-template='{{ index .data "job-02.yaml" }}' | oc create -f -
oc -n lw-poc-validate wait --for=condition=complete job/validate-02-hummingbird-mirror --timeout=240s
oc -n lw-poc-validate logs job/validate-02-hummingbird-mirror -c check | tee qa-evidence/validator.log
grep -q 'CHECK PASSED:' qa-evidence/validator.log
ansible -i inventory.yml bastion -m ansible.builtin.file -a 'path=/tmp/track1-qa-wrong-key.pub state=absent'
echo 'PASS: rerun and independent cryptographic assessment'
