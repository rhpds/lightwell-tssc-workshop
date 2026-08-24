# Module 07 — 3.3 Live Renovate

### Brief Overview

Live Renovate CronJob opens a PR on `lw-student/spring-boot-lw-poc` for stale `lightwell-pins.properties` (Lightwell GAV + Hummingbird digest). Learner **reviews and merges**. Check rejects a hand-edited commit or a seeded PR. MintMaker is the SoW mapping name only.

### Audience and Time

- **Prerequisites:** 3.1 seed (bot collaborator); chart `components.renovate` enabled on the claim
- **Estimated duration:** ~45 min (includes waiting for Renovate bot)

### Learning Objectives

- Identify a PR authored by `renovate-bot` (not `student`)
- Merge it; do not recreate the pin change as a manual commit
- Map MintMaker → this bot

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why a bot PR | TBD |
| 2 | Your change: merge renovate-bot PR | TBD |
| 3 | Check: author + files | TBD |

### Detailed Steps

1. Stale pins: `3.14.0.rhlw-00000` and all-zero Hummingbird digest. CronJob every 20 minutes. Renovate groups both lines into **one** PR (`groupName` on `lightwell-pins.properties`) so merging Maven does not conflict the digest bump.
2. Worked example in `renovate-docs` is author `student` / wrong package — paste fails.
3. If dest is still empty, Docker bump may lag; Lightwell Maven bump should appear after Nexus is up. Retry.
4. Learner merges on Gitea. Then apply pins to pom/Dockerfile if not already done in 3.2.
5. Check: merged commit author is renovate-bot; files include `lightwell-pins.properties`; not a seed SHA.
6. **Visual (screenshot, dry-run):** Gitea PR authored by `renovate-bot` — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/55 — do not invent the PNG here. Capture only if a live claim actually opened a PR.
7. Callout: customer Renovate often reads Artifactory Maven remotes; Check is still Nexus + Gitea.

### Key Takeaways

- Consultants run Renovate against enterprise git; this cluster uses Gitea.
- No github.com for learners.

### Infrastructure Notes

- V2-24 chart; token minted at runtime. Hummingbird dest bump needs 1.2.
