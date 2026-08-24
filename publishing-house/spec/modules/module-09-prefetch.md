# Module 09 — 4.2 Prefetch (Hermeto mapping)

### Brief Overview

Learner **adds** Task `prefetch-dependencies` to the pipeline (it is **not** in the seed). The Task runs Maven `go-offline` then `mvn -o` against Nexus. Not `quay.io/konflux-ci/hermeto`, not a ClusterTask, not named hermeto. Check fails if undeclared deps are not prefetched / Central is still in settings.

### Audience and Time

- **Prerequisites:** 2.1 settings; 4.1 files; Task exists in `lightwell-tasks`
- **Estimated duration:** ~40 min

### Learning Objectives

- Wire `prefetch-dependencies` with the correct `runAfter` (not the worked-example order)
- Fail if settings/pom still point at public Central
- Map SoW “Hermeto” to this Task

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Mapping vs Konflux | TBD |
| 2 | Your change: add Task to pipeline | TBD |
| 3 | Check: offline resolve | TBD |

### Detailed Steps

1. Show Task YAML in `lightwell-tasks`; seeded pipeline omits it.
2. Worked example uses `hermeto` name / pip / wrong `runAfter`.
3. Learner copies Task into **their** pipeline in `lw-poc-build`.
4. Prefetch must use in-cluster Nexus; empty `.m2-offline` fails `mvn -o`.
5. Dockerfile `mvn -o` is a later content detail (V2-34) — outline it as follow-on, not this Check’s only evidence.

### Key Takeaways

- Hermetic prefetch is a Tekton Task on this claim.
- Do not install Konflux.

### Infrastructure Notes

- Report: `publishing-house/spec/v2-23-hermeto-prefetch.md`.
