# V2-2 Spike: portable admission

**Status:** closed (spike report). Implement in [V2-16](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/9).
**Date:** 2026-08-17
**Issue:** [V2-2](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/2)
**Does not change** `publishing-house/spec.yaml` until you explicitly apply v2.

Learner edits **one** trust-policy file. A chart renders the live gate. Do not put `kind: ClusterImagePolicy` in the scored file.

---

## 1. Decision

| Choice | Resolution |
|--------|------------|
| Scored object the learner edits | Portable `TrustPolicy` YAML (workshop schema). Seeded broken. |
| Live gate (default) | Namespaced OpenShift **`ImagePolicy`** (`config.openshift.io/v1`) in the app namespace and the prod namespace |
| Not the scored CR | **`ClusterImagePolicy`** — cluster-wide; `openshift*` names reserved; a broad `scopes` entry can brick pulls |
| 4.20 fallback | **Kyverno** `verifyImages` (keyless issuer + subject), only if the `ImagePolicy` CRD is missing **or** MCO node drain makes the native path unusable on a CNV claim |
| Not this gate | **RHACS** admission — Cosign **public keys** only; cannot match RHTAS Fulcio / OIDC identity from Track 5.1 |
| Feature gates | **Do not** set `TechPreviewNoUpgrade`. Custom ImagePolicy is GA with “sigstore support” in **4.20**; the default `openshift` ClusterImagePolicy is TP on 4.20 and GA on 4.21 |
| Catalog OCP | Q8 stays **4.20 now / 4.21 when the item can move**. V2-1 already saw **4.21.27** on a v1 CNV claim — native CRDs will be there on that topology |

ASK Q8 (“Kyverno/RHACS now, ClusterImagePolicy later”) is kept as the *portability* requirement: same learner fields, backend may change. This spike picks the backends that actually match **keyless RHTAS**.

---

## 2. Why not RHACS for Track 6.1

RHACS “Trusted image signers” verifies Cosign **public keys**. Track 5.1 is **keyless** (RHTAS Fulcio, issuer `https://kubernetes.default.svc`). There is no RHACS policy criterion for Fulcio `oidcIssuer` + subject.

Leave RHACS for Track 7 (runtime / ACS control). Keep `securedCluster.admissionControl.listenOnCreates` as it is.

---

## 3. Native ImagePolicy vs Kyverno

### 3.1 Prefer ImagePolicy (Red Hat, no extra operator)

OpenShift 4.20 feature table: **sigstore support = GA**; default `openshift` ClusterImagePolicy stays TP until 4.21. Creating a **custom** `ImagePolicy` / `ClusterImagePolicy` (PublicKey or FulcioCAWithRekor) does **not** require `TechPreviewNoUpgrade`. BYOPKI (`policyType: PKI`) is the path that still needed a feature gate on 4.20 — the lab does not use it.

`ImagePolicy` is **namespace-scoped**. That matches Track 6 (stage app-ns + prod-ns) and cannot override cluster `openshift` release scopes.

Enforcement is **CRI-O / `policy.json`**, not a Kubernetes admission webhook. `oc apply` of an unsigned Deployment can succeed; the pod fails at **pull** (signature verification). The Check must look at pod phase / events, not only apply stderr.

MCO writes `/etc/crio/policies/<ns>.json` and `registries.d/sigstore-registries.yaml`. Docs say MCP scheduling is disabled while that applies. **V2-16 must time this on a CNV claim** (V2-1 topology). If a learner `enforce: true` apply drains workers for minutes or knocks Showroom over, switch the live gate to Kyverno and keep ImagePolicy as an inspect-only render.

### 3.2 Kyverno only as fallback

Kyverno `verifyImages` + `keyless.issuer` / `keyless.subject` maps the same learner fields and denies at **admission** (cleaner `oc apply` fail). It is a **community** operator, not a catalog product. Do not install it unless native ImagePolicy is missing or MCO-cost fails the timing test.

Helm value: `admission.backend: auto | imagepolicy | kyverno`.

`auto` = ImagePolicy CRD present → native; else Kyverno.

---

## 4. Learner file (scored)

Seed in the **stage GitOps repo** (learner-owned, not the workshop monorepo), path:

