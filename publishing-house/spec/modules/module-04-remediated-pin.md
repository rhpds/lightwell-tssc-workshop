# Module 04 — 2.2 Select and verify the remediated dependency

## Learning objectives and exercise

Continue in the same clone. Match the package in advisories/LW-DEMO-0002.json to the POM, read its fixed event, and edit the default commons.lang3.version property. Inspect the Git diff and resolve with the Remediated profile and a separate fresh cache. Compare both logs and carry the version into Track 3 without replacing the application POM.

## Prerequisites and evidence

Provisioning seeds `workshop-templates/lightwell-dependencies` from the configured workshop revision, including the canonical OSV fixture and `WORKSHOP_REVISION`. Discover its URL and branch from `lab-gitea`. Maven runs in Showroom. Module 2.2 requires module 2.1's settings and baseline evidence.

The working directory is `~/lightwell-dependencies`. Students retain their local edits and logs; no push or validation Job is required. Maven's tree proves version selection; successful artifact-download lines establish the source. The advisory is workshop sample data, not a real CVE. Track 3 commits the application default property. Python, Artifactory, and Premier remain brief callouts.

## Provisioning and QA

Keep cluster coordinates in ConfigMaps and exercise files in Gitea. Verify initial and repeat seeding, advisory provenance, fresh-cache resolution through both Nexus channels, and the downstream handoff. Do not overwrite student clones during seed updates.
