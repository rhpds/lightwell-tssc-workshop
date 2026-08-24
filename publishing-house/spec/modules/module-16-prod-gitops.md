# Module 16 — 6.2 Promote to prod repo

### Brief Overview

**Second Gitea remote** `gitops-prod-spring-boot-lw-poc`. Seed digest is `sha256:REPLACE_ME_PROD_DIGEST`; no TrustPolicy on prod overlay. Learner commits the **signed** digest to prod. Check: Argo Application `lw-poc-prod` sources the **prod** remote (fails if it still tracks stage). Not two Helm files in one repo.

### Audience and Time

- **Prerequisites:** 6.1 stage Healthy; prod Application exists
- **Estimated duration:** ~30 min

### Learning Objectives

- Push the signed digest to the prod GitOps remote
- Keep prod Argo pointing at prod
- Not retarget the stage Application

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why two remotes | TBD |
| 2 | Your change: prod digest commit | TBD |
| 3 | Check: Application spec.repoURL | TBD |

### Detailed Steps

1. Show seed wrong digest and missing TrustPolicy on prod tree.
2. Learner commits the same signed digest used on stage (replicas as the track requires).
3. Check: `lw-poc-prod` `.spec.source.repoURL` is `student_prod_gitops_repo_url`; image is signed; unsigned still denied (policy from 6.1).
4. Do not “fix” by pointing prod Argo at stage.
5. **Visual (generate):** stage vs prod GitOps remotes — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/52 (same as 6.1).
6. **Visual (screenshot, dry-run):** Argo Applications — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/56.

### Key Takeaways

- Promotion is a git commit to a second remote — Release Service mapping.

### Infrastructure Notes

- V2-17. Namespace `lw-poc-prod`.
