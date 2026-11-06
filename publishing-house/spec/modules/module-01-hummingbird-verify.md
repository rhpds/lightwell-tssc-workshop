# Track 1 — Build a verified base-image mirror with Ansible

The learner completes `mirror-base.yml` in the Showroom terminal and targets the claim bastion over SSH. Only a browser is needed on the student computer.

## Learning objectives

- Discover bastion access in RHDP provision details and create an Ansible inventory.
- Select the published Hummingbird index and Red Hat key.
- Run source verification, oc-mirror, artifact copy, and destination verification as ordered tasks.
- Show that a failed control stops the workflow and clears its consumable result.
- Publish the verified internal digest for Track 3.

## Exercise

Extract the scaffold from `lightwell-repo/track1-ansible`, fill inventory and source/key variables, inspect task ordering and failure handling, run a negative key case, then complete the mirror. Provisioning supplies Ansible in Showroom. The playbook transfers the existing lab Linux tools to the bastion and removes temporary registry authentication on completion.

## Check

One final assessment retains `validate-02-hummingbird-mirror`. It reads the report, compares the expected source/destination/index, and runs Cosign independently with the trusted Red Hat key. A `.sig` tag or report token alone cannot pass. It does not require a Kubernetes mirror Job. Track 3 consumes the report’s verified destination.

The existing mirror-bases pipeline diagram illustrates the three controls. Image signature verification does not independently certify SBOM or attestation contents.
