# Module 17 — 7.1 SBOM system of record

### Brief Overview

Learner ingests (or labels) the **promoted** app SBOM into TPA so the digest is a system of record. This is not the Track 2 OSV read and not the Track 7 VEX blast-radius Check (7.2). **Callout:** Python SPDX vs CycloneDX (text).

### Audience and Time

- **Prerequisites:** 4.4 SBOM; 6.2 digest; RHTPA + Keycloak
- **Estimated duration:** ~30 min

### Learning Objectives

- SSO / token for TPA v3 API (from userinfo, not a pasted secret in git)
- Ingest CycloneDX for the promoted digest
- Find the component in the TPA UI

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | TPA vs RHDA | TBD |
| 2 | Your change: ingest | TBD |
| 3 | Check: TPA has digest/SBOM | TBD |

### Detailed Steps

1. Discover TPA URL and OIDC from `demo-userinfo-keycloak` / RHTPA userinfo.
2. Worked example uses a different purl / filename.
3. Learner uploads the SBOM from 4.4 bound to the promoted digest.
4. Check: TPA document exists for that digest (API or labeled ConfigMap/report token).
5. syft CLI may be missing (`syft_baked=false`) — use pipeline SBOM output.
6. **Visual (screenshot, dry-run):** TPA after promoted-app SBOM ingest — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/58 — do not invent the PNG here. GAV VEX UI is 7.2 (#57).

### Key Takeaways

- Compliance starts from the promoted artifact, not a laptop folder.

### Infrastructure Notes

- RHTPA chart. Do not enable live CSAF importer as the gate.
