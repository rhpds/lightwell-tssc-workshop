# Red Hat Developer Hub — Track 3.1

The RHDH Operator creates Developer Hub in namespace `rhdh`. The mounted
`lightwell-java-service` Software Template fetches the parameterized skeleton
from in-cluster Gitea, publishes `lw-student/spring-boot-lw-poc`, then registers
its `catalog-info.yaml`. Python remains disabled; there is one Java path.

## Operator prerequisite: publish:gitea

The RHDH image does not include this workshop's Gitea publishing module. The
previously configured workshop release archive is unavailable. Do not point
claims at that URL or enable an unverified package. Package the upstream module:

```bash
bash automation/tools/package-rhdh-gitea-plugin.sh /tmp/rhdh-gitea-output
```

The script pins the upstream module and RHDH export CLI versions, exports a
backend dynamic plugin, and writes a `.tgz` plus its SHA-512 `.integrity` file.
It does not publish the package, change cluster configuration, or store credentials.
Transitive dependency resolution is captured in the output lockfiles; retain those
with the archive. Test the resulting package against the RHDH version on the claim.

Host the archive at an operator-controlled HTTPS artifact URL accessible to the
RHDH init container. Supply its URL and the exact integrity string in the bootstrap
chart's deployment values:

```yaml
components:
  rhdh:
    giteaScaffolder:
      enabled: true
      package: https://ARTIFACT-HOST/PATH/plugin.tgz
      integrity: sha512-REPLACE_WITH_GENERATED_VALUE
```

The bootstrap chart forwards these fields to the component chart. For a direct
component install, use `dynamicPlugins.giteaScaffolder` instead. Helm rejects
activation with an empty URL or integrity. The default stays disabled until a
real archive is supplied; that default alone is **not ready for module 3.1**.
After the operator sync/restart, inspect dynamic-plugin init logs and confirm
`fetch:template`, `publish:gitea`, and `catalog:register` at `/create/actions`.
The `lab-rhdh.gitea_scaffolder_enabled` flag records configuration, not readiness.

Packaging follows the [RHDH CLI](https://github.com/redhat-developer/rhdh-cli)
and [Backstage Gitea module](https://backstage.io/api/stable/modules/_backstage_plugin-scaffolder-backend-module-gitea.html).
The dynamic plugin is a workshop integration; local export is not a substitute
for testing its compatibility with the deployed Hub.

## Source and permissions

Gitea provisioning assembles `workshop-templates/lightwell-java-service` from the
RHDH skeleton. `assemble-skeleton.sh` promotes `pom.xml.example` and overlays the
canonical Java exercise pipeline, Renovate configuration/pins, and known-bad
Dockerfile from the seed ConfigMap. Missing Java overlays fail assembly. The
application name is fixed to the workshop name so these assets and later modules
agree. Template expressions remain intact until `fetch:template` renders them.

Students create `lw-student` and grant the configured publishing account access
to its Owners team with the explicit commands in module 3.1. The chart exposes
only the publishing username in `lab-rhdh`; credentials remain in
`rhdh-gitea-scaffolder`. This lab uses the configured admin identity; production
installations should use a suitably scoped service account.

RHDH creates the application repository; students must not pre-create it, delete
an existing application, or run the legacy learner seed script over it. After
creation they explicitly grant the Renovate account write access and populate
the two GitOps remotes with ordinary Git pushes. The template does not perform
those steps. Student login repair belongs to the instructor; the legacy ensure
script can reset an existing password when authentication fails.

## Review before workshop delivery

On a fresh claim, complete module 3.1 and inspect all three task results, both
output links, catalog identity/source location, application starting files, bot
permissions, and stage/prod commit hashes. Run modules 3.2 and 3.3 to verify the
runtime/POM edits and an actual grouped Renovate PR. Preserve the created
repository if catalog registration fails; repair registration instead of
recreating the repository. No Track 3 validation Job is required.

Developer Hub uses the configured Guest login for this workshop. Do not redirect
students to GitHub OAuth. Claim-specific coordinates are in `lab-rhdh` and
`lab-gitea`. Module instructions and template output use the seven-track sequence.
