# Module 13 — 5.2 Enforce and review the signature policy

### Brief Overview

Copy and tighten the learner-owned Conforma policy, wire the Task after signing, and compare fresh unsigned-builder and signed-application reports. The lab does not produce a provenance attestation.

### Audience and Time

- **Prerequisites:** Module 5.1; Conforma Task in lightwell-tasks; ec on PATH.
- **Estimated duration:** ~35 min; confirm during dry run.

### Learning Objectives

- Copy ConfigMap `conforma-policy` into the build namespace and tighten the copy
- Wire Task `conforma-policy` after `cosign-sign-keyless`, pointed at that copy
- Show `ec validate` reporting `builtin.image.signature_check` on `openjdk-21-builder`
- Show the signed application digest passing that same check, with only the attestation builtin left over

### Exercise sequence

1. Create your own policy copy.
2. Tighten the copy and inspect the difference.
3. Connect the policy Task after signing.
4. Run and inspect the policy Task.
5. Compare the unsigned and signed images.

### Review and handoff

Review saved command evidence before running the existing report and Validate Job. Preserve the Check IDs and the single Java application path. Carry the current digest and its evidence forward; refresh verification and SBOM evidence after a rebuild.
