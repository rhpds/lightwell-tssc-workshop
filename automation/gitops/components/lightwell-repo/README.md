# charts/components/lightwell-repo — Lightwell Network artifact manager

Enterprise **artifact manager** pattern (Sonatype Nexus) presenting Lightwell Network tiers used in field PoV delivery:

| Tier | Purpose | Canonical remote |
|------|---------|------------------|
| **Validated** (Java) | Upstream-parity rebuilds | `https://packages.redhat.com/lightwell/java/validated` |
| **Remediated** (Java) | Exact-version `.rhlw-0000X` backports | `https://packages.redhat.com/lightwell/java/remediated` |
| **OSV (Java)** | Fixed-vuln records for remediated | `https://packages.redhat.com/lightwell/osv/java/remediated` |
| **Validated** (Python / PyPI) | Upstream-parity rebuilds for `pip` | `https://packages.redhat.com/lightwell/python/validated` |
| **Remediated** (Python / PyPI) | Exact-version `.rhlw-0000X` backports | `https://packages.redhat.com/lightwell/python/remediated` |

pip simple-index paths append `/simple` (e.g. `…/python/validated/simple`).

Do **not** invent alternate channel names such as `upstream-untrusted` / `lightwell-network-secured`.

## Modes (live proxy vs seeded mirror)

| `lightwellRepo.mode` | When to use | Behavior |
|----------------------|-------------|----------|
| **`seeded`** (default) | RHDP / offline / deterministic labs | Nexus **hosted** repos; Job `lightwell-repo-seed` uploads curated Maven stubs, OSV JSON, CycloneDX SBOMs, GAV-bound OpenVEX, and PyPI wheels |
| **`proxy`** | Live LWN membership available | Nexus **proxy** repos to canonical `packages.redhat.com` URLs using Secret `lightwell-network-credentials` (`LW_USERNAME` / `LW_PASSWORD`) |

Set mode in values (or root-app overlay). Never commit real `LW_*` values.

### PyPI Remediated (required)

`channels.pypiRemediated.enabled` **must stay `true`** for this Java+Python catalog:

- **seeded + enabled** — creates hosted PyPI Remediated and uploads a workshop `.rhlw-*` marker wheel (does **not** call live LWN)
- **proxy + enabled** — creates PyPI proxy to `…/python/remediated`

Do **not** set `enabled: false` for catalog claims. The seeded marker keeps Module 8 deterministic without live Remediated PyPI membership.

### Seeded content (default)

Two Maven seed kinds on purpose (Module 2 teaches both):

| Kind | Coordinates | JAR | Lab use |
|------|-------------|-----|---------|
| **Resolution stub** | `spring-core:5.3.18` (+ `.rhlw-00003`) | Manifest-only workshop stub | `mvn dependency:get` — prove Nexus hosts Lightwell-shaped GAVs |
| **Compile-capable** | `commons-lang3:3.14.0` (+ `.rhlw-00001`) | Real Apache Commons Lang 3.14.0 (ASL 2.0), fetched from Maven Central at seed time | `mvn clean verify` — enterprise manager feeds a real PoC build |

| Coordinate | Tier | Notes |
|------------|------|-------|
| `org.springframework:spring-core:5.3.18` | Validated | Resolution stub; OSV demo base version |
| `org.springframework:spring-core:5.3.18.rhlw-00003` | Remediated | Resolution stub; exact-version suffix |
| `org.apache.commons:commons-lang3:3.14.0` | Validated | Compile-capable; matches `spring-boot-lw-poc` validated pin |
| `org.apache.commons:commons-lang3:3.14.0.rhlw-00001` | Remediated | Same binary under `.rhlw-*`; matches `lightwell-remediated-pins` |

**OSV** (raw repo `lightwell-osv-java-remediated`):

```text
osv/java/remediated/LW-DEMO-0001.json
```

`affected[].ranges[].events[].fixed` → `5.3.18.rhlw-00003`.

