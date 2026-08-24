# Module 15 — 6.1 GitOps + admission

### Brief Overview

Stage GitOps: learner `oc tag`s the signed image into `lw-poc-staging` and commits digest + replicas to the **stage** Gitea gitops remote. Admission: learner completes portable `TrustPolicy` (`enforce: true`, real identity). Chart renders namespaced `ImagePolicy` on staging **and** prod — not `ClusterImagePolicy`, not RHACS for this gate. Unsigned still denied. **Callouts:** VM = same digest; canary/blue-green exist; rolling is scored.

### Audience and Time

- **Prerequisites:** 5.1 signed digest; Gitea stage gitops repo; admission CronJob
- **Estimated duration:** ~35 min

### Learning Objectives

- Promote via stage GitOps (Application `lw-poc-staging`)
- Complete TrustPolicy so unsigned cannot run
- Leave prod remote for 6.2

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Stage vs prod remotes | TBD |
| 2 | Your change: digest + TrustPolicy | TBD |
| 3 | Check: unsigned deny; stage Healthy | TBD |
| 4 | Callouts: VM, canary, rolling | TBD |

### Detailed Steps

1. Seed TrustPolicy `enforce: false` / `REPLACE_ME_*`. Worked example is a different kind/name.
2. Learner fills issuer/subject from 5.1; sets enforce true; commits to **stage** gitops `admission/trust-policy.yaml`.
3. `oc tag` from `lw-poc-build` into `lw-poc-staging`; Helm `image.digest` + `replicas: 1`.
4. Check: ImagePolicy live on staging+prod; unsigned deploy denied; Argo `lw-poc-staging` Healthy.
5. Callouts only: bootc/Satellite same digest; canary/blue-green; rolling is what we score.
6. `app-operate` NetworkPolicy stays open (not 4.3).
7. **Visual (generate):** stage vs prod GitOps remotes — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/52 — do not invent the PNG here. Shared with 6.2.
8. **Visual (screenshot, dry-run):** Argo Applications stage Healthy / prod seed — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/56.

### Key Takeaways

- One learner file; backend may be ImagePolicy or Kyverno fallback (V2-2).
- Prod commit is 6.2.

### Infrastructure Notes

- V2-16, V2-17. Do not score ClusterImagePolicy.
