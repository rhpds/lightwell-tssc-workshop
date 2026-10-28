# charts/components/networkpolicy — Track 4.3 hermetic + Track 6 operate (V2-21)

Two policies, two Checks. Provision does **not** apply a correct hermetic
allow-list. The build-ns seed is too open; app-ns operate stays open.

## What it deploys

| Resource | Purpose |
|----------|---------|
| Namespace `lw-poc-build` | PipelineRuns / BuildConfig (Track 4 hermetic) |
| Namespace `lw-poc-staging` | Stage app (Track 6 operate; Argo Application destination) |
| Namespace `lw-poc-prod` | Prod app (same name as admission; idempotent) |
| NetworkPolicy `build-egress` | Seed allow-all egress in build ns — learner tightens |
| NetworkPolicy `app-operate` | Seed open operate in staging and prod |
| ConfigMap `lab-networkpolicy` | Namespaces, allow-list hints, seed flags |
| ConfigMap `networkpolicy-docs` | Worked example that is **not** paste-identical |

Do **not** apply ImagePolicy to `lw-poc-build`. Admission still targets staging + prod only.

## Scored vs seeded

| Track | Namespace | Policy | Seed | Learner |
|-------|-----------|--------|------|---------|
| 4.3 hermetic | `lw-poc-build` | `build-egress` | allow-all egress | deny-egress + DNS + image-registry + Nexus |
| 6 operate | `lw-poc-staging`, `lw-poc-prod` | `app-operate` | open | stays operate (not the hermetic Check) |

Documented hermetic allow-list (docs ConfigMap — **not** applied at provision):

- `openshift-dns` UDP/TCP **5353**
- `openshift-image-registry` TCP **5000**
- `lightwell-repo` Nexus HTTP **8081** + Docker dest **5000**
- In-cluster Gitea (internal git clone)

`registry.redhat.io` is **not** on the scored allow-list. After the learner
tightens the policy, task-image pulls from public registries will fail unless
those images are already on the internal registry.

Worked example `example-hermetic-egress.yaml` uses a fake namespace, a different
policy name, and a public CIDR so paste-identical copy fails the Check.

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespaces |
| `1` | NetworkPolicies |
| `2` | lab ConfigMap + docs |

Root App-of-Apps places this chart at sync wave **`10`** (with admission) so
namespaces exist before Gitea Argo Applications (wave 15).

## Values of interest

| Key | Default | Notes |
|-----|---------|-------|
| `networkPolicy.enabled` | `true` | Chart gate |
| `build.namespace` | `lw-poc-build` | Hermetic / pipeline ns |
| `build.seedTooOpen` | `true` | Allow-all egress until the learner tightens |
| `stage.namespace` | `lw-poc-staging` | Was `lw-poc-student` |
| `prod.namespace` | `lw-poc-prod` | Same as admission |

## Local validation

```bash
helm lint automation/gitops/components/networkpolicy
helm template networkpolicy automation/gitops/components/networkpolicy \
  --set deployer.domain=apps.cluster.example.com
```

## Enable from root-app

```bash
helm template lightwell automation/gitops/bootstrap-infra \
  --set components.networkPolicy.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Root-app default is `components.networkPolicy.enabled: true` (with admission).

## Related

- [V2-21](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/13)
- Track 4 AsciiDoc: V2-34 (not this chart)
- Validate Jobs: V2-54 (not this chart)
