# Workshop release contract

A catalog claim must select one immutable release tag for the bootstrap Application, child charts, Showroom guide, and Gitea starter imports. `gitops.revision` has no implicit `main` fallback. Set it explicitly to the bootstrap Application's `spec.source.targetRevision`; leave `components.showroom.content.repoRef` empty to inherit it. The Showroom git-cloner takes a branch/tag, not a SHA. Use the SHA as acceptance evidence, not as its content ref.

The root chart rejects a different guide repository/ref and rejects legacy `springBootLwPoc` and `fastapiLwPoc` enablement. The scored path is the student-owned Java application. Starter assembly fails if the selected revision cannot be fetched; it never falls back to the default branch. The separately packaged RHDH Gitea plugin remains pinned by its package version and integrity hash: it has its own release cadence and must be tested with each workshop release.

## Catalog team handoff

The RHDP/AgnosticV overlay is maintained outside this repository. Updating this chart does **not** update that overlay, an old tag, or existing claims. Do not close #102 until the catalog team completes these steps:

1. Merge the workshop fixes and select a new candidate release tag on the intended commit. Never move the old `lightwell-tssc-workshop-1.0.1` tag or label an untested candidate as validated.
2. Set the catalog bootstrap target and `gitops.revision` to that same tag, using this repository. Remove any Showroom ref override or set it to the same tag. Explicitly disable both legacy application components in the catalog values. Preserve the current infrastructure enablement and claim-specific values.
3. Render the catalog's effective bootstrap values. Provision a fresh test claim from the candidate, then run `python3 qa-automation/release-preflight.py --bootstrap bootstrap` from this checkout with authorized `oc` access. Substitute the real bootstrap Application name if different. Save its revision report and the healthcheck output.
4. Verify rendered Showroom navigation against `content/modules/ROOT/nav.adoc` at that tag and prerequisites against `publishing-house/spec.yaml`. Confirm no retired module-02 navigation or obsolete universal Validate Job/report-token instructions. Complete the learner path and the persistence, credential, and namespace migration acceptance checks before promoting the catalog overlay.
5. Record the catalog overlay PR, immutable tag, resolved SHA, fresh claim result, and any deliberately versioned external dependencies on #102. An inaccessible overlay or untested claim is a remaining release blocker.

The preflight requires a remote release tag and compares the bootstrap and child resolved revisions, starter import values, and the actual Showroom checkout. It rejects mismatches and missing evidence. Explicit development branches can be used for chart iteration but do not pass catalog release readiness. An old bootstrap release cannot acquire these guards retroactively; the catalog team must replace its pinned release.
