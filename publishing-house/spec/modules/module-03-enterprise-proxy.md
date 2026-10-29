# Module 03 — 2.1 Enterprise proxy

### Brief Overview

Learner **writes** `~/track-2-1-settings.xml` from ConfigMap `lab-lightwell-repo` so Maven resolves Lightwell Validated through in-cluster Nexus. There is no stub ConfigMap and no Validate Job. The Review is the Maven log. Direct `packages.redhat.com` is explained; seeded Nexus is the workshop default. **Callouts:** Python `pip.conf`; Artifactory virtual repo / remote (not installed).

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
| 2 | Exercise: settings.xml from lab-lightwell-repo | TBD |
| 3 | Review: Maven resolve from Nexus | TBD |
| 4 | Callout: pip.conf | TBD |
| 5 | Callout: Artifactory (not installed) | TBD |

### Detailed Steps

1. Worked example uses a fake repo id / host (`nexus.example.invalid`). `lightwell-maven-settings` is a reference. Do not copy it over the home file.
2. Learner writes `~/track-2-1-settings.xml` from `nexus_url`, `channel_validated`, and `channel_remediated` on `lab-lightwell-repo`.
3. `mvn -s ~/track-2-1-settings.xml` dependency resolve against Validated; output must show the Nexus host. No Validate Job.
4. Callout: `pip.conf` index-url for Lightwell PyPI Validated (no FastAPI app).
5. Callout: Artifactory remote + virtual + include/exclude against the same Lightwell URLs (docs link; no second product; the exercise stays Nexus `settings.xml`). Visual #50 already includes Artifactory in the three-column flow — do not invent a PNG here.
6. Do not require live `packages.redhat.com` if the claim is seeded.
7. **Visual (generate):** direct vs proxied vs seeded — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/50 — do not invent the PNG here. No Nexus admin screenshot (Check is Maven CLI).

### Key Takeaways

- Consultants wire the customer’s artifact manager. On this cluster that manager is Nexus.
- Python is a sentence, not Module 7.
- Artifactory is remote + virtual + include/exclude; not installed.

### Infrastructure Notes

- Namespace `lightwell-repo`. Auth placeholders never committed.
