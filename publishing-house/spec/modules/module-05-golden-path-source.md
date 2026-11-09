# Module 05 — 3.1 Golden-path source

## Outcome

The learner creates `lw-student/spring-boot-lw-poc` through RHDH's Java Software
Template and inspects its Software Catalog registration. There is one Java path.
The legacy seed script is not part of the student exercise.

## Prerequisites

- Working student Gitea login, RHDH Guest login, and lab ConfigMaps.
- RHDH actions `fetch:template`, `publish:gitea`, and `catalog:register` loaded.
- Java skeleton assembled with the common build and Renovate overlays.
- Existing operator-owned stage/prod templates and Renovate account.

## Exercise

1. Discover Gitea/RHDH coordinates and check template/action availability.
2. Create `lw-student`; add the configured publishing identity to its Owners team.
3. Leave the application repository absent and run Lightwell Java Service in RHDH.
4. Inspect fetch, publish, and register results and both output links.
5. Add Renovate write access with an explicit Gitea API command.
6. Create empty stage/prod GitOps repositories, clone their templates, and push normally.

## Review

Compare catalog identity and source location, application starting files, bot
permission, and local/remote GitOps commit hashes. Record task/catalog links and
commit hashes. No validation Job or report token. Preserve existing repositories
on retries; do not delete or force-push student work. Module 3.2 edits FROM/POM;
module 3.3 reviews the bot PR.

## Operator readiness

Package and host the pinned Gitea dynamic plugin, configure its archive URL and
integrity, then verify the loaded actions on a fresh claim before delivery.
The RHDH chart README describes packaging and activation; disabled configuration
is not sufficient for this exercise. A failed catalog step must be repaired
without recreating an already-published application repository.
