#!/usr/bin/env bash
# Read learner TrustPolicy from Gitea GitOps and apply ImagePolicy (or Kyverno).
# Seed stays broken: enforce false / REPLACE_ME → do not apply a live gate.
#
# OpenShift ImagePolicy fulcioSubject.signedEmail must be an RFC email. Track 5.1
# Fulcio identity is a Kubernetes SA URI, so URI subjects render PublicKey from
# ConfigMap lab-cosign-pubkey (Track 5.3 cosign.pub). Email subjects still use
# FulcioCAWithRekor. oc tag remaps the repo: signedIdentity is ExactRepository
# to the build ImageStream (SIGNED_IMAGE_REPO).
set -euo pipefail

if ! command -v oc >/dev/null 2>&1; then
  curl -fsSL -o /tmp/oc.tgz \
    https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz
  tar -C /usr/local/bin -xzf /tmp/oc.tgz oc
fi
if ! command -v git >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import yaml" 2>/dev/null; then
  dnf install -y -q git python3 python3-pyyaml && dnf clean all
fi

resolve_backend() {
  case "${BACKEND}" in
    imagepolicy|kyverno)
      echo "${BACKEND}"
      return
      ;;
    auto)
      if oc get crd imagepolicies.config.openshift.io >/dev/null 2>&1; then
        echo imagepolicy
        return
      fi
      if oc get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
        echo kyverno
        return
      fi
      echo "ImagePolicy CRD missing and Kyverno is not installed." >&2
      echo "Do not enable TechPreviewNoUpgrade. Install Kyverno only if native ImagePolicy is unusable, then set admission.backend=kyverno." >&2
      exit 0
      ;;
    *)
      echo "Unknown BACKEND=${BACKEND}" >&2
      exit 1
      ;;
  esac
}

delete_gates() {
  local backend="$1"
  if [[ "${backend}" == imagepolicy ]]; then
    for ns in "${STAGE_NAMESPACE}" "${PROD_NAMESPACE}"; do
      oc -n "${ns}" delete imagepolicy "${POLICY_NAME}" --ignore-not-found 2>/dev/null || true
    done
  else
    oc delete clusterpolicy "${POLICY_NAME}" --ignore-not-found 2>/dev/null || true
  fi
}

GITOPS_URL="${GITOPS_REPO_URL:-}"
GITOPS_USER=""
GITOPS_PASS=""
if [[ -z "${GITOPS_URL}" ]] && oc -n "${GITEA_NAMESPACE}" get configmap "${GITEA_LAB_CONFIG_CM}" >/dev/null 2>&1; then
  GITOPS_URL="$(oc -n "${GITEA_NAMESPACE}" get configmap "${GITEA_LAB_CONFIG_CM}" -o jsonpath='{.data.student_gitops_repo_url}')"
  GITOPS_USER="$(oc -n "${GITEA_NAMESPACE}" get configmap "${GITEA_LAB_CONFIG_CM}" -o jsonpath='{.data.student_username}')"
  GITOPS_PASS="$(oc -n "${GITEA_NAMESPACE}" get configmap "${GITEA_LAB_CONFIG_CM}" -o jsonpath='{.data.student_password}')"
fi

if [[ -z "${GITOPS_URL}" ]]; then
  echo "GitOps repo URL not ready (ConfigMap lab-gitea missing) — skip"
  exit 0
fi

CLONE_URL="${GITOPS_URL}"
if [[ -n "${GITOPS_USER}" && -n "${GITOPS_PASS}" ]]; then
  hostpath="${GITOPS_URL#https://}"
  hostpath="${hostpath#http://}"
  CLONE_URL="https://${GITOPS_USER}:${GITOPS_PASS}@${hostpath}"
fi

