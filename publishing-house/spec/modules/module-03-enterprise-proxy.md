# Module 03 — 2.1 Configure Maven to use Nexus

## Learning objectives and exercise

Clone the prepared lightwell-dependencies repository in Showroom. Read Nexus coordinates from lab-lightwell-repo, complete both URLs in settings.xml, inspect the Git diff, and resolve the starting POM with the Validated profile and a fresh cache. Review the exact dependency version and successful Nexus download in the saved Maven log.

## Prerequisites and evidence

Provisioning seeds `workshop-templates/lightwell-dependencies` from the configured workshop revision, including the canonical OSV fixture and `WORKSHOP_REVISION`. Discover its URL and branch from `lab-gitea`. Maven runs in Showroom. Module 2.2 requires module 2.1's settings and baseline evidence.

The working directory is `~/lightwell-dependencies`. Students retain their local edits and logs; no push or validation Job is required. Maven's tree proves version selection; successful artifact-download lines establish the source. The advisory is workshop sample data, not a real CVE. Track 3 commits the application default property. Python, Artifactory, and Premier remain brief callouts.

## Provisioning and QA

Keep cluster coordinates in ConfigMaps and exercise files in Gitea. Verify initial and repeat seeding, advisory provenance, fresh-cache resolution through both Nexus channels, and the downstream handoff. Do not overwrite student clones during seed updates.
