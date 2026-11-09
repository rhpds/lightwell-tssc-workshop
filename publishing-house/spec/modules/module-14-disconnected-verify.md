# Module 14 — 5.3 Add and verify the admission signing key

### Brief Overview

Add a second signature to the verified application digest and verify it with the public key exported from the admission ConfigMap. The cluster remains connected; mirrored TUF and simulated transfer are optional appendix work.

### Audience and Time

- **Prerequisites:** Current verified application digest from 5.1 and policy evidence from 5.2.
- **Estimated duration:** ~30 min; confirm during dry run.

### Learning Objectives

- Generate a cosign key pair under `/home/lab-user/lab-trust` and sign the application digest with `--key` and `--tlog-upload=false`
- Verify that digest with `cosign verify --key`
- Publish `cosign.pub` to ConfigMap `lab-cosign-pubkey` so 6.1 can render ImagePolicy
- Explain that a Lightwell library signature is a different layer from this application key

### Exercise sequence

1. Generate or reuse your signing key.
2. Sign the verified digest and publish the public key.
3. Verify with the published public key.

### Review and handoff

Review saved command evidence before running the existing report and Validate Job. Preserve the Check IDs and the single Java application path. Carry the current digest and its evidence forward; refresh verification and SBOM evidence after a rebuild.
