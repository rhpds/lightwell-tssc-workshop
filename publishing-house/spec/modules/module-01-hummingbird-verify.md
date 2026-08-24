# Module 01 — 1.1 Verify Hummingbird

### Brief Overview

Track 1 starts on a **published** Hummingbird / Hardened Images runtime (`HUMMINGBIRD_JAVA_RUNTIME` from V2-1 / `demo-userinfo-lightwell-repo`). The learner completes a trust policy and verifies the **published** digest with `cosign`. They do **not** run oc-mirror yet (that is 1.2). Check is amd64; arm64 in the index is a one-sentence callout.

### Audience and Time

- **Personas:** DevSecOps, platform engineers
- **Prerequisites:** Ungated intro; Showroom has `cosign` on PATH (V2-20)
- **Estimated duration:** ~30 min

### Learning Objectives

- Fill the incomplete trust-policy / verify inputs (not a copy of the worked example)
- Run `cosign verify` against the learner-recorded published digest
- Explain that the catalog index may list other arches; the Check is amd64 only

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Hummingbird vs UBI (why verify) | TBD |
| 2 | Your change: trust policy / recorded digest | TBD |
| 3 | Check: `cosign verify` published digest | TBD |
| 4 | Callout: multi-arch | TBD |

### Detailed Steps

1. Discover pin from `demo-userinfo-lightwell-repo` (`hummingbird_source_pullspec`). Do not invent pull specs in AsciiDoc.
2. Worked example uses a **different** image or incomplete snippet (not paste-identical).
3. Learner records digest + completes trust-policy fields (`REPLACE_ME_*` fail the Check).
4. `cosign verify` on the **published** coordinate (registry.access.redhat.com). Prefer baked key if the track fetches a cosign public key.
5. Callout: index may include arm64; no extra Check (Epic D / V2-95).
6. Do not pre-mirror. Do not switch Dockerfile FROM here (Track 3 / 3.2).
7. **Visual (generate):** published vs dest digest — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/49 — do not invent the PNG here. Shared with 1.2.

### Key Takeaways

- Consultants consume published Hummingbird; they do not rebuild the factory.
- Verify before mirror; 1.2 is a separate Check.

### Infrastructure Notes

- Egress: `registry.access.redhat.com` (Q22). No `github.com`.
- Seed: incomplete trust policy / REPLACE_ME (V2-53 details).
