# Track 2: Lightwell dependencies

Clone this prepared repository from in-cluster Gitea into `~/lightwell-dependencies` in Showroom. Follow modules 2.1 and 2.2 in the workshop.

1. Read the Nexus URL and channel names from `lab-lightwell-repo` in namespace `lightwell-repo`.
2. Complete both repository URLs in `settings.xml`. Select the profile explicitly on each Maven run.
3. Resolve the starting POM with the Validated profile and save the baseline evidence.
4. Read `advisories/LW-DEMO-0002.json`, match the Maven package, and set the default property in `pom.xml` to its exact fixed version.
5. Resolve with the Remediated profile and compare the version and download evidence.

The advisory is workshop sample data, not a real CVE. Provisioning imports it from `automation/gitops/components/lightwell-repo/files/seed/LW-DEMO-0002.json` at the same workshop commit as this directory. `WORKSHOP_REVISION` records that commit; neither generated file is maintained separately here.

Keep edits local; do not push to this operator-managed template. Resume with your existing clone. Track 3 applies the selected version to your own application repository. Do not replace the application POM with this small exercise POM.

Evidence and Maven caches are ignored by Git. Settings contain cluster URLs only; never add credentials.
