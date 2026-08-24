# Module 12 — 5.1 Sign (keyless)

### Brief Overview

Learner signs the **app** digest keylessly with RHTAS (Fulcio, Rekor, TUF) and `cosign verify`. This is the connected happy path. 5.3 is a **second** Check (mirrored TUF + keys). Do not treat keyless-only as Track 5 done.

### Audience and Time

- **Prerequisites:** 4.4 image digest; `cosign` on PATH; RHTAS Ready
- **Estimated duration:** ~25 min

### Learning Objectives

- Sign the learner-built app image (not only Hummingbird)
- `cosign verify` with Fulcio identity / issuer matching the cluster
- Leave TUF/key-based verify for 5.3

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Keyless vs keys | TBD |
| 2 | Your change: sign app digest | TBD |
| 3 | Check: `cosign verify` | TBD |

### Detailed Steps

1. Pipeline cosign-sign-keyless or manual `cosign sign` against RHTAS.
2. Worked example uses `example.invalid` issuer/subject.
3. Learner records app digest; verify must succeed on **that** digest.
4. Identity strings stay `REPLACE_ME_*` until they fill them (V2-14 task pattern).
5. `oc tag` to staging may wait for 6.1.

### Key Takeaways

- Keyless is the connected PoV path.
- Disconnected customers still need 5.3.

### Infrastructure Notes

- RHTAS chart. Showroom does not curl GitHub for cosign.
