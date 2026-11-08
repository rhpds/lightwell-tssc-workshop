# Student **stage** GitOps repository (Module 5 Exercise 4 / Track 6.1)

This Gitea repo is your **stage** runtime desired state for the Spring Boot LWN PoC.
Production is a **second remote** (`student_prod_gitops_repo_url`) — not a second
file in this repository.

- Chart root is a thin Helm chart (no `./app` Maven sources — those live in your
  `spring-boot-lw-poc` application repo used by the pipeline).
- Default `replicas: 0` and empty `image.digest` keep Argo CD **Healthy** before promote.
- `admission/trust-policy.yaml` is the Track 6.1 scored file (V2-16). Seed is
  `enforce: false` with `REPLACE_ME_*`. Do not apply `kind: ClusterImagePolicy`.
- Exercise 4 / 6.1: `oc tag` the signed image from `lw-poc-build` into
  `lw-poc-staging`, commit `image.digest` + `replicas: 1`, push **here**.
  Track 6.2 uses the prod remote.

See `PROMOTE.md` for the stage promote steps. Discover URLs from ConfigMap
`lab-gitea` (`student_gitops_repo_url`, `student_promote_namespace`,
`student_build_namespace`).
Prod is `student_prod_gitops_repo_url` (V2-17) — a different Gitea repository.