`admission/trust-policy.yaml`

Worked example in Showroom must use a **different** path or truncated snippet (Q: examples not paste-identical).

### 4.1 Schema

```yaml
# Seeded incomplete. Do not change apiVersion/kind.
apiVersion: tssc.workshop/v1
kind: TrustPolicy
metadata:
  name: prod-admission
spec:
  # Seeded disabled. Check requires true after identity is filled.
  enforce: false
  # Registry/repo the gate applies to (internal dest from Track 1 / app build).
  scopes:
    - REPLACE_ME_REGISTRY/REPLACE_ME_REPO
  identity:
    # Must match the Fulcio OIDC issuer used at sign time (Track 5.1).
    issuer: REPLACE_ME_OIDC_ISSUER
    # Fulcio subject. ImagePolicy field name is signedEmail; value may be an SA URI.
    subject: REPLACE_ME_IDENTITY
  # Signed app digest the learner recorded in Track 5 (sha256:…).
  digest: sha256:REPLACE_ME
  signedIdentity:
    matchPolicy: MatchRepoDigestOrExact
```

### 4.2 What the learner must change (Track 6.1)

| Seeded defect | Pass when |
|---------------|-----------|
| `enforce: false` | `true` |
| `REPLACE_ME_OIDC_ISSUER` | Real issuer from ConfigMap `lab-admission` / `oc get securesign` (lab default `https://kubernetes.default.svc`) |
| `REPLACE_ME_IDENTITY` | Subject of the keyless signature (not the Showroom example string) |
| `sha256:REPLACE_ME` | Digest they signed in 5.1 (same digest GitOps will promote) |
| `REPLACE_ME_REGISTRY/REPLACE_ME_REPO` | Internal repo that stage/prod actually pull |

### 4.3 What the chart injects (not learner-edited)

| Field | Source |
|-------|--------|
| `fulcioCAData` | RHTAS TUF `fulcio_v1.crt.pem` (base64) |
| `rekorKeyData` | RHTAS TUF `rekor.pub` (base64) |
| Target namespaces | app (stage) + prod |
| `policyType` | `FulcioCAWithRekor` |

Do not ask learners to paste PEMs.

### 4.4 Placeholders the Check rejects

Any remaining `REPLACE_ME`, empty `identity.issuer` / `identity.subject`, `enforce: false`, or digest that is not `sha256:[0-9a-f]{64}`.

---

## 5. Field map (same edit → active API)

| TrustPolicy | ImagePolicy / ClusterImagePolicy | Kyverno `verifyImages` |
|-------------|----------------------------------|-------------------------|
| `spec.scopes[]` | `spec.scopes[]` | `imageReferences[]` |
| `spec.identity.issuer` | `spec.policy.rootOfTrust.fulcioCAWithRekor.fulcioSubject.oidcIssuer` | `attestors[].entries[].keyless.issuer` |
| `spec.identity.subject` | `…fulcioSubject.signedEmail` | `attestors[].entries[].keyless.subject` |
| `spec.digest` | Include digest-pinned pull spec in `scopes` **or** Check vs GitOps `image.digest` (preferred: both) | Digest in `imageReferences` |
| `spec.enforce` | `true` → create/patch ImagePolicy; `false` → do not apply (or delete) | `failureAction: Enforce` vs omit/Audit |
| `spec.signedIdentity.matchPolicy` | `spec.policy.signedIdentity.matchPolicy` | (Kyverno uses repo match via `imageReferences`; no remap unless added later) |
| (chart) Fulcio CA + Rekor | `fulcioCAData` + `rekorKeyData` | `keyless.rekor.url` = in-cluster Rekor; optional Rekor key |

Do **not** render `ClusterImagePolicy` for the scored namespaces. Optional inspect-only copy in content may show a ClusterImagePolicy **snippet** with the same four learner fields, on a different filename.

### 5.1 Rendered ImagePolicy (chart, not scored)

