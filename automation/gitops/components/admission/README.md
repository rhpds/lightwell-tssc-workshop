# charts/components/admission — Track 6.1 portable trust policy (V2-16)

Learner edits **one** file in the Gitea GitOps repo. A CronJob renders the live
gate. Provision does **not** apply a correct `ImagePolicy`.

## What it deploys

| Resource | Purpose |
|----------|---------|
| Namespace `tssc-admission` | Jobs, scripts, TUF Secret, userinfo |
| Namespace `lw-poc-prod` | Empty prod ns for ImagePolicy; V2-17 adds Application `lw-poc-prod` from the prod GitOps remote |
| Job `rhtas-tuf-copy` | Copies Fulcio CA + Rekor key from RHTAS TUF into Secret `rhtas-tuf-keys` |
| CronJob `trust-policy-apply` | Reads `admission/trust-policy.yaml`; applies ImagePolicy when `enforce: true` |
| ConfigMap `demo-userinfo-admission` | Issuer hint, namespaces, unsigned-deny teaching note |
| ConfigMap `admission-docs` | Worked examples that are **not** paste-identical |

## Scored file vs live gate

| Layer | Kind | Where |
|-------|------|--------|
| Learner edit | `TrustPolicy` (`tssc.workshop/v1`) | Gitea `admission/trust-policy.yaml` |
| Live gate (default) | namespaced `ImagePolicy` | `lw-poc-staging` and `lw-poc-prod` |
| Fallback | Kyverno `ClusterPolicy` | only if ImagePolicy CRD is missing or `admission.backend=kyverno` |
| Not scored | `ClusterImagePolicy` | inspect snippet in `admission-docs` only |
| Not this gate | RHACS Trusted image signers | keyless Fulcio identity is not a public-key match |

Seed is `enforce: false` with `REPLACE_ME_*` placeholders. CronJob deletes any
rendered gate while the file is incomplete. No Solve.

When `identity.subject` is a Kubernetes SA URI (Track 5.1), native ImagePolicy
cannot put that string in `signedEmail`. The CronJob then applies
`policyType: PublicKey` using ConfigMap `lab-cosign-pubkey` (learner publishes
Track 5.3 `cosign.pub`). Email subjects still render `FulcioCAWithRekor`.
`signedIdentity` is `ExactRepository` to the build ImageStream so dest pulls
after `oc tag` accept the signed identity. Learners must `cosign copy` (and
dest `cosign sign --key`) because `oc tag` does not copy `.sig` tags.

Enforcement for native ImagePolicy is **CRI-O `policy.json`**: `oc apply` of an
unsigned Deployment can succeed; the pod fails at **pull**. The policy file
reaches the node through a MachineConfigPool update. A pull during that update
stores the image with no signature. A later restart on that node stays in
`CreateContainerError` (`already present on machine` / `no signature exists`)
and does not recover by retrying. A pull after the pool is updated succeeds,
and a restart of that pull succeeds. Check 6.1 requires pools not Updating,
and a Ready stage pod created after the ImagePolicy object.

## Backend

Helm `admission.backend`: `auto` (default) | `imagepolicy` | `kyverno`.

`auto` uses `ImagePolicy` when the CRD exists. It does **not** install Kyverno.
Do not set `TechPreviewNoUpgrade`. Custom ImagePolicy (FulcioCAWithRekor) is GA
on OpenShift 4.20; do not score cluster-wide `ClusterImagePolicy`.

If a learner `enforce: true` apply drains MachineConfigPools for minutes, switch
`admission.backend: kyverno` after installing Kyverno yourself. Keep ImagePolicy
as the inspect-only render.

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespaces |
| `1` | RBAC + scripts ConfigMap |
| `2` | TUF copy Job |
| `3` | Apply CronJob |
| `4` | userinfo + docs |

Root App-of-Apps places this chart at sync wave **`10`** (with RHTAS / RHACS).
TUF copy waits for Securesign Ready. Apply CronJob retries until Gitea exists.

## Values of interest

| Key | Default | Notes |
|-----|---------|-------|
| `admission.enabled` | `true` | Chart gate |
| `admission.backend` | `auto` | Native ImagePolicy preferred |
| `admission.stageNamespace` | `lw-poc-staging` | Track 6 stage |
| `admission.prodNamespace` | `lw-poc-prod` | Empty until V2-17 |
| `admission.policyName` | `tssc-prod-admission` | Never `openshift*` |
| `kyverno.install` | `false` | Do not ship the community operator |

## Local validation

```bash
helm lint automation/gitops/components/admission
helm template admission automation/gitops/components/admission \
  --set deployer.domain=apps.cluster.example.com
```

## Enable from root-app

```bash
helm template lightwell automation/gitops/bootstrap-infra \
  --set components.admission.enabled=true \
  --set components.rhtas.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Root-app default is `components.admission.enabled: true` (with RHTAS).

## Related

- [V2-16](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/9)
- [publishing-house/spec/v2-2-portable-admission.md](../../../../publishing-house/spec/v2-2-portable-admission.md)
