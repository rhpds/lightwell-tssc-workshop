# charts/components/renovate — live Renovate against Gitea (V2-24)

Track 3.3 scored bot. **MintMaker** is the SoW / mapping-appendix name for this
CronJob. This cluster does **not** install hosted Konflux MintMaker.

The bot must open a **real PR** on `lw-student/spring-boot-lw-poc` that updates
stale Lightwell and Hummingbird pins. The learner merges. A hand-edited commit
or a seeded PR fails the Check (Validate Job is V2-54).

Live PR proof is unproven until a claim. Fail the spike if Gitea+Renovate cannot
open a PR on RHDP.

## What it deploys

| Resource | Purpose |
|----------|---------|
| Namespace `renovate` | Bot runtime |
| Job `renovate-bot-token` | Create `renovate-bot` + mint Gitea token into a Secret |
| Secret `renovate-gitea-token` | Runtime token (never committed) |
| CronJob `renovate` | Official image, Gitea platform, every 20 minutes |
| ConfigMap `renovate-config` | Global config: no GitHub presets, Maven + Docker dest only |
| ConfigMap `lab-renovate` | Egress hosts, mapping name, target repo |
| ConfigMap `renovate-docs` | Worked example that is **not** paste-identical |

Does **not** open PRs on `workshop-templates`. Target repo exists after Module 2
learner seed; the CronJob retries until then.

## Pins

Seeded in the Java **app** template overlay (`lightwell-pins.properties`):

| Key | Seed (stale) | Expected bump |
|-----|----------------|---------------|
| `commons-lang3` | `3.14.0.rhlw-00000` | Nexus remediated `3.14.0.rhlw-00001` |
| `hummingbird-digest` | all-zero `sha256` | dest digest after Track 1 oc-mirror |

`pom.xml` default and Dockerfile `FROM` stay on the V2-13 UBI / dep-gate path.
Do not put a scored Hummingbird `FROM` in the seed.

Repo `renovate.json` uses regex managers only. Global config does **not**
`extends` GitHub presets (`binarySource: global`).

## Bot egress (Q24 exception — bot only)

List **only** hosts this bot needs. Do **not** add `github.com` to learner
NetworkPolicy or Showroom CLI downloads.

| Host | Why |
|------|-----|
| `ghcr.io` | Official Renovate image pull |
| `gitea.gitea.svc:3000` | In-cluster Gitea API / git |
| `nexus.lightwell-repo.svc:8081` | Maven remediated datasource |
| `registry-lightwell-repo.<domain>` | Dest Docker after Track 1 (may 404 until oc-mirror) |

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | RBAC + config + token Secret placeholder |
| `2` | Token Job |
| `3` | CronJob |
| `4` | lab ConfigMap + docs |

Root App-of-Apps places this chart at sync wave **`25`** (after Gitea 15 and
Nexus 20). The plan table listed 40; 25 is the dependency-correct wave.

Root-app default is `components.renovate.enabled: true` (after Gitea + Nexus).

## Local validation

```bash
helm lint automation/gitops/components/renovate
helm template renovate automation/gitops/components/renovate \
  --set deployer.domain=apps.cluster.example.com
helm template lightwell automation/gitops/bootstrap-infra \
  --set components.renovate.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

## Related

- [V2-24](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/16)
- Track 3 AsciiDoc: V2-33 (not this chart)
- Validate Jobs: V2-54 (not this chart)