```text
osv/java/remediated/LW-DEMO-0002.json
```

`affected[].ranges[].events[].fixed` → `3.14.0.rhlw-00001` (Track 7 scored id; distinct from spring-core).

**CycloneDX** (same raw repo):

```text
sbom/java/validated/org.springframework/spring-core/5.3.18.cdx.json
sbom/java/remediated/org.springframework/spring-core/5.3.18.rhlw-00003.cdx.json
sbom/java/validated/org.apache.commons/commons-lang3/3.14.0.cdx.json
sbom/java/remediated/org.apache.commons/commons-lang3/3.14.0.rhlw-00001.cdx.json
vex/java/remediated/org.apache.commons/commons-lang3/3.14.0.rhlw-00001.vex.json
```

**Track 7 scored VEX (Q12 C+)** — bound to the Track 2 pin, not a generic TPA fixture and not live CSAF:

| Item | Value |
|------|-------|
| GAV | `org.apache.commons:commons-lang3:3.14.0.rhlw-00001` |
| Id | `LW-DEMO-0002` |
| Maven sidecars | classifiers `cdx` / `vex` next to the remediated GAV |
| Blast radius | `LW-DEMO-0002` is **fixed via Lightwell**; upstream `3.14.0` stays affected |
| Ingest | Learner pulls from Nexus and uploads to TPA. Provision does **not** pre-ingest |
| Not the gate | `trustedProfileAnalyzer.importers.redhatCsaf` stays `false` |
| Callout only | Hummingbird / Red Hat CSAF = OS-layer VEX; Python SPDX/VEX analogue is Track 8 text (no second seed) |

**PyPI** (Modules 7–9):

| Package | Tier | Notes |
|---------|------|-------|
| `httpx==0.27.2` | Validated | Real wheel fetched from PyPI at seed time; usable by FastAPI sample |
| `lw-workshop-pypi==1.0.0+rhlw.00001` | Remediated (required) | Workshop marker proving `.rhlw-0000X` on the Remediated index |

