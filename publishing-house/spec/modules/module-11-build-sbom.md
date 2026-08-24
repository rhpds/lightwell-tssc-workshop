# Module 11 — 4.4 Build + SBOM

### Brief Overview

OpenShift **BuildConfig** produces the app image in `lw-poc-build`. SBOM artifact is generated (syft when available; pipeline SBOM task). Known-bad Dockerfile still fails. Image build is **not** Buildah.

### Audience and Time

- **Prerequisites:** 4.1–4.3; `.tekton` applied in build ns
- **Estimated duration:** ~45 min (includes BuildConfig run time)

### Learning Objectives

- Run the pipeline / BuildConfig until an imagestream tag exists
- Produce an SBOM file or OCI-attached SBOM
- Show the known-bad path still fails

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | BuildConfig vs Buildah | TBD |
| 2 | Your change: successful build | TBD |
| 3 | Check: image + SBOM; bad Dockerfile fails | TBD |

### Detailed Steps

1. Apply `.tekton` / BuildConfig in `lw-poc-build` (`student_build_namespace`).
2. Worked example uses a different task name / Python build.
3. Learner PipelineRun succeeds; ImageStream `spring-boot-lw-poc` has a digest.
4. SBOM present (file in workspace or attached). `syft` may still be `syft_baked=false` — use pipeline task if CLI missing.
5. Known-bad Dockerfile fixture still fails 4.1/4.4 negative.

### Key Takeaways

- Konflux “build” on this claim is BuildConfig + Tekton.
- `oc tag` into staging is Track 6, not this Check.

### Infrastructure Notes

- Seeded hybrid pipeline: dep-gate → BuildConfig → ACS → SBOM → cosign (learner still wires 4.2 / verify-base / conforma).
