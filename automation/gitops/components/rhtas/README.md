# charts/components/rhtas — Red Hat Trusted Artifact Signer

Deploys keyless signing infrastructure for the Lightwell TSSC workshop via the **RHTAS Operator** (OLM Subscription) and a `Securesign` custom resource (Fulcio, Rekor, Trillian, CTlog, TUF).

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace (`trusted-artifact-signer`) |
| `1` | OLM Subscription (`openshift-operators`) |
| `2` | `Securesign` CR |
| `3` | RHDP `demo-userinfo-rhtas` ConfigMap |

Root App-of-Apps places this chart at sync wave **`10`** (with other TSSC operators).

## Keyless signing stack

| Component | Role |
|-----------|------|
| **Fulcio** | Short-lived signing certificates from OIDC identity |
| **Rekor** | Tamper-evident transparency log |
| **Trillian** | Merkle-tree backend for Rekor / CTlog |
| **CTlog** | Certificate transparency for Fulcio |
| **TUF** | Trust-root distribution for verifiers |
| **TSA** | Optional RFC 3161 timestamp authority (`securesign.tsa.enabled`) |

Default Fulcio OIDC issuer is the **Kubernetes API** (`Type: kubernetes`) so pipeline / Tekton SA keyless signing works without a separate IdP. Optional Keycloak / RHBK email issuer can be enabled via `oidc.keycloak.enabled` when SSO is available (RHADS pattern).

OpenShift advertises `service-account-jwks-uri` as the external API (`https://api.<cluster>:6443/openid/v1/jwks`) while the service-account issuer stays `https://kubernetes.default.svc`. Current Fulcio refuses that cross-host JWKS fetch, so `cosign-sign-keyless` fails with `There was an error processing the identity token`. Job `align-sa-jwks-uri` sets `KubeAPIServer` `unsupportedConfigOverrides` so discovery publishes `https://kubernetes.default.svc/openid/v1/jwks` instead, then restarts `fulcio-server` because Fulcio caches the old JWKS URI until the pod is recreated. The token issuer string does not change. That override marks kube-apiserver `Upgradeable=False` until it is removed; workshop claims are not upgraded in place. Disable with `oidc.kubernetes.alignJwksURI.enabled=false`.

## Reuse sources

- Trusted Software Factory: `agd-v2.trusted-software-factory-cnv.prod`
- RHADS / `rhpds.ads` `ocp4_workload_trusted_artifact_signer` Securesign templates
- [RHTAS Deployment Guide](https://docs.redhat.com/en/documentation/red_hat_trusted_artifact_signer/1/html/deployment_guide/rhtas-ocp-deploy)

## Values of interest

| Key | Default | Notes |
|-----|---------|-------|
| `rhtas.enabled` | `true` | Chart gate |
| `rhtas.namespace` | `trusted-artifact-signer` | Instance namespace |
| `operator.channel` | `stable` | Or `stable-v1.3` |
| `operator.namespace` | `openshift-operators` | OperatorHub AllNamespaces |
| `oidc.kubernetes.enabled` | `true` | SA keyless signing |
| `oidc.kubernetes.alignJwksURI.enabled` | `true` | Republish in-cluster SA JWKS URI so Fulcio can sign |
| `oidc.keycloak.enabled` | `false` | Enable when SSO exists |
| `securesign.tsa.enabled` | `false` | Lighter default footprint |
| `deployer.domain` | `""` | Injected by root-app |

## Local validation

```bash
helm lint charts/components/rhtas
helm template rhtas charts/components/rhtas \
  --set deployer.domain=apps.cluster.example.com

./scripts/helm-validate.sh
```

## Enable from root-app

```bash
helm template lightwell charts/root-app \
  --set components.rhtas.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

Keep `components.rhtas.enabled: false` in committed root values until a cluster is ready to sync this chart.

## Related

- Issue [#4](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/4)
- [charts/root-app/README.md](../../root-app/README.md)
