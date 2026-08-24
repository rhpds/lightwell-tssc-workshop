# Module 02 — 1.2 Mirror into the trust boundary

### Brief Overview

Learner finishes the incomplete `ImageSetConfiguration` and **runs oc-mirror** so the scored image plus signatures and SBOM artifacts land in Nexus dest `hummingbird-mirror`. Provision does **not** pre-mirror. Check: `cosign verify` against the **internal** digest the learner recorded (`dest_registry_host`).

### Audience and Time

- **Prerequisites:** 1.1 passed; `oc-mirror` on Showroom PATH; dest registry empty
- **Estimated duration:** ~60 min (includes oc-mirror run time)

### Learning Objectives

- Replace `REPLACE_ME_HUMMINGBIRD_PULLSPEC` with the V2-1 pin (not a sample UBI)
- Start the learner Job from `oc-mirror-tooling` (not a provision Job)
- Verify image + signature/SBOM artifacts internally

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why dest is empty | TBD |
| 2 | Your change: ImageSet | TBD |
| 3 | Run oc-mirror | TBD |
| 4 | Check: internal `cosign verify` | TBD |

### Detailed Steps

1. Show empty dest (`hummingbird-mirror`) and incomplete ConfigMap `imageset-configuration`.
2. Worked example is `ubi9/ubi-minimal` in `oc-mirror-tooling` — paste-identical copy fails.
3. Learner edits ImageSet (image + signatures/SBOM artifact types; no `--remove-signatures`).
4. Learner creates/starts Job from tooling ConfigMap (`oc-mirror-learner`). The Job runs oc-mirror, then `cosign copy` so dest has tag-based signatures (Nexus Docker dest has no OCI referrers).
5. Record internal digest; `cosign verify` must use that dest digest, not only the public one from 1.1.
6. **Visual (generate):** published vs dest digest — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/49 (same as 1.1).
7. **Visual (screenshot, dry-run):** ImageSet after REPLACE_ME is filled — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/54 — do not invent the PNG here.
8. Callout: customer dest is often Artifactory Docker; Check is in-cluster Nexus `hummingbird-mirror`.

### Key Takeaways

- Mirror is a learner skill, not a finished cluster.
- Internal verify is a different Check from published verify.

### Infrastructure Notes

- Charts: V2-10 dest, V2-11 incomplete ImageSet. Dest Route `registry-lightwell-repo`.
