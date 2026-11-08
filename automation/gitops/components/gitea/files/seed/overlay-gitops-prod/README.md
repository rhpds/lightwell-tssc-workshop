# Student **prod** GitOps repository (Track 6.2)

This Gitea remote is the **production** desired state. It is a **second
repository**, not a second values file in the stage GitOps repo.

- Chart root is the same thin Helm chart as stage (no `./app` Maven sources).
- Seed is **wrong on purpose:** `image.digest` is `sha256:REPLACE_ME_PROD_DIGEST`
  and `replicas: 0`. Do not copy `values.yaml` from the stage remote.
- Track 6.2: commit **your** signed digest (from Track 5) here, set `replicas: 1`,
  push **this** remote. The Argo CD Application `lw-poc-prod` must keep
  `spec.source.repoURL` on **this** prod remote — not `student_gitops_repo_url`.

See `PROMOTE.md`. Discover URLs from ConfigMap `lab-gitea`
(`student_prod_gitops_repo_url`, `student_prod_namespace`).
