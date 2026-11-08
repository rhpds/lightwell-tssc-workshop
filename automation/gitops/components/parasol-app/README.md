# charts/components/parasol-app — optional secondary workload

Values-gated **multi-tier** scaffold for a larger enterprise narrative (Parasol / Dev Day reuse) **after** the primary [`spring-boot-lw-poc`](../spring-boot-lw-poc/) LWN path works.

This chart does **not** fork the full Parasol Insurance application into Git. It deploys frontend/backend placeholders, ships the **same Lightwell Maven channel names** as the primary PoC, and documents how to point images at a built Parasol workload.

## Acceptance mapping

| Criterion | How |
|-----------|-----|
| Optional / values-gated | Root `components.parasolApp.enabled: false`; chart is secondary |
| Same validated/remediated channels | ConfigMap `parasol-lightwell-maven-settings` uses `lightwell-java-validated` / `lightwell-java-remediated` |
| Does not block Phase 1 | Primary labs stay on `spring-boot-lw-poc` (#24) |

## Upstream reuse

- [rh-rad-ai-roadshow/parasol-insurance](https://github.com/rh-rad-ai-roadshow/parasol-insurance) (Quarkus + React)
- OpenShift Dev Day Roadshow catalog: `published.ocp-dev-days-rdshw.prod`
- Stretch: Hummingbird hardened images (#30 / #31) — out of scope here

## Sync waves

| Wave | Resources |
|------|-----------|
| `0` | Namespace `parasol` |
| `1` | Maven settings + lab docs (+ frontend HTML) |
| `2` | Backend / frontend Deployments + Services |
| `3` | Route |
| `4` | RHDP lab ConfigMap |

Root App-of-Apps places this chart at sync wave **`40`** (with sample apps).

## Enable

```bash
# After building real Parasol images:
helm template lightwell charts/root-app \
  --set components.parasolApp.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Keep committed root values at `enabled: false`.

## Related

- Issue [#8](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/8)
- Primary PoC: [#24](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/24)
- Artifact manager: [#7](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/7)
