# charts/components/showroom — RHDP Showroom lab UI

Deploys the **Showroom** split-screen learner experience for this workshop:

| Pane | Source |
|------|--------|
| Lab guide | Antora build of `site.yml` → `docs/modules/ROOT` (Modules 1–6 Java + Modules 7–9 Python; epic [#144](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/144)) |
| Terminal | `quay.io/rhpds/openshift-showroom-terminal-ocp` plus init-copy of `cosign`, `ec`, `oc-mirror` from `registry.redhat.io` (V2-20). `syft` is **not** baked. |

Promoted from `examples/helm/components/showroom` for issue [#19](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/19). Image pins follow [docs/SHOWROOM-UPDATE-SPEC.md](../../../docs/SHOWROOM-UPDATE-SPEC.md).

## Content path

| Setting | Value |
|---------|-------|
| `content.repoUrl` | This workshop Git repo |
| `content.repoRef` | `main` |
| `content.antoraPlaybook` | `site.yml` |
| UI theme | `rhpds/rhdp_showroom_theme` (declared in `site.yml`) |

Learners discover modules via `docs/modules/ROOT/nav.adoc` after Antora builds.

## Sync waves (inside this chart)

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | SA, RBAC (incl. lab ClusterRoleBinding), ConfigMaps, PVC |
| `2` | Deployment + Service |
| `3` | Route (`showroom.<deployer.domain>`) |
| `4` | RHDP `lab-showroom` (`showroom_url`) |

## Terminal lab RBAC

The terminal container runs as ServiceAccount `showroom` in namespace `showroom`. Module exercises use `oc -n lightwell-repo …`, `oc get routes -A`, and later TSSC namespaces — **namespace-local `edit` is not enough**.

When `showroom.terminal.labClusterAccess` is `true` (default), the chart creates ClusterRoleBinding `showroom-lab-cluster-admin` → `cluster-admin` for that SA. This is intentional for the RHDP workshop path so Showroom `/terminal/` can follow Modules 1–6 (and 7–9 when enabled) without a separate learner kubeconfig.

PVC `showroom-terminal-lab-user-home` mounts at `/home/lab-user`. Pod `securityContext.fsGroup` is `1000` (`OnRootMismatch`) so `lab-user` can write `~/` (#58). Do not tell learners to use `/tmp` instead.

Terminal `postStart` runs `lab-git-setup.sh` (#77): `user.name` / `user.email` plus a Gitea HTTPS credential store from `lab-gitea` (`student_username` / `student_password` / `gitea_url`). That is why later listings can `git commit` / `git push origin HEAD` with no TTY. The password is never written into the chart. 3.2 still has a one-shot fallback if this hook has not run yet.

Root App-of-Apps places this chart at sync wave **`50`** (last).

## Lab ConfigMap

ConfigMap `lab-showroom` exposes:

* `showroom_url` — primary access link (matches hello-world / field-content pattern)
* `gitea_url` — in-cluster Gitea (not egress)
* `hummingbird_source_pullspec` — V2-1 digest pin (do not invent pull specs)
* `dest_registry_host` / `dest_registry_docker` — empty Nexus Docker dest for learner oc-mirror
* `lab_clis` — `cosign,ec,oc-mirror` on PATH (`/usr/local/bin`); `syft_baked=false`
* `do_not_curl_github` — Q22; never download CLIs from github.com at runtime
* `lab_entry`, `access_instructions` (no `modules` key; v1 slugs were dropped, #57)
* Labels: `demo.redhat.com/application: lightwell-tssc-workshop`, `demo.redhat.com/userinfo: ""`

## Terminal CLIs (V2-20)

Init containers copy binaries from the same images the pipelines chart already pins:

| CLI | Image |
|-----|--------|
| `cosign` | `registry.redhat.io/rhtas/cosign-rhel9:1.3.0` |
| `ec` | `registry.redhat.io/rhtas/ec-rhel9:0.7` |
| `oc-mirror` | `registry.redhat.io/openshift4/oc-mirror-plugin-rhel9:v4.20` |

Files land at `/usr/local/bin/{cosign,ec,oc-mirror}` via `emptyDir` + `subPath` (login shells keep default PATH). **Do not** curl `github.com` for these. **`syft` is deferred** until a bake registry exists (no Red Hat CLI image).

## Nookbag / zero-touch

`nookbag.enabled` defaults to **`true`** so the ZT UI shell can load repo-root [`ui-config.yml`](../../../ui-config.yml) (split-screen lab + Terminal). **RHTPA** embeds (`external: false`); **SSO Account Console / Nexus / OpenShift Console** use `external: true` (those UIs set `X-Frame-Options`). Leave LlamaStack / multi-user zero-touch automation out of scope — see [SHOWROOM-UPDATE-SPEC.md](../../../docs/SHOWROOM-UPDATE-SPEC.md).

## Local validation

```bash
helm lint charts/components/showroom
helm template showroom charts/components/showroom \
  --set deployer.domain=apps.cluster.example.com

helm template lightwell charts/root-app \
  --set components.showroom.enabled=true \
  --set deployer.domain=apps.cluster.example.com
```

## Enable from root-app

```bash
# components.showroom.enabled: true  (wave 50)
# content.* already points at this repo + site.yml
```

## Related

- Modules: `docs/modules/ROOT/pages/module-0{1..5}-*.adoc`
- Issue [#19](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/19)
- [V2-20](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/12) — Showroom CLIs + ConfigMaps `lab-showroom` and `lab-gitea`
- [charts/root-app/README.md](../../root-app/README.md)
