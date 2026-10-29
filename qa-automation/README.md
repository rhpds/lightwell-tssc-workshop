# qa-automation — V2-22 health and V2-52 fresh-claim e2e

Classic Showroom, honor system, **no Solve**. These playbooks do not complete
Tracks 1–7.

## healthcheck.yml

Post-provision readiness (< 60s). Confirms the v2 GitOps objects exist:

- Namespaces `lw-poc-build`, `lw-poc-staging`, `lw-poc-prod`
- NetworkPolicy `build-egress` / `app-operate`
- Incomplete ImageSet ConfigMap, oc-mirror tooling + PVC
- Incomplete lab stub (`stub-18-blast-radius`). Modules 1.1, 2.1, and 2.2 have no stub.
- CronJob `trust-policy-apply`
- Tasks `verify-base-image` / `conforma-policy` / `prefetch-dependencies`
- Showroom CLI lab ConfigMap (`cosign`, `ec`, `oc-mirror`; `syft_baked=false`)
- Validate Job scaffold: namespace `lw-poc-validate`, helper, 15 report ConfigMaps, Job templates (no Job instances)

Does **not** require a mirrored Hummingbird image, a signature, or unsigned deny.
Does **not** start Validate Jobs.

Expects the claim to enable `networkPolicy`, `admission`, `gitea`,
`lightwell-repo`, `pipelines`, and `validateJobs`.

## e2e.yml

Imports the health check, asserts the **fresh-claim negatives**, then **creates
each gated Validate Job** and expects a teaching `CHECK FAILED` (V2-52). Jobs
are deleted afterward so a leftover instance is not mistaken for learner work.

| Title item | Fresh-claim assertion | Pass-path |
|------------|----------------------|-----------|
| Mirror job | ImageSet still `REPLACE_ME`; Job `oc-mirror-student` absent | V2-54 / Track 1 |
| Lab stubs | 7.2 still `REPLACE_ME`; known-bad `FROM docker.io`; ACS `fail-on-skipped` false. Modules 1.1, 2.1, and 2.2 have no stub. | V2-54 |
| Cosign verify internal | No PipelineRun in `lw-poc-build`; no digest on stage ImageStream | V2-54 / Track 5 |
| Admission deny | TrustPolicy seed `enforce: false`; no `ImagePolicy` `tssc-prod-admission` | V2-54 / Track 6.1 |
| Validate reports | Each unique quiz key still `REPLACE_ME`; no learner Job yet | V2-59 |
| Validate Jobs (×15) | Each Job fails with `CHECK FAILED` / no Solve; none left behind | V2-54 / V2-59 |

On a fresh claim Jobs fail on live seed state (placeholders, missing repos,
too-open NP) **or** on empty quiz tokens. Re-running e2e after a learner
finishes a track is expected to **fail** (seed state already changed, or a Job
would pass).

e2e is longer than healthcheck (18 Jobs; first `ose-cli` pull may dominate).

## Run

```bash
# From the repo root, kubeconfig already selected for the claim:
ansible-playbook qa-automation/healthcheck.yml
ansible-playbook qa-automation/e2e.yml

ansible-playbook --syntax-check qa-automation/healthcheck.yml
ansible-playbook --syntax-check qa-automation/e2e.yml
```

Requires `oc` on PATH and cluster-admin (or equivalent) on the claim.
