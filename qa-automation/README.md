# qa-automation — V2-22 health and V2-52 fresh-claim e2e

Classic Showroom, honor system, **no Solve**. These playbooks do not complete
Tracks 1–7.

## healthcheck.yml

Post-provision readiness (duration depends on cluster response time). Confirms the v2 GitOps objects exist:

- Namespaces `lw-poc-build`, `lw-poc-staging`, `lw-poc-prod`
- NetworkPolicy `build-egress` / `app-operate`
- Prepared Track 1 Gitea mirror repository and provisioned Showroom Ansible runtime
- Incomplete lab stub (`stub-18-blast-radius`). Tracks 1 and 2 have no stub.
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
| Bastion mirror | No verified Track 1 result | V2-54 / Track 1 |
| Lab stubs | 7.2 still `REPLACE_ME`; known-bad `FROM docker.io`; ACS `fail-on-skipped` false. Tracks 1 and 2 have no stub. | V2-54 |
| Cosign verify internal | No PipelineRun in `lw-poc-build`; no digest on stage ImageStream | V2-54 / Track 5 |
| Admission deny | TrustPolicy seed `enforce: false`; no `ImagePolicy` `tssc-prod-admission` | V2-54 / Track 6.1 |
| Validate reports | Each unique quiz key still `REPLACE_ME`; no learner Job yet | V2-59 |
| Validate Jobs (×15) | Each Job fails with `CHECK FAILED` / no Solve; none left behind | V2-54 / V2-59 |

On a fresh claim Jobs fail on live seed state (placeholders, missing repos,
too-open NP) **or** on empty quiz tokens. Re-running e2e after a learner
finishes a track is expected to **fail** (seed state already changed, or a Job
would pass).

e2e is longer than healthcheck (15 Jobs; first `ose-cli` pull may dominate).

## Run

```bash
# From the repo root, kubeconfig already selected for the claim:
ansible-playbook qa-automation/healthcheck.yml
ansible-playbook qa-automation/e2e.yml

ansible-playbook --syntax-check qa-automation/healthcheck.yml
ansible-playbook --syntax-check qa-automation/e2e.yml
```

Requires `oc` on PATH and cluster-admin (or equivalent) on the claim.

## Track 1 live regression

Run `qa-automation/track1.sh` inside Showroom after completing `~/hummingbird-mirror-pipeline/inventory.yml`
and the source/key variables in `mirror-base.yml`. This requires an allocated test
claim: it performs real registry writes and updates the Track 1 report. It tests
missing and incorrect keys, successful mirroring, stale-result rejection, reruns,
and the independent cryptographic Check. Logs remain in `~/hummingbird-mirror-pipeline/qa-evidence`.
It deliberately does not run the full fresh-claim suite after completing Track 1.


### Track 2 starter and Maven evidence

Run `bash qa-automation/track2.sh` in Showroom after provisioning. It uses a temporary clone, checks advisory consistency with the Nexus seed ConfigMap and revision metadata, fills settings from cluster coordinates, and resolves both versions with separate fresh caches. It requires the expected dependency tree and successful JAR download from each Nexus channel. It does not edit student work or replace the student Review with a grading Job. Fresh-cache Maven plugin downloads require network access. On failure it prints the Maven log; temporary files are removed on exit.

For local provisioning checks, run `python3 qa-automation/test-track2-seed.py`. The test uses temporary Git fixtures and a mocked Gitea API, exercising initial/repeated/updated imports and preserving an edited student clone. It does not contact a cluster.

## Student acceptance regressions

Run `python3 qa-automation/test-student-defects.py` with Helm and PyYAML installed. It renders the affected charts, checks scoped ACS production pulls and catalog registration, verifies a same-wave consumer for the mirror PVC, and exercises the rendered prefetch script with matching and mismatched effective dependency graphs. Fixture packaging checks preserve upstream bytecode/licenses and reject signed input rather than invalidating its signature. The test uses temporary files and does not modify a claim.

`build-demo-jar.py` produces a marked simulation fixture, not a security backport. For integration validation, scan its output with Syft 1.18.1 (the workshop version) and confirm the Commons Lang PURL contains `3.14.0.rhlw-00001`; compare all `.class` entries with the upstream JAR to confirm the documented simulation boundary.
