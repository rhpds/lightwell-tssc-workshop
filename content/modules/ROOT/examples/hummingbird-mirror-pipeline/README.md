# Hummingbird mirror pipeline

Complete this starter in the Showroom terminal, following Track 1 of the workshop.
The provisioned Gitea repository is ready to clone; do not clone the workshop
GitHub monorepo as a student.

1. Fill `inventory.yml` with the bastion SSH host, port and user. Keep passwords
   and private keys outside this repository.
2. Set `source_pullspec` and `verification_key` in `mirror-base.yml` using the
   guide and the cluster's `lab-lightwell-repo` ConfigMap.
3. Record the destination's state with `oc image info` before running the mirror.
4. Run `ansible-playbook -i inventory.yml mirror-base.yml --syntax-check`, test
   SSH with `ansible -i inventory.yml bastion -m ansible.builtin.ping`, then run
   the negative-key exercise and the complete workflow from the guide.
5. Compare destination image metadata before and after, review the bastion
   ImageSet and run-specific logs, and inspect both saved Cosign verification
   payloads and the approved destination.

`prepare.yml` reads cluster configuration in Showroom and prepares the bastion.
`mirror-base.yml` verifies the source, mirrors the image, copies signatures,
and verifies the destination. `publish.yml` saves evidence and publishes the
verified result for Track 3. Registry credentials are removed after execution.
Local evidence is ignored by Git. The repository contains no completed inventory
or credentials. `WORKSHOP_REVISION` records the workshop commit used at provision.

The Gitea remote is an operator-managed starter. Edit your local clone; Track 1
requires no push or creation of the later application repositories. Re-running
the provision seed updates the starter without rewriting its Git history and
does not modify student clones.
