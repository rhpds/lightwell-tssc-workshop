# Module 13 — 5.2 Attest + Conforma

### Brief Overview

Learner copies ConfigMap `conforma-policy` to the build/app ns, **tightens** it (skip flags off, identity not `.*`, CVE not 999), and wires Task `conforma-policy` after sign. Fail-then-pass: known-bad image fails; learner image passes. Local `ec validate`; no quay.io policy fetch.

### Audience and Time

- **Prerequisites:** 5.1; Task in `lightwell-tasks`; `ec` on PATH
- **Estimated duration:** ~35 min

### Learning Objectives

- Turn the weak seed into an enforcing policy
- Wire the Task (not present in seeded pipeline)
- Demonstrate fail then pass

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why Conforma | TBD |
| 2 | Your change: tighten + wire | TBD |
| 3 | Check: fail-then-pass | TBD |

### Detailed Steps

1. Seeded ConfigMap is weak. Docs example is not paste-identical.
2. Learner disables skip, sets identity/issuer to RHTAS values from 5.1, drops dummy CVE 999.
3. Add Task after `cosign-sign-keyless` with correct `runAfter`.
4. Check: `ec validate` fails on unsigned/known-bad; passes on signed learner image.
5. Mapping: Konflux Conforma → this Task.

### Key Takeaways

- Policy is learner-owned, not a passing default.
- SLSA/in-toto attestations ride with the image where the pipeline emits them.

### Infrastructure Notes

- V2-15. Worked example in `conforma-policy-docs`.
