# 7.1 Record the promoted image's SBOM

### Overview

Record and retrieve the promoted application inventory.

### Prerequisites

Final saved SBOM and signing evidence; completed production promotion; TPA and Keycloak.

### Learning objectives

- Bind the inventory to the promoted artifact.
- Authenticate and ingest CycloneDX.
- Retrieve and compare the stored inventory.
- Distinguish inventory evidence from advisory interpretation.

### Exercise and review

1. Fetch the production Git commit and compare its digest with the signed image and live Deployment.
2. Select a saved CycloneDX inventory or recover lab-sbom-cyclonedx; require its root version to match the promoted digest.
3. Inspect Commons Lang, obtain an OIDC token, and upload the inventory to TPA.
4. List stored SBOMs with pagination, download the matching document, and compare its root digest and components.
5. Review saved terminal evidence; carry the document ID and inventory into 7.2. No validation Job or report token.

### Visuals

`track7-sbom-identity.svg` follows the digest from production through the retrieved inventory.

### Infrastructure scope

Existing cluster behavior and instructor validation assets remain unchanged. The learner reviews direct evidence. Keep the live CSAF importer disabled.
