# 7.2 Explain the remediation and inspect ACS results

### Overview

Explain the sample library remediation and assess the promoted image with ACS.

### Prerequisites

7.1 retrieved inventory; Track 2 selected version; application clone and provisioned ACS Task/CI Secret.

### Learning objectives

- Interpret advisory evidence for an exact installed GAV.
- Store the supported inventory and advisory formats in TPA.
- Configure skipped checks to fail and inspect ACS policy evidence.
- Report sample remediation, policy findings, and limitations accurately.

### Exercise and review

1. Download the library CycloneDX, OpenVEX, and OSV documents from claim-specific Nexus URLs.
2. Compare installed Commons Lang with OSV fixed events and OpenVEX product URLs. LW-DEMO-0002 is a workshop sample, not a real CVE.
3. Upload library CycloneDX to the SBOM endpoint and OSV to the advisory endpoint; inspect stored evidence. Keep OpenVEX local.
4. Commit, fetch, and apply fail-on-skipped=true for the pipeline ACS task.
5. Run the existing ACS Task against the saved promoted digest without rebuilding. Inspect this named attempt and distinguish policy rejection from operational errors.
6. Write a local blast-radius report with image identity, advisory evidence, TPA IDs, ACS outcome, and scope. Review directly without a validation Job or report token.

### Visuals

`track7-advisory-layers.svg` separates inventory, library advisory, and other controls. `track7-acs-evidence.svg` follows configuration, an immutable-image check, and result interpretation.

### Infrastructure scope

Existing cluster behavior and instructor validation assets remain unchanged. The learner reviews direct evidence. Keep the live CSAF importer disabled.
