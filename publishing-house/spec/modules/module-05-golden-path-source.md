# Module 05 — 3.1 Golden-path source

### Brief Overview

Application source becomes **learner-owned** on in-cluster Gitea (`lw-student/spring-boot-lw-poc`). Scaffold via RHDH `lightwell-java-service` **or** clone + learner-seed from `workshop-templates`. Python RHDH template is not provisioned.

### Audience and Time

- **Prerequisites:** Gitea userinfo; learner org created (partial `gitea-learner-setup`)
- **Estimated duration:** ~25 min

### Learning Objectives

- Create org `lw-student` and seed the Java app remote from templates (or RHDH publish)
- Confirm `student_repo_url` is the working copy — not GitHub, not `workshop-templates`

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why learner-owned git | TBD |
| 2 | Your change: org + seed or RHDH | TBD |
| 3 | Check: Gitea app repo exists and is pushable | TBD |

### Detailed Steps

1. Discover `gitea_url` / passwords from `demo-userinfo-gitea`. Never clone the workshop GitHub monorepo.
2. Learner-seed-from-templates.sh (adds `renovate-bot` collaborator — needed for 3.3).
3. Optional: RHDH Software Template `lightwell-java-service` targeting the same org.
4. Check: repo exists under `lw-student`; templates org is not the scored remote.
5. Do not retarget Dockerfile FROM here (3.2). Do not merge a fake Renovate PR (3.3).

### Key Takeaways

- Golden path is Gitea + RHDH, not a zip from GitHub.
- Bot collaborator is a side effect of seed, scored in 3.3.

### Infrastructure Notes

- Gitea chart; RHDH enabled with lab stack. Python skeleton off (V2-12).
