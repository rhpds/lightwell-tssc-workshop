# spring-boot-lw-poc (student lab repository)

Learner-owned application repository for the Lightwell TSSC workshop
(hosted on in-cluster **Gitea**).

Use this repository for Module 5 pipeline exercises (clone → policy gate → remediate →
BuildConfig image → sign). Discover your remote from ConfigMap `lab-gitea`
(`student_repo_url`).

## Layout

| Path | Purpose |
|------|---------|
| `pom.xml` / `src/` / `Dockerfile` | App sources at repository root |
| `Dockerfile.known-bad` | V2-53 leftover (4.1 / 4.4). Not the BuildConfig Dockerfile |
| `settings.xml` | Local Maven + LWN/Nexus (optional Secret — see Module 5) |
| `.tekton/` | Hybrid pipeline: dep-gate → OpenShift BuildConfig → ACS → SBOM → cosign |
| `renovate.json` / `lightwell-pins.properties` | Track 3.3 live Renovate (stale Lightwell + Hummingbird pins) |
| `README.md` | This file |

## Module 5 quick path (policy gate)

1. Default pin fails dep-gate:

   ```xml
   <commons.lang3.version>3.14.0</commons.lang3.version>
   ```

2. Success path — change the **default** properties pin to:

   ```xml
   <commons.lang3.version>3.14.0.rhlw-00001</commons.lang3.version>
   ```

3. Commit, push to `main` on **this** Gitea remote, re-run `lightwell-build-policy-gate`.

## Module 5 Ex3 (build + keyless sign)

Image build uses OpenShift **BuildConfig** (Dockerfile multi-stage / Maven Central inside
the build — not the learner Maven Secret). Track 4.2: Task `prefetch-dependencies`
in `lightwell-tasks` is **not** in the seeded Pipeline (not named hermeto). Tekton
handles policy, ACS (may soft-skip), SBOM, and RHTAS cosign.

The seeded Dockerfile is **UBI OpenJDK 21** (V2-13). Track 3: change the runtime `FROM` to
the mirrored Hummingbird digest (`dest_registry_host` + `hummingbird_source_pullspec`).
Do not copy a sample `FROM` from Showroom.

Track 3.3: merge the **renovate-bot** PR on `lightwell-pins.properties` (not a hand
commit). Apply the new pins to `pom.xml` / Dockerfile as the track instructs.

Apply `.tekton/` and the BuildConfig in `lw-poc-build` (`student_build_namespace`).
Promote with `oc tag` into `lw-poc-staging` (`student_promote_namespace`).

See Showroom Module 5 Exercise 3 for copy-paste `oc` / `tkn` steps (build namespace,
pull-secret link, PipelineRun).