WORKDIR=/tmp/gitops
rm -rf "${WORKDIR}"
if ! GIT_TERMINAL_PROMPT=0 git -c http.sslVerify=false clone --depth 1 "${CLONE_URL}" "${WORKDIR}" 2>/tmp/git-clone.err; then
  echo "GitOps clone failed (repo may not exist yet):"
  cat /tmp/git-clone.err
  exit 0
fi

POLICY_FILE="${WORKDIR}/${GITOPS_REPO_PATH}"
BACKEND_RESOLVED="$(resolve_backend)"

if [[ ! -f "${POLICY_FILE}" ]]; then
  echo "No ${GITOPS_REPO_PATH} in GitOps repo — skip"
  delete_gates "${BACKEND_RESOLVED}"
  exit 0
fi

export POLICY_FILE STAGE_NAMESPACE PROD_NAMESPACE POLICY_NAME BACKEND_RESOLVED
export TUF_SECRET_NAME ADMISSION_NAMESPACE REKOR_URL_HINT
export COSIGN_PUB_CM="${COSIGN_PUB_CM:-lab-cosign-pubkey}"
export SIGNED_IMAGE_REPO="${SIGNED_IMAGE_REPO:-}"
python3 - <<'PY'
import os, re, subprocess, sys, base64, json, yaml

path = os.environ["POLICY_FILE"]
policy_name = os.environ["POLICY_NAME"]
stage = os.environ["STAGE_NAMESPACE"]
prod = os.environ["PROD_NAMESPACE"]
backend = os.environ["BACKEND_RESOLVED"]
secret_name = os.environ["TUF_SECRET_NAME"]
adm_ns = os.environ["ADMISSION_NAMESPACE"]
rekor_url = os.environ.get("REKOR_URL_HINT") or ""
pubkey_cm = os.environ.get("COSIGN_PUB_CM") or "lab-cosign-pubkey"
signed_repo = (os.environ.get("SIGNED_IMAGE_REPO") or "").strip()

def run(cmd, check=True):
    return subprocess.run(cmd, check=check, capture_output=True, text=True)

with open(path) as f:
    doc = yaml.safe_load(f) or {}

spec = doc.get("spec") or {}
identity = spec.get("identity") or {}
enforce = spec.get("enforce")
scopes = spec.get("scopes") or []
issuer = str(identity.get("issuer") or "").strip()
subject = str(identity.get("subject") or "").strip()
digest = str(spec.get("digest") or "").strip()

blob = open(path).read()
placeholder = "REPLACE_ME" in blob
digest_ok = bool(re.fullmatch(r"sha256:[0-9a-f]{64}", digest))
ready = (
    enforce is True
    and not placeholder
    and issuer
    and subject
    and scopes
    and digest_ok
)

def delete_gates():
    if backend == "imagepolicy":
        for ns in (stage, prod):
            run(["oc", "-n", ns, "delete", "imagepolicy", policy_name, "--ignore-not-found"], check=False)
    else:
        run(["oc", "delete", "clusterpolicy", policy_name, "--ignore-not-found"], check=False)

if not ready:
    print("TrustPolicy not ready (enforce/placeholders/digest) — live gate stays off")
    delete_gates()
    sys.exit(0)

