# Module 04 — 2.2 Remediated pin

### Brief Overview

Learner reads a Lightwell OSV / fixed event and sets the exact `.rhlw-*` version (`commons-lang3:3.14.0.rhlw-00001`) on `~/track-2-2/pom.xml`. There is no stub ConfigMap and no Validate Job. The Review is `mvn dependency:tree` showing **that** GAV from Nexus Remediated. Track 3 commits the same default. **Callouts:** Python `+rhlw.*` on requirements.txt; Artifactory must allow the `.rhlw-*` suffix (text only).

### Audience and Time

- **Prerequisites:** 2.1; app repo or Module 2 Gitea tree; OSV fixture in Nexus / ConfigMap
- **Estimated duration:** ~20 min

### Learning Objectives

- Map an OSV `fixed` event to a Maven exact pin
- Commit the pin on the scored pom (not only a profile that is never used)
- Call out PEP 440 local version analogue
- Call out Artifactory `.rhlw-*` suffix (same GAV; not a second Check)

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | OSV / Lightwell fixed event | TBD |
| 2 | Exercise: pom default version | TBD |
| 3 | Review: tree shows `.rhlw-*` | TBD |
| 4 | Callout: Python +rhlw | TBD |
| 5 | Callout: Artifactory `.rhlw-*` suffix | TBD |

### Detailed Steps

1. Inspect seeded OSV / GAV (`LW-DEMO-0002` / commons-lang3). Worked example uses a different GAV.
2. Change **default** `<commons.lang3.version>` on `~/track-2-2/pom.xml` to `3.14.0.rhlw-00001` (Track 3 commits the same version).
3. `mvn dependency:tree` with Remediated settings must list that GAV from Nexus. No Validate Job.
4. Optional source-diff of stub sources jar (v1 Module 4 material) as teaching, not the Check.
5. Python callout: `package==1.0.0+rhlw.00001` style — no FastAPI repo required.
6. Artifactory callout: same `.rhlw-*` GAV; remote naming must allow the suffix. The exercise is still Nexus.

### Key Takeaways

- Remediated is exact-version, not “latest”.
- Track 7 VEX is bound to **this** GAV.

### Infrastructure Notes

- Seed pin / broken default: V2-13 pom + V2-18 VEX beside the GAV.