Override the Commons Lang download URL with env `COMMONS_LANG3_JAR_URL` on the seed Job if the cluster cannot reach Maven Central. Override the httpx wheel with `pypiSeed.wheelUrl` / `PYPI_SEED_WHEEL_URL` if the cluster cannot reach `files.pythonhosted.org`.

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | Credentials / Nexus admin placeholders, channel / Maven / pip / OSV / seed ConfigMaps |
| `2` | Nexus Deployment + PVC + Service |
| `3` | OpenShift Route |
| `4` | Seed RBAC + Job `lightwell-repo-seed` + oc-mirror PVC/SA/tooling (no Hummingbird pull) + RHDP lab ConfigMap (same wave as the empty workspace PVC — #54) |

Root App-of-Apps places this chart at sync wave **`20`**.

## Dest registry (V2-10)

Nexus **hosted Docker** repo `hummingbird-mirror` is the oc-mirror destination. It is created **empty**. Provision does **not** pull or push `HUMMINGBIRD_JAVA_RUNTIME` (V2-1 pin is lab ConfigMap only). Learners run oc-mirror in V2-11.

| Item | Value |
|------|--------|
| Docker connector | container/Service port `5000` |
| Route | `registry-lightwell-repo.<domain>` (TLS edge) |
| oc-mirror dest | `docker://registry-lightwell-repo.<domain>` |
| Plugin image | `registry.redhat.io/openshift4/oc-mirror-plugin-rhel9:v4.20` (Showroom copies the binary onto PATH — V2-20) |
| Cosign image | `registry.redhat.io/rhtas/cosign-rhel9:1.3.0` (Job copies tag-based signatures after oc-mirror — #63) |
| Workspace | PVC `oc-mirror-workspace` (`HOME`/`workingDir` `/workspace`, `fsGroup` 1000, anyuid SCC — #60) |
| Push auth | Secret `nexus-docker-push` (seed Job; admin → dest host) |
| DockerToken realm | Seed PUT `NexusAuthenticatingRealm` + `DefaultRole` + `DockerToken` (Nexus 3.70 has no `NexusAuthorizingRealm`; a swallowed 400 left dest login failing — #62) |
| Tooling | ConfigMap `oc-mirror-tooling` (`README`, learner `job.yaml`, worked example) |

Source pin (do not invent):

```
registry.access.redhat.com/hi/openjdk:21-runtime@sha256:e7c41dc2cba28c49d551c491419e00b75c5aef6c13326cc08765d30e882630ba
```

## Incomplete ImageSet (V2-11)

ConfigMap `imageset-configuration` is seeded with `REPLACE_ME_HUMMINGBIRD_PULLSPEC`. No provision Job runs oc-mirror.

| Item | Value |
|------|--------|
| Scored file | ConfigMap `imageset-configuration` key `imageset-config.yaml` |
| Worked example | `oc-mirror-tooling` key `example-imageset.yaml` (`ubi9/ubi-minimal` — not paste-identical) |
| Learner edit | Replace `REPLACE_ME_HUMMINGBIRD_PULLSPEC` with the V2-1 digest pin |
| Run from Showroom | `oc get cm oc-mirror-tooling -o jsonpath='{.data.job\.yaml}' \| oc create -f -` |
| Signatures | Job does **not** pass `--remove-signatures`. Nexus 3.70 Docker dest has no OCI referrers, so the Job runs `cosign copy` after oc-mirror (tag protocol `.sig` / `.att` / `.sbom`) |

```bash
oc -n lightwell-repo edit configmap imageset-configuration
# set additionalImages[0].name to hummingbird_source_pullspec from lab-lightwell-repo
oc -n lightwell-repo get configmap oc-mirror-tooling -o jsonpath='{.data.job\.yaml}' | oc create -f -
```

## Incomplete lab stubs (V2-53)

ConfigMap `stub-18-blast-radius` in `lightwell-repo` so the 7.2 Validate Job can `oc get` learner work. Worked examples stay on the pages / `validate-docs` and are not paste-identical. Argo `ignoreDifferences` `/data` on that name plus `imageset-configuration`. Modules 1.1, 2.1, and 2.2 have no stub. 2.1 writes `~/track-2-1-settings.xml` from ConfigMap `lab-lightwell-repo`. 2.2 writes `~/track-2-2/pom.xml`. `lightwell-maven-settings` stays a reference. Do not copy it over the 2.1 file.

| Module | ConfigMap | Seed defect | Not the scored path |
|--------|-----------|-------------|---------------------|
| 7.2 | `stub-18-blast-radius` | `REPLACE_ME_*` keys | `LW-DEMO-0001` |

Gitea overlay leftovers (same issue): `Dockerfile.known-bad` (`FROM docker.io` + `curl`); pipeline `acs-image-check` `fail-on-skipped: "false"`. ImageSet, UBI `FROM`, stale pins, too-open NP, Fulcio placeholders, TrustPolicy `enforce: false`, prod digest placeholder, and `report-*` `REPLACE_ME` were already seeded in Epic B.

## Credentials

### Lightwell Network (proxy mode)

```bash
oc -n lightwell-repo create secret generic lightwell-network-credentials \
  --from-literal=LW_USERNAME='<registry-sa|name>' \
  --from-literal=LW_PASSWORD='<token>' \
  --dry-run=client -o yaml | oc apply -f -
```

### Nexus admin (optional)

The seed Job captures `/nexus-data/admin.password` via `oc exec` when Secret `nexus-admin-credentials` password is empty. To set explicitly:

```bash
PASSWORD=$(oc -n lightwell-repo exec deploy/nexus -- cat /nexus-data/admin.password)
oc -n lightwell-repo create secret generic nexus-admin-credentials \
  --from-literal=username=admin --from-literal=password="$PASSWORD" \
  --dry-run=client -o yaml | oc apply -f -
```

**Never commit** service-account tokens or passwords.

## Maven learner UX

ConfigMap `lightwell-maven-settings` provides `settings.xml` with profiles:

- `lightwell-validated`
- `lightwell-remediated`

```bash
oc -n lightwell-repo extract configmap/lightwell-maven-settings --keys=settings.xml --to=.
mvn -s settings.xml -Plightwell-validated clean verify
# After seed Job succeeds:
mvn -s settings.xml dependency:get \
  -Dartifact=org.springframework:spring-core:5.3.18.rhlw-00003 \
  -Plightwell-remediated
```

## Python / pip learner UX

ConfigMap `lightwell-pip-settings` provides `pip.conf` (Validated) and `pip-remediated.conf`.

Learner-facing Nexus index URLs (Showroom / Module 7 attrs):

| Tier | Nexus simple index |
|------|--------------------|
| Validated | `https://nexus-lightwell-repo.<domain>/repository/lightwell-python-validated/simple` |
| Remediated | `https://nexus-lightwell-repo.<domain>/repository/lightwell-python-remediated/simple` |

Also published on ConfigMap `lab-lightwell-repo` keys `pypi_index_validated` / `pypi_index_remediated`.

```bash
oc -n lightwell-repo extract configmap/lightwell-pip-settings --keys=pip.conf --to=.
PIP_CONFIG_FILE=$PWD/pip.conf pip install httpx==0.27.2
# Remediated marker (Module 8 — channels.pypiRemediated.enabled=true required):
oc -n lightwell-repo extract configmap/lightwell-pip-settings --keys=pip-remediated.conf --to=.
PIP_CONFIG_FILE=$PWD/pip-remediated.conf pip install lw-workshop-pypi==1.0.0+rhlw.00001
```

Canonical remotes (document even when mirroring):

```text
https://packages.redhat.com/lightwell/python/validated
https://packages.redhat.com/lightwell/python/validated/simple
https://packages.redhat.com/lightwell/python/remediated
https://packages.redhat.com/lightwell/python/remediated/simple
```

## Reuse / references

- [Configure Artifactory for LWN Java](https://docs.redhat.com/en/documentation/red_hat_lightwell_network/current/configure-configure_artifactory_to_use_rhln_repository) (same remotes / `.rhlw-*` naming; this chart uses Nexus as the workshop stand-in)
- [Configure Python build tool for LWN](https://docs.redhat.com/en/documentation/red_hat_lightwell_network/current/configure-configure_python_build_tool)
- [DEVELOPMENT-PLAN.md](../../../DEVELOPMENT-PLAN.md) — Lab model
- [console.redhat.com/lightwell](https://console.redhat.com/lightwell)

## Local validation

```bash
helm lint charts/components/lightwell-repo
helm template lightwell-repo charts/components/lightwell-repo \
  --set deployer.domain=apps.cluster.example.com

./scripts/helm-validate.sh
```

## Enable from root-app

```bash
helm template lightwell charts/root-app \
  --set components.lightwellRepo.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Keep `components.lightwellRepo.enabled: false` until ready to sync.

## Related

- Issue [#7](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/7) — chart scaffold
- [V2-18](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/11) — GAV-bound CDX+VEX seed (C+); no live CSAF gate
- Issue [#145](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/145) — PyPI Validated + Remediated (always on)
- [V2-10](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/3) — dest Docker repo + oc-mirror tooling (no pre-mirror)
- [V2-11](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/4) — incomplete ImageSet + learner-run Job
- [V2-53](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/35) — incomplete lab stubs + known-bad leftover
- [V2-20](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/12) — Showroom copies oc-mirror onto PATH
- Epic [#144](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/144) — Python path Modules 7–9 (Java + Python catalog)
- OSV toolkit (pin parse + source diff): [`tools/osv-eval/`](../../../tools/osv-eval/) / [#25](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/25)