email_ok = bool(re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", subject))

all_scopes = []
for raw in scopes:
    s = str(raw).strip()
    if not s:
        continue
    if s not in all_scopes:
        all_scopes.append(s)
    if "@" not in s:
        pinned = f"{s}@{digest}"
        if pinned not in all_scopes:
            all_scopes.append(pinned)

def q(value):
    return json.dumps(value)

def ensure_ns(ns):
    run(["oc", "create", "namespace", ns], check=False)

def signed_identity_yaml():
    if signed_repo:
        return f"""    signedIdentity:
      matchPolicy: ExactRepository
      exactRepository:
        repository: {q(signed_repo)}
"""
    return """    signedIdentity:
      matchPolicy: MatchRepoDigestOrExact
"""

if backend == "imagepolicy":
    if email_ok:
        sec = run(["oc", "-n", adm_ns, "get", "secret", secret_name, "-o", "json"])
        data = json.loads(sec.stdout).get("data") or {}
        fulcio_pem = base64.b64decode(data["fulcio_v1.crt.pem"]).decode()
        rekor_pem = base64.b64decode(data["rekor.pub"]).decode()
        fulcio_b64 = base64.b64encode(fulcio_pem.encode()).decode()
        rekor_b64 = base64.b64encode(rekor_pem.encode()).decode()
        root = f"""    rootOfTrust:
      policyType: FulcioCAWithRekor
      fulcioCAWithRekor:
        fulcioCAData: {fulcio_b64}
        fulcioSubject:
          oidcIssuer: {q(issuer)}
          signedEmail: {q(subject)}
        rekorKeyData: {rekor_b64}
"""
        print("Rendering ImagePolicy FulcioCAWithRekor (subject is an email)")
    else:
        cm = run(["oc", "-n", adm_ns, "get", "configmap", pubkey_cm, "-o", "json"], check=False)
        if cm.returncode != 0:
            print(
                f"TrustPolicy subject is a URI (not an ImagePolicy signedEmail). "
                f"Publish Track 5.3 ~/lab-trust/cosign.pub to ConfigMap {adm_ns}/{pubkey_cm}.",
                file=sys.stderr,
            )
            sys.exit(1)
        cm_data = json.loads(cm.stdout).get("data") or {}
        pub = cm_data.get("cosign.pub") or ""
        if not pub.strip() or "REPLACE_ME" in pub or "BEGIN PUBLIC KEY" not in pub:
            print(
                f"ConfigMap {adm_ns}/{pubkey_cm} key cosign.pub is empty or still a placeholder. "
                "oc apply --from-file=cosign.pub=$HOME/lab-trust/cosign.pub (Track 5.3).",
                file=sys.stderr,
            )
            sys.exit(1)
        key_b64 = base64.b64encode(pub.encode()).decode()
        root = f"""    rootOfTrust:
      policyType: PublicKey
      publicKey:
        keyData: {key_b64}
"""
        print(
            "Rendering ImagePolicy PublicKey from lab-cosign-pubkey "
            "(signedEmail cannot hold the pipeline SA URI)"
        )

    for ns in (stage, prod):
        ensure_ns(ns)
        body = f"""apiVersion: config.openshift.io/v1
kind: ImagePolicy
metadata:
  name: {policy_name}
  namespace: {ns}
spec:
  scopes:
{chr(10).join('    - ' + q(s) for s in all_scopes)}
  policy:
{root}{signed_identity_yaml()}"""
        apply = subprocess.run(["oc", "apply", "-f", "-"], input=body, text=True, capture_output=True)
        sys.stdout.write(apply.stdout)
        sys.stderr.write(apply.stderr)
        if apply.returncode != 0:
            sys.exit(apply.returncode)
    print(f"Applied ImagePolicy {policy_name} in {stage} and {prod}")
else:
    refs = "\n".join("            - " + q(s + "*" if "@" not in s else s) for s in all_scopes)
    body = f"""apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: {policy_name}
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-signed-image
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [{q(stage)}, {q(prod)}]
      verifyImages:
        - imageReferences:
{refs}
          attestors:
            - entries:
                - keyless:
                    issuer: {q(issuer)}
                    subject: {q(subject)}
                    rekor:
                      url: {q(rekor_url or 'http://rekor-server.trusted-artifact-signer.svc')}
          mutateDigest: false
          required: true
"""
    apply = subprocess.run(["oc", "apply", "-f", "-"], input=body, text=True, capture_output=True)
    sys.stdout.write(apply.stdout)
    sys.stderr.write(apply.stderr)
    if apply.returncode != 0:
        sys.exit(apply.returncode)
    print(f"Applied Kyverno ClusterPolicy {policy_name}")
PY
