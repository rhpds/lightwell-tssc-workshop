# Module 12 — 5.1 Verify the application’s keyless signature

### Brief Overview

Inspect the signing TaskRun and verify the application digest with RHTAS identity and issuer constraints. Save the immutable image reference and verification output.

### Audience and Time

- **Prerequisites:** Track 4 image and SBOM evidence; RHTAS ready; cosign on PATH.
- **Estimated duration:** ~25 min; confirm during dry run.

### Learning Objectives

- Distinguish the pipeline’s internal signing endpoints from Showroom’s verification Routes.
- Confirm the committed run configuration and identify a successful signing TaskRun.
- Verify an immutable application reference against the pipeline identity and issuer.
- Save the verified digest and explain which signature belongs to the application.

### Exercise sequence

1. Confirm the committed signing configuration.
2. Inspect the signing TaskRun.
3. Verify and save the application digest.

### Review and handoff

Review saved command evidence before running the existing report and Validate Job. Preserve the Check IDs and the single Java application path. Carry the current digest and its evidence forward; refresh verification and SBOM evidence after a rebuild.
