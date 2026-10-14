# charts/components/validate-jobs — in-cluster Checks (V2-59)

Classic Showroom, honor system, **no Solve**, no `runtime-automation/`.
Provision does **not** create Job instances and does **not** pass any track.

## What it deploys

| Resource | Purpose |
|----------|---------|
| Namespace `lw-poc-validate` | Jobs, helper, reports, userinfo |
| ServiceAccount `validate-jobs` | Read-only inspect SA used **inside** the Job |
| ClusterRole `validate-jobs` | get/list on lab objects (no secrets, no create) |
| RoleBinding `validate-jobs-image-puller` in `lw-poc-build` | Pull the app image and `.sig` tag for 5.3 `cosign verify --key` |
| Role `validate-jobs-tpa-cli` in `trusted-profile-analyzer` | get Secret `tpa-realm-cli-clients` so 7.1 can call the analyzer |
| ConfigMap `validate-scripts` | Shared `helper.sh` + `check.sh` + `check-01.sh` … `check-18.sh` |
| ConfigMap `validate-job-templates` | One `job-NN.yaml` per gated module (learner `oc create`) |
| ConfigMap `report-<id>-<slug>` (×18) | Learner-owned short-answer; unique quiz key seeded `REPLACE_ME` |
| ConfigMap `demo-userinfo-validate` | Rerun example, Job/report names |
| ConfigMap `validate-docs` | Worked examples that are **not** paste-identical |

Jobs grade **live state** (`oc get`, public Gitea HTTP, and for 7.1 the Trusted Profile Analyzer SBOM API) **and** the per-module report token. They do **not** run Showroom `mvn`. Empty or wrong tokens fail even if cluster state is correct. Check 7.1 passes only when the analyzer holds a CycloneDX document whose root component version is the digest in the prod GitOps `values.yaml`.

Showroom-only gaps (still fail on a fresh claim):

- **5.3** runs `cosign verify --key` on `spring-boot-lw-poc:latest` using ConfigMap `tssc-admission/lab-cosign-pubkey`. `~/lab-trust` is not visible to the Job. Task `cosign-sign-keyless` is Check 5.1. A fresh claim still fails because `cosign.pub` is `REPLACE_ME`.
- **6.1** requires MachineConfigPools not Updating, and the newest `lw-poc-staging` pod Ready and created after ImagePolicy `tssc-prod-admission`. A cached pull from before the node enforced the policy stays in `CreateContainerError`.

## Learner rerun (unlimited)

```bash
oc -n lw-poc-validate delete job validate-01-hummingbird-verify --ignore-not-found
oc -n lw-poc-validate get configmap validate-job-templates \
  -o go-template='{{ index .data "job-01.yaml" }}' | oc create -f -
oc -n lw-poc-validate logs -f job/validate-01-hummingbird-verify
```

Same pattern as oc-mirror: templates live in a ConfigMap; the Job is not a Helm
object. `activeDeadlineSeconds` is 60 (120 on 5.3). No attempt quota.

## Reports

One ConfigMap per gated module in `lw-poc-validate`. Learners `oc edit` the
**unique** quiz key (seed `REPLACE_ME`). Allowed tokens are in `check-NN.sh`
(hyphens/underscores/case fold). Do not copy `example-report.yaml`. 7.2 still
grades structured blast-radius fields on `stub-18-blast-radius`; `report-18`
is the SoW layer token (`vex_layer`).

Track 1.1 / 2.1 / 2.2 / 7.2 also read stubs in `lightwell-repo`
(`stub-01-hummingbird-verify`, `stub-03-enterprise-proxy`,
`stub-04-remediated-pin`, `stub-18-blast-radius`).

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | RBAC + scripts |
| `2` | Reports + Job templates |
| `3` | userinfo + docs |

Root App-of-Apps places this chart at sync wave **`45`** (after sample apps,
before Showroom).

## Values of interest

| Key | Default | Notes |
|-----|---------|-------|
| `validateJobs.enabled` | `true` | Chart gate |
| `validateJobs.namespace` | `lw-poc-validate` | Not `lw-poc-build` |
| `job.image` | `openshift4/ose-cli:latest` | `oc` + `curl` + bash |
| `job.cosignImage` | `rhtas/cosign-rhel9:1.3.0` | 5.3 init container copies `cosign` into the Job |
| `job.buildNamespace` | `lw-poc-build` | Image-puller RoleBinding for 5.3 verify |
| `job.activeDeadlineSeconds` | `60` | 5.3 is `120` while it copies `cosign` |

## Local validation

```bash
helm lint automation/gitops/components/validate-jobs
helm template validate-jobs automation/gitops/components/validate-jobs \
  --set deployer.domain=apps.cluster.example.com
```

## Enable from root-app

```bash
helm template lightwell automation/gitops/bootstrap-infra \
  --set components.validateJobs.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Root-app default is `components.validateJobs.enabled: true`.

## Related

- [V2-51](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/33)
- Track checks: [V2-54](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/36)
- Fresh-claim fail suite: [V2-52](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/34) (`qa-automation/e2e.yml`)
- Report schema: [V2-59](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/40)
- How to run (content): V2-55 (not this chart)
