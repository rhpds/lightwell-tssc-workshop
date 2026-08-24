# Module 03 — 2.1 Enterprise proxy

### Brief Overview

Learner **authors** `settings.xml` from a stub so Maven resolves Lightwell Validated and Remediated through in-cluster Nexus (enterprise proxy pattern). Direct `packages.redhat.com` is explained; seeded Nexus is the workshop default. **Callouts:** Python `pip.conf`; Artifactory virtual repo / remote (not installed).

### Audience and Time

- **Prerequisites:** Track 1; Maven in Showroom; ConfigMap `lightwell-maven-settings`
- **Estimated duration:** ~30 min

### Learning Objectives

- Produce a settings.xml that is not the worked-example file
- Resolve a Validated GAV from Nexus (not Maven Central)
- State how pip.conf / Artifactory would do the same job

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Direct vs proxied vs seeded | TBD |
| 2 | Your change: settings.xml from stub | TBD |
| 3 | Check: Maven resolve from Nexus | TBD |
| 4 | Callout: pip.conf | TBD |
| 5 | Callout: Artifactory (not installed) | TBD |

### Detailed Steps

1. Stub settings.xml is incomplete (missing mirror or wrong URL). Worked example uses a fake repo id / host.
2. Learner fills Nexus URLs from `demo-userinfo-lightwell-repo` / `lightwell-maven-settings`.
3. `mvn -s settings.xml` dependency resolve against Validated; output must show Nexus host.
4. Callout: `pip.conf` index-url for Lightwell PyPI Validated (no FastAPI app).
5. Callout: Artifactory remote + virtual + include/exclude against the same Lightwell URLs (docs link; no second product; Check stays Nexus `settings.xml`). Visual #50 already includes Artifactory in the three-column flow — do not invent a PNG here.
6. Do not require live `packages.redhat.com` if the claim is seeded.
7. **Visual (generate):** direct vs proxied vs seeded — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/50 — do not invent the PNG here. No Nexus admin screenshot (Check is Maven CLI).

### Key Takeaways

- Consultants wire the customer’s artifact manager; Nexus is the RHDP stand-in.
- Python is a sentence, not Module 7.
- Artifactory is remote + virtual + include/exclude; not installed.

### Infrastructure Notes

- Namespace `lightwell-repo`. Auth placeholders never committed.
