# charts/components/gitea — Student Git (Gitea)

In-cluster **Gitea** for learner application **and** GitOps repositories. Module 6
pipelines and lab instructions clone **student** remotes here — not the workshop
GitOps monorepo (`NA-FSI-Services/lightwell-tssc-workshop`). **Do not** send
students to GitHub for lab clone/push; prefer `demo-userinfo-gitea` remotes
everywhere (see [AGENTS.md](../../../AGENTS.md)).

## What it deploys

| Resource | Purpose |
|----------|---------|
| Deployment + PVC + Route `gitea.<domain>` | Gitea (SQLite) |
| Job `gitea-student-repo-seed` | Create admin + `student` user; push **template** trees only |
| ConfigMap script `student-seed-from-templates.sh` | Learner copies Java templates → `lw-student` repos |
| ConfigMap script `student-ensure-gitea-user.sh` | Learner ensures Gitea login user `student` exists (via `gitea-admin`) |
| Application `lw-poc-staging` | Argo App from the learner **stage** GitOps remote (`lw-poc-staging`) |
| Application `lw-poc-prod` | Argo App from the learner **prod** GitOps remote (`lw-poc-prod`, V2-17) |
| GitOps overlay `admission/trust-policy.yaml` | Track 6.1 scored TrustPolicy (V2-16); seed is `enforce: false` |
| ConfigMap `demo-userinfo-gitea` | RHDP userinfo (expected URLs, templates, credentials) |

Default student in the **chart**: `student` / workshop password placeholder.
Each catalog claim is a dedicated environment with this one user.

Python FastAPI chart, overlays, and RHDH template files **stay in git** and are **not** provisioned (V2-12). Re-enable `seed.python`, `gitopsAppSetPython`, and `seed.templates.skeletonPython` only for V2-90.

### Learner model

1. Lab scripts / charts **start Gitea** and create the student user.
2. Learners discover `gitea_url` via `oc`, run `student-ensure-gitea-user.sh` if needed, then create organization **`lw-student`** and empty repos **`spring-boot-lw-poc`**, **`gitops-spring-boot-lw-poc`** (stage), and **`gitops-prod-spring-boot-lw-poc`** (prod).
3. Learner runs `student-seed-from-templates.sh` to push operator-prepared content from **`workshop-templates/`** into those repos. The script also adds **`renovate-bot`** as a write collaborator on the Java app repo (Track 3.3 / V2-24).
4. RHDH `publish:gitea` targets the same learner org.

| Item | Value |
|------|--------|
| Learner org | `lw-student` (`student_gitea_org`) |
| Java app repo | `lw-student/spring-boot-lw-poc` (`student_repo_url`) |
| Java stage GitOps repo | `lw-student/gitops-spring-boot-lw-poc` (`student_gitops_repo_url`) |
| Java prod GitOps repo | `lw-student/gitops-prod-spring-boot-lw-poc` (`student_prod_gitops_repo_url`) |
| Template org | `workshop-templates` |
| Java app template | `workshop-templates/spring-boot-lw-poc` |
| Java stage GitOps template | `workshop-templates/gitops-spring-boot-lw-poc` |
| Java prod GitOps template | `workshop-templates/gitops-prod-spring-boot-lw-poc` (wrong digest seed) |
| RHDH Java skeleton | `workshop-templates/lightwell-java-service` (`fetch:template`) |
| Build NS | `lw-poc-build` (PipelineRuns / BuildConfig; V2-21) |
| Stage NS / Argo app | `lw-poc-staging` |
| Prod NS / Argo app | `lw-poc-prod` |

## Path isolation (monorepo → template remotes)

Default `seed.source.mode=live`: the seed Job clones the **workshop GitOps URL**
(`seed.source.repoUrl`, injected from root-app `gitops.repoUrl`), then:

1. **Java app template** — copies `seed.source.path` to `workshop-templates/spring-boot-lw-poc`, includes `tools/osv-eval/`, overlays `.tekton/`, `renovate.json`, and stale `lightwell-pins.properties` (V2-24)
2. **Java stage GitOps template** — copies chart tree **excluding `app/`** to `workshop-templates/gitops-spring-boot-lw-poc`, overlays `admission/trust-policy.yaml` (V2-16 seed)
3. **Java prod GitOps template** — same chart isolation to `workshop-templates/gitops-prod-spring-boot-lw-poc`; digest seed `sha256:REPLACE_ME_PROD_DIGEST`; **no** TrustPolicy (V2-17)
4. **RHDH Java skeleton** — copies `seed.templates.skeleton` to `workshop-templates/lightwell-java-service`

Python FastAPI assemble (`seed.python`) and `skeletonPython` are **off** (V2-12). Overlay files stay in the chart.

Students never clone GitHub — only Gitea templates + their own org remotes (`student_repo_url`).

