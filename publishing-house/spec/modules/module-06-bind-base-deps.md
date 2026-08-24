# Module 06 — 3.2 Bind base + deps in source

### Brief Overview

Seeded Dockerfile is **UBI OpenJDK 21** (wrong product). Learner sets runtime `FROM` to the **mirrored** Hummingbird digest (`dest_registry_host` + digest from 1.2) and commits Lightwell pins in source. Do not copy a sample `FROM` from Showroom.

### Audience and Time

- **Prerequisites:** 1.2 dest digest; 2.2 pin; 3.1 app repo
- **Estimated duration:** ~30 min

### Learning Objectives

- Change runtime FROM from UBI to dest Hummingbird digest pin
- Keep Lightwell pins in the committed pom / pins file
- Strip leftover public registry fetches from the scored files (full forbid-list Check is 4.1)

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why seed is UBI | TBD |
| 2 | Your change: FROM + pins | TBD |
| 3 | Check: committed files | TBD |

### Detailed Steps

1. Show seed `ubi9/openjdk-21-runtime` and `lightwell-pins.properties` (stale pins for 3.3).
2. Worked example FROM uses a fake registry/name (not paste-identical).
3. Learner writes `FROM dest/hi/openjdk@sha256:…` using **internal** digest from 1.2.
4. Pom default pin remains the Track 2 remediated GAV (or is applied here if not already).
5. Check: git on `lw-student/spring-boot-lw-poc` has Hummingbird FROM + `.rhlw-*`; still UBI fails.

### Key Takeaways

- Source of truth is the learner repo, not the operator template.
- 3.3 still requires a bot PR on the pins file.

### Infrastructure Notes

- V2-13 UBI seed. Dest empty until 1.2.
