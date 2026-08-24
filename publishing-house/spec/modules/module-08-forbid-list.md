# Module 08 — 4.1 Source forbid-list

### Brief Overview

Active build files still contain a forbidden `FROM`, `curl`, or public index URL. Learner removes them. Check fails if any remain. This is not the NetworkPolicy Check (4.3) and not prefetch (4.2).

### Audience and Time

- **Prerequisites:** 3.2 source; pipeline applied in `lw-poc-build`
- **Estimated duration:** ~30 min

### Learning Objectives

- List the scored forbid patterns
- Edit Dockerfile / build files until none remain
- Know a known-bad Dockerfile is kept as a negative fixture

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Seeded violations | TBD |
| 2 | Your change: strip forbidden fetches | TBD |
| 3 | Check: scan of active files | TBD |

### Detailed Steps

1. Seed includes at least one forbidden public URL or curl (exact seed: V2-53 / V2-34).
2. Worked example forbids a different host than the scored file.
3. Learner edits the files the BuildConfig actually uses.
4. Check greps active Dockerfile/settings for the forbid-list; known-bad extra file may still exist and must still fail 4.4.

### Key Takeaways

- Hermetic starts in source, before NP and prefetch.
- Mapping: Konflux hermetic source policies → this Check.

### Infrastructure Notes

- Build in `lw-poc-build`. Image build stays BuildConfig (Q10).
