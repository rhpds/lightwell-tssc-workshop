# charts/components/spring-boot-lw-poc — primary Java sample

Primary learner workload: **Spring Boot / Java 21 / Maven** greeting API with OpenAPI, demonstrating Lightwell Network **Validated** and **Remediated** (`.rhlw-*`) consumption.

**Dockerfile (V2-13):** seed is UBI `ubi9/openjdk-21` / `ubi9/openjdk-21-runtime` (wrong product). Track 3 replaces the runtime `FROM` with the mirrored Hummingbird digest. Do not ship `hi/openjdk` as the seed.

Parasol (`#8`) remains optional and secondary.

## Layout

```
spring-boot-lw-poc/
├── Chart.yaml / values.yaml / templates/   # GitOps deploy (Deployment, Route, docs)
└── app/                                    # Maven project sources
    ├── pom.xml.example                     # dual-stream pins; Gitea seed → pom.xml
    ├── settings.xml                        # lightwell-validated / lightwell-remediated
    ├── Dockerfile
    └── src/main/java/.../GreetingController.java
```

## Learner commands

Students use the **Gitea** app remote (`lab-gitea` → `student_repo_url`), not a
monorepo checkout. Operators still author sources under `./app` in this chart.
The GitHub copy of the Maven manifest is `app/pom.xml.example` so Dependabot cannot
bump the scored `commons-lang3` `3.14.0` pin. Seed renames it to `pom.xml` on Gitea.
Local operator Maven: `mvn -f pom.xml.example ...`.

```bash
# Learner (Showroom): clone Gitea spring-boot-lw-poc — pom.xml at repo root
cd /tmp/spring-boot-lw-poc
export LIGHTWELL_NEXUS_URL=https://nexus-lightwell-repo.apps.<domain>
export MVN_LOCAL=-Dmaven.repo.local=/tmp/m2
mvn $MVN_LOCAL -s settings.xml -Plightwell-validated clean verify
mvn $MVN_LOCAL -s settings.xml -Plightwell-validated dependency:tree
mvn $MVN_LOCAL -s settings.xml -Plightwell-validated spring-boot:run

# Remediated exact-version pin (needs LWN / seeded Nexus for .rhlw-* artifact)
mvn $MVN_LOCAL -s settings.xml -Plightwell-remediated,lightwell-remediated-pins clean verify

# SBOM for RHTPA
mvn $MVN_LOCAL -s settings.xml -Plightwell-validated -DskipTests package
syft packages dir:target -o cyclonedx-json > sbom.cyclonedx.json
```

Endpoints (after Route is up): `/api/greeting`, `/api/healthz`, `/swagger-ui.html`.

## Image / deploy

Default `replicas: 0` and empty `image.digest` keep Argo **Healthy** before promote.

1. Prefer digest pin after Module 5 Ex4: set `image.digest: sha256:…` and `replicas: 1`.
2. When `image.repository` is empty, the image is derived as `{registry}/{namespace}/{name}`.
3. Chart renders an ImageStream for `oc tag` promote into the product namespace.
4. **Workshop runtime path (#100):** leave root-app `components.springBootLwPoc.enabled=false`; Gitea seeds a thin chart (no `./app`) and Argo Application `lw-poc-staging` syncs it. Enable the monorepo Application only for non-Gitea demos.

## Sync waves

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | Lab docs ConfigMap |
| `2` | Deployment + Service |
| `3` | Route |
| `4` | RHDP lab ConfigMap |

Root App-of-Apps places this chart at sync wave **`40`**.

## Related

- Issue [#24](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/24)
- Artifact manager: [#7](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/7)
- Optional Parasol: [#8](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/8)