Lab Maven and pip fixtures in this GitHub repo are named **`pom.xml.example`** and
**`requirements.txt.example`**. Dependabot treats `pom.xml` / `requirements.txt` as
live projects and has already bumped the scored Maven pin (`commons-lang3` `3.14.0`
→ `3.18.0`, PRs #1, #4, #53, #67). The same risk applies to the Python `httpx==0.27.2`
Validated line. `assemble-repo.sh` / `assemble-skeleton.sh` rename those files back
when seeding Gitea. Do **not** merge Dependabot Maven or pip PRs on those fixtures.
Leave `publishing-house/tools/requirements.txt` as a real tooling manifest.

Optional `seed.source.gitSecretName` references a Secret with `username` / `password`
(or token as password) for private GitOps clones. **Do not commit credentials**; leave
empty for the public development repo.

`SOURCE_MODE=embedded` keeps the legacy ConfigMap pom/README fallback for the **Java app**
template only (offline chart tests). GitOps seed requires `live` mode.

## Digest promote

**Stage (6.1):**

1. Pipeline builds/signs into **build** NS (`lw-poc-build`)
2. Student `oc tag`s into `lw-poc-staging` ImageStream
3. Student commits `image.digest` + `replicas: 1` to **stage** Gitea gitops remote
4. Argo Application `lw-poc-staging` syncs → Healthy Route

**Prod (6.2 / V2-17):** second Gitea remote. Seed digest is `sha256:REPLACE_ME_PROD_DIGEST`. Learner commits the signed digest to `student_prod_gitops_repo_url`. Application `lw-poc-prod` must keep sourcing the **prod** remote (Check fails if it tracks stage). Not two Helm files in one repo.

Monorepo `components.springBootLwPoc` stays **disabled** (runtime SoT is Gitea).
`components.fastapiLwPoc` stays **disabled** (not a second catalog namespace).

## Sync waves (inside chart)

`namespace` → `rbac` / `config` → `deploy` → `route` → `seed` → `applicationset` → `userinfo`

Root-app Application wave: **`15`** (after TSSC operators, before RHDH / sample apps).

## Values of interest

| Key | Default | Notes |
|-----|---------|-------|
| `gitea.namespace` | `gitea` | |
| `student.username` | `student` | Single lab user for the dedicated environment |
| `student.password` | workshop placeholder | Override via values / secrets; never commit real passwords |
| `seed.templates.org` | `workshop-templates` | Operator-prepared content |
| `seed.templates.skeleton.enabled` | `true` | Seed RHDH Java `fetch:template` repo |
| `seed.templates.skeleton.repoName` | `lightwell-java-service` | Under templates org |
| `seed.templates.skeletonPython.enabled` | `false` | Off at provision (V2-12); files stay in git |
| `seed.templates.skeletonPython.repoName` | `lightwell-python-service` | Under templates org when enabled |
| `seed.repoName` | `spring-boot-lw-poc` | Learner + template Java app name |
| `seed.gitops.enabled` | `true` | Stage Java GitOps remote |
| `seed.gitops.repoName` | `gitops-spring-boot-lw-poc` | Learner + template **stage** gitops name |
| `seed.gitops.prod.enabled` | `true` | Second remote (V2-17) |
| `seed.gitops.prod.repoName` | `gitops-prod-spring-boot-lw-poc` | Learner + template **prod** gitops name |
| `seed.python.enabled` | `false` | Off at provision (V2-12) |
| `seed.python.repoName` | `fastapi-lw-poc` | Unused unless `seed.python.enabled` |
| `seed.python.gitops.repoName` | `gitops-fastapi-lw-poc` | Unused unless `seed.python.enabled` |
| `gitopsAppSet.enabled` | `true` | Argo Application `lw-poc-staging` (stage) in `openshift-gitops` |
| `gitopsAppSet.appName` | `lw-poc-staging` | Named stage Application (not prefix+username) |
| `gitopsAppSet.namespace` | `lw-poc-staging` | Stage app ns (was `lw-poc-student`) |
| `gitopsAppSet.buildNamespace` | `lw-poc-build` | Hermetic pipeline ns (V2-21) |
| `gitopsAppSetProd.enabled` | `true` | Argo Application `lw-poc-prod` sources the prod remote |
| `gitopsAppSetProd.namespace` | `lw-poc-prod` | Matches V2-16 admission prod ns |
| `gitopsAppSetPython.enabled` | `false` | Do not create `lw-fastapi-student` |
| `seed.source.mode` | `live` | `live` isolate from GitOps repo; `embedded` Java app fallback |
| `seed.source.repoUrl` | `""` | Injected by root-app from `gitops.repoUrl` |
| `seed.source.path` | `charts/components/spring-boot-lw-poc/app` | Java app subtree |
| `seed.python.sourcePath` | `charts/components/fastapi-lw-poc/app` | Python app subtree |
| `deployer.domain` | `""` | Injected by root-app |

## Local validation

```bash
helm lint charts/components/gitea
helm template gitea charts/components/gitea \
  --set deployer.domain=apps.cluster.example.com \
  --set seed.source.repoUrl=https://github.com/example/lightwell-tssc-workshop.git
./scripts/learner-git-check.sh
```

## Enable from root-app

```bash
# components.gitea.enabled: true (see charts/root-app/values.yaml)
```
