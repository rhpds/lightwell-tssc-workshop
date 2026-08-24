# Module 18 — 7.2 VEX blast radius + ACS

### Brief Overview

**C+:** Learner pulls Lightwell **GAV-bound** CDX+VEX for `commons-lang3:3.14.0.rhlw-00001` (`LW-DEMO-0002`) from Nexus, ingests to TPA, and writes a blast-radius **report**: that CVE is remediated **via the Lightwell pin**, not still-open upstream. Hummingbird/Red Hat CSAF = OS-layer **callout**. ACS image check must not be the disabled stub. Live CSAF importer is **not** the gate.

### Audience and Time

- **Prerequisites:** 2.2 pin; 7.1 TPA; ACS pipeline task present
- **Estimated duration:** ~40 min

### Learning Objectives

- Fetch VEX/CDX from Nexus beside the Track 2 GAV (not a generic fixture CVE)
- Report keys: vulnerability id + status + GAV (schema V2-59)
- Enable/confirm ACS control is not skipped

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Layer map: library VEX vs OS CSAF | TBD |
| 2 | Your change: ingest GAV VEX + report | TBD |
| 3 | Check: report tokens + ACS | TBD |

### Detailed Steps

1. Userinfo keys `scored_vex_maven_cdx` / `scored_vex_maven_vex`. Worked example uses a different CVE/GAV.
2. Learner downloads from Nexus Remediated classifiers `cdx`/`vex`, ingests to TPA.
3. Report artifact: CVE/advisory id, status fixed, GAV matches Track 2 pin, “via Lightwell” token.
4. Callout: Hummingbird VEX/CSAF is OS layer — do not score it. Artifactory can host the same GAV classifiers; not installed.
5. ACS: pipeline image check on (not the soft-skip stub). ACS is not the admission gate (6.1).
6. **Visual (generate):** library VEX vs OS CSAF layer map — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/53 — do not invent the PNG here.
7. **Visual (screenshot, dry-run):** TPA after GAV VEX ingest — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/57. Not an ACS console shot (Check is pipeline, not the stub).

### Key Takeaways

- Metadata travels with the `.rhlw-*` GAV consultants pin in PoV.
- Wrong-layer VEX (RHEL CSAF) is how consultants over-claim.

### Infrastructure Notes

- V2-18 seed. Validate Job V2-54 / report V2-59.
