# Module 14 — 5.3 Disconnected verify

### Brief Overview

Second Track 5 Check. Learner places the TUF root (and keys) on the **lab trust path** and completes **key-based** `cosign verify`. Seeded TUF path is empty or wrong; copying the example path fails. The cluster stays networked — this is the **procedure** for air-gap, not a diode. Diode/media transfer stays in `appendix-disconnected-playbook.adoc` (V2-40).

### Audience and Time

- **Prerequisites:** 5.1 signed digest; admission/RHTAS TUF material (V2-16 copy Job)
- **Estimated duration:** ~30 min

### Learning Objectives

- Export/copy TUF root to the scored path (not the example path)
- `cosign verify --key` (or equivalent) against that root
- Explain this is not a physically disconnected cluster

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Why a second Check | TBD |
| 2 | Your change: TUF on lab path | TBD |
| 3 | Check: key-based verify | TBD |

### Detailed Steps

1. Seeded trust path empty/wrong. Example uses a different filename/ns.
2. Learner copies from RHTAS TUF / `rhtas-tuf-keys` into the path the Check reads.
3. Key-based verify of the **app** digest succeeds.
4. Callout: real diode playbook is appendix-only.

### Key Takeaways

- Consultants can say “mirrored TUF + keys” without claiming the RHDP cluster is air-gapped.

### Infrastructure Notes

- V2-40 content issue owns AsciiDoc + appendix. This outline is the spec grain.
