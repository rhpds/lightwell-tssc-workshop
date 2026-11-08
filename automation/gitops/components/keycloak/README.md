# keycloak — workshop IdP for RHTPA

Minimal **Keycloak** (`start-dev` + realm import) that publishes the OIDC issuer RHTPA expects:

`https://sso.<deployer.domain>/realms/tpa`

## Sync waves (inside chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace `sso` |
| `1` | SA / anyuid SCC, admin Secret, realm ConfigMap |
| `2` | Deployment + Service |
| `3` | Route `sso.<domain>` |
| `4` | RHDP lab ConfigMap |

Root-app places this component at sync wave **`5`** so it is up before `rhtpa` (wave `10`).

## Realm clients (must match rhtpa)

| Client | Type | Secret |
|--------|------|--------|
| `frontend` | public | — |
| `cli` | confidential | `workshop-tpa-cli-changeme` (same as `rhtpa.oidc.cliClientSecret`) |

Workshop UI user: `tpa-user` / `workshop-tpa-user-changeme` with Trustify roles `chicken-user`, `chicken-manager`, `chicken-admin`.

## Trustify authorization (Module 4)

RHTPA / Trustify 3 requires OIDC **scopes** (and commonly **chicken-*** realm roles) before SBOM list/upload succeeds. This chart’s realm import includes:

| Kind | Names |
|------|--------|
| Realm roles | `chicken-user` (default), `chicken-manager`, `chicken-admin` |
| Standard client scopes (embedded) | `basic`, `profile`, `email`, `roles`, `web-origins`, `acr`, `offline_access` |
| Trustify client scopes (default on `frontend` + `cli`) | `read:document`, `create:document`, `delete:document` |
| Workshop user | `tpa-user` → all three chicken roles |
| CLI service account | `service-account-cli` → `chicken-manager` |

Standard scopes are **embedded** in the import JSON: Keycloak skips creating built-ins when `clients[]` / `clientScopes[]` are supplied, and without `roles` / `basic` tokens lack `realm_access` / `sub` (TPA then returns 401/403).

No learner-facing Keycloak Admin Console steps are required when GitOps syncs this chart on a fresh claim.

`start-dev` has **no PVC**. The Deployment pods annotate `checksum/realm-import` so ConfigMap changes recreate the pod and `--import-realm` reloads the realm. On long-lived claims where the realm already exists *inside a still-running pod*, delete the Keycloak pod (or scale Deployment) after sync so import runs on empty local storage.

If you re-import the `tpa` realm on an already-running claim, Keycloak rotates signing keys — restart the RHTPA `server` Deployment once so Trustify reloads JWKS (`oc -n trusted-profile-analyzer rollout restart deploy/server`). Prefer scaling `server` to `0` then `1` if a RWO storage PVC leaves pods in CrashLoopBackOff.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `keycloak.namespace` | `sso` | Keeps Route host `sso.<domain>` |
| `keycloak.routeHostPrefix` | `sso` | Do not change unless rhtpa `oidc.issuerURL` is overridden |
| `keycloak.image` | `quay.io/keycloak/keycloak:26.0.2` | Quarkus distribution |
| `oidc.cliClientSecret` | `workshop-tpa-cli-changeme` | Keep in sync with rhtpa chart |
| `deployer.domain` | `""` | Injected by root-app |

Override admin / workshop passwords via values or RHDP secret injection — do not use committed defaults in shared environments.

## Local validation

```bash
helm lint charts/components/keycloak
helm template keycloak charts/components/keycloak \
  --set deployer.domain=apps.cluster.example.com
```

Confirm the rendered realm JSON contains `chicken-manager` and `create:document`.

## Not in scope

- HA / external DB / production hardening
- RHBK Operator (claim-friendly Deployment instead)
- RHTAS Fulcio Keycloak realm (`trusted-artifact-signer`) — enable separately later if needed