```yaml
apiVersion: config.openshift.io/v1
kind: ImagePolicy
metadata:
  name: tssc-prod-admission   # never openshift*
  namespace: <app-or-prod-ns>
spec:
  scopes:
    - <trust-policy.spec.scopes[0]>
  policy:
    rootOfTrust:
      policyType: FulcioCAWithRekor
      fulcioCAWithRekor:
        fulcioCAData: <from RHTAS>
        fulcioSubject:
          oidcIssuer: <trust-policy.spec.identity.issuer>
          signedEmail: <trust-policy.spec.identity.subject>
        rekorKeyData: <from RHTAS>
    signedIdentity:
      matchPolicy: MatchRepoDigestOrExact
```

Create one object per gated namespace (stage + prod). Prod Check is still “unsigned deny” plus 6.2’s prod GitOps remote.

---

## 6. Chart shape (V2-16)

New component `automation/gitops/components/admission/` at bootstrap wave **10** (with RHTAS / RHACS). Needs Fulcio/Rekor material from the RHTAS chart — sequence: RHTAS Ready, then a Job copies TUF keys into a Secret the admission chart mounts.

| Piece | Role |
|-------|------|
| Seed `admission/trust-policy.yaml` in Gitea GitOps overlay | Learner file; `enforce: false` |
| Controller or Argo-synced Job | Reads Gitea file; if `enforce: true` and placeholders gone, applies ImagePolicy (or Kyverno) |
| ConfigMap `lab-admission` | Expected issuer hint, Rekor/Fulcio URLs, “how to run unsigned deny” |
| **No Solve** | Broken policy stays broken |

Do not apply a correct ImagePolicy at provision. Seed must fail the 6.1 Check on a fresh claim.

---

## 7. Check (Track 6.1) — for V2-54 later

Live state:

1. Committed `trust-policy.yaml` has `enforce: true` and no `REPLACE_ME`.
2. `identity.issuer` / `identity.subject` are not the Showroom example strings.
3. `digest` equals the signed app digest in GitOps values (or the learner report).
4. ImagePolicy (or Kyverno ClusterPolicy) exists in app-ns **and** prod-ns with those identity fields.
5. Unsigned image in `scopes` does **not** run (ImagePullBackOff / signature error, or Kyverno admit deny).
6. Signed digest **can** run (after 6.2 promote; 6.1 may only prove unsigned deny).

Quiz keys (V2-59): why admission exists in a SoW; webhook vs CRI-O `policy.json` — allowed tokens, not an essay.

Teaching fail: “Admission is still off (`enforce: false`)” / “Issuer is still the placeholder” — not an Ansible trace.

---

## 8. Risks for V2-16

| Risk | Mitigation |
|------|------------|
| ImagePolicy apply drains MCP | Time it on CNV. If too slow, `backend: kyverno`. Do not enable `TechPreviewNoUpgrade`. |
| `signedEmail` vs Kubernetes SA URI | ImagePolicy `signedEmail` is an RFC email. 5.1 identity is a SA URI, so the CronJob renders `PublicKey` from ConfigMap `lab-cosign-pubkey` (5.3 `cosign.pub`). TrustPolicy.subject stays the URI. |
| Mirror remapping | `oc tag` does not copy `.sig` tags. 6.1/6.2 `cosign copy` onto the dest digest; CronJob sets `ExactRepository` to the build ImageStream. |
| Nested scopes vs cluster `openshift` policy | Keep lab `scopes` on the dest registry host only; never `quay.io/openshift-release-dev/*`. |
| Kyverno as community operator | Catalog talking point: customer 4.21 = ImagePolicy; Kyverno is the lab fallback only. |
| RHACS still listening | Unsigned deny must be attributable to **this** policy in the teaching message, not a Central BUILD policy. |

---

## 9. Unblocks

- [V2-16](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/9) — implement chart + seed
- [V2-36](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/23) — Track 6.1 content (depends on V2-16)
- [V2-22](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/14) — e2e unsigned deny (Phase 5)

---

## 10. Follow-ups (not this spike)

- Live MCO timing on a CNV claim (V2-16 first apply).
- Exact Fulcio subject string from a Track 5.1 signature (V2-16 / V2-35).
- `spec.yaml` `ocp_version` still 4.20 until you apply v2; native path still valid (custom ImagePolicy GA on 4.20; CNV claims already 4.21).
- Do not list ClusterImagePolicy under `non_ga_products`.
