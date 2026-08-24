# Lightwell Software Supply Chain Security Workshop

## Overview

This lab walks a consultant through **one trusted supply chain** on a dedicated OpenShift claim: verify a Hummingbird base, consume Lightwell dependencies, own the application source, build in a Konflux-class pipeline (OpenShift Pipelines + BuildConfig — not hosted Konflux), produce a signed attested image, promote to a production container via GitOps, then prove continuous compliance.

**Visual (generate):** seven-track flow — https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/48 — do not invent the PNG here. Other teaching diagrams and dry-run screenshots are cited on the module outlines.

Java (`spring-boot-lw-poc`) is the **only scored app**. Python / PyPI and Artifactory are **callouts** on the same modules, not a second hands-on path. v1 Modules 1–9 (Java then FastAPI) are not the spine.

Scheduling envelope is a **two-day event**. Clock time is not the design constraint. `duration_hours` stays TBD until a dry run.

## Target Audience

- **Role:** Application developers, DevSecOps engineers, and platform engineers who will deliver Lightwell Network / TSSC proof-of-value
- **Experience level:** Intermediate to Advanced
- **What they already know:** Basic Maven, Git CLI, oc CLI (namespaces, configmaps, routes), RHDP Showroom
- **What they don't know:** Hummingbird verify + oc-mirror, Lightwell Validated/Remediated/OSV and `.rhlw-*` pins, live Renovate against Gitea, hermetic build (forbid-list + prefetch + build-ns NetworkPolicy), portable TrustPolicy admission, prod GitOps remote, Lightwell GAV-bound VEX in TPA

## Prerequisites

- Basic Maven (add a dependency, run a build)
- Git CLI: clone, commit, push, merge a PR
- oc CLI: inspect namespaces, configmaps, routes, NetworkPolicy
- RHDP Showroom access provisioned before the session
- No prior Lightwell Network, Hummingbird, or supply-chain security experience required

Prerequisites are assumed and not automatically validated by the lab environment.

## Learning Objectives

1. Complete a trust policy and verify a published Hummingbird image (amd64 digest; arm64 is a callout)
2. Edit an incomplete ImageSetConfiguration and run oc-mirror so image, signatures, and SBOM land in the in-cluster dest
3. Author Maven settings.xml so Lightwell Validated and Remediated resolve from the enterprise Nexus proxy
4. Apply an exact-version `.rhlw-*` pin from a Lightwell OSV fixed event on a broken pom.xml
5. Bind application source to the mirrored Hummingbird digest and Lightwell pins
6. Merge a live Renovate PR on in-cluster Gitea that updates those pins (not a hand-edit)
7. Enforce a hermetic build: source forbid-list, prefetch task, and build-namespace NetworkPolicy
8. Produce an OpenShift BuildConfig image and SBOM
9. Sign the app image keylessly with RHTAS and tighten Conforma so a known-bad image fails
10. Complete mirrored-TUF plus key-based cosign verify (disconnected procedure, not a physical air-gap)
11. Promote a signed digest through stage GitOps with unsigned-deny admission, then commit it to the prod GitOps remote
12. Ingest Lightwell GAV-bound VEX/SBOM into TPA and report the CVE as remediated via the Lightwell pin

## Content Type

Lab (hands-on)

## Products & Technologies

**Red Hat Products:**
- Red Hat Lightwell Network (Validated, Remediated, OSV)
- Project Hummingbird / Red Hat Hardened Images (`hi/openjdk` — GA; pin `HUMMINGBIRD_JAVA_RUNTIME`)
- Red Hat Trusted Profile Analyzer (RHTPA / TPA)
- Red Hat Trusted Artifact Signer (RHTAS) — Fulcio, Rekor, TUF
- Red Hat Advanced Cluster Security (RHACS)
- Red Hat Developer Hub (RHDH) — Software Templates / golden path
- Red Hat OpenShift Container Platform (OCP) — oc CLI; catalog minimum **4.20**
- Red Hat OpenShift Pipelines (Tekton)
- Red Hat OpenShift GitOps (Argo CD)
- Keycloak / SSO — OIDC for RHTPA

**Upstream and Third-Party Technologies:**
- Maven — Java build tool
- Nexus — enterprise artifact manager (workshop stand-in; Artifactory is a callout)
- Gitea — in-cluster source and GitOps remotes (not GitHub)
- Renovate — live bot against Gitea (MintMaker = mapping name only)
- syft — SBOM generator (when baked; `syft_baked=false` until a bake registry exists)
- cosign (Sigstore) — keyless and key-based verify (baked on Showroom PATH)
- oc-mirror v2 — learner-run (baked on Showroom PATH)
- ec — Enterprise Contract CLI (baked on Showroom PATH)
- Spring Boot — scored sample (`spring-boot-lw-poc`)
- CycloneDX / OSV — Lightwell GAV-bound VEX seed
- FastAPI / pip — callouts only (files stay in git; not provisioned)

## Module Map

| Module | Track | Title | Gate |
|--------|-------|-------|------|
| 00 | — | Ungated intro | None (honor-system note; first Check is 1.1) |
| 01 | 1 | 1.1 Verify Hummingbird | Trust policy complete; `cosign verify` on recorded published digest |
| 02 | 1 | 1.2 Mirror into the trust boundary | Learner-run oc-mirror; `cosign verify` on **internal** digest |
| 03 | 2 | 2.1 Enterprise proxy | Maven resolves from Nexus Validated/Remediated (settings.xml they authored) |
| 04 | 2 | 2.2 Remediated pin | Dependency tree shows `.rhlw-*` GAV they pinned |
| 05 | 3 | 3.1 Golden-path source | Learner-owned app repo on Gitea |
| 06 | 3 | 3.2 Bind base + deps in source | Committed `FROM` mirrored Hummingbird + Lightwell pins |
| 07 | 3 | 3.3 Live Renovate | Merged PR from `renovate-bot` (not a hand-edit) |
| 08 | 4 | 4.1 Source forbid-list | Forbidden `FROM`/`curl`/public URL gone from active build files |
| 09 | 4 | 4.2 Prefetch (Hermeto mapping) | Task `prefetch-dependencies` wired; undeclared deps fail |
| 10 | 4 | 4.3 Build NetworkPolicy | `build-egress` tightened on `lw-poc-build` |
| 11 | 4 | 4.4 Build + SBOM | BuildConfig image + SBOM; known-bad Dockerfile still fails |
| 12 | 5 | 5.1 Sign (keyless) | RHTAS keyless `cosign verify` on **app** digest |
| 13 | 5 | 5.2 Attest + Conforma | Weak policy fail then pass after learner tighten |
| 14 | 5 | 5.3 Disconnected verify | Learner TUF root + key-based verify |
| 15 | 6 | 6.1 GitOps + admission | Unsigned deny; stage Application Healthy |
| 16 | 6 | 6.2 Promote to prod repo | Prod Argo sources **prod** remote (not stage) |
| 17 | 7 | 7.1 SBOM system of record | TPA has learner-ingested SBOM for promoted digest |
| 18 | 7 | 7.2 VEX blast radius + ACS | GAV-bound VEX; report CVE fixed via Lightwell; ACS on |

Tracks are the **story**. Modules are gated Check points. Durations are estimates for a two-day workshop envelope; revise after dry runs.

Suggested **content grouping** (not a timer): Day 1 = tracks 1–3. Day 2 = tracks 4–7. Instructor page: `content/modules/ROOT/pages/appendix-instructor-runbook.adoc` (V2-43). Rebalance that page after dry runs; do not cut gated Checks.

Showroom file names can still group by track later (`module-01-hummingbird.adoc` …). Spec grain is the gated list above, not one module per track.

## Difficulty Level

Intermediate to Advanced

## Environment

**Learner view:** RHDP Showroom, dedicated OpenShift claim, one user `student`. Operators and services are already running: Pipelines, GitOps, RHACS, RHTPA, RHDH, Keycloak, Gitea, Nexus, RHTAS. Namespaces: `lw-poc-build` (pipelines / BuildConfig), `lw-poc-staging` (stage app), `lw-poc-prod` (prod app). Python twin is **not** provisioned. Gitea org `lw-student` after Module 2 learner setup. CLIs on Showroom PATH: `oc`, `mvn`, `cosign`, `ec`, `oc-mirror` (not curl from `github.com`). `syft` bake is deferred.

**Automation needed:** Yes

Must be provisioned before learners begin (see GitOps charts; many default-off until the claim enables them):

- OpenShift 4.20+ (CNV) with Pipelines, GitOps, RHACS, RHTPA, RHDH, RHTAS
- Keycloak realm
- Nexus (`lightwell-repo`) seeded Validated/Remediated/OSV + empty dest Docker `hummingbird-mirror`
- Incomplete ImageSet ConfigMap; learner runs oc-mirror (no pre-mirror of scored Hummingbird)
- Gitea templates; learner copies into `lw-student`
- Admission chart (TrustPolicy apply CronJob; no correct ImagePolicy at provision)
- NetworkPolicy seeds (too-open build, open operate)
- Renovate CronJob (default-off until enabled; targets `lw-student/spring-boot-lw-poc`)
- Tekton tasks in `lightwell-tasks`: `verify-base-image`, `conforma-policy`, `prefetch-dependencies` — **not** in the seeded pipeline
- Validate Jobs chart (`lw-poc-validate`): helper + 18 live-state checks + unique report tokens + Job templates (no Job instances at provision). Learners re-run Jobs from Showroom (V2-55).
- RHDH template `lightwell-java-service` (Python template files stay in git, off)
- ConfigMaps: `demo-userinfo-*`, `lightwell-channels`, `lightwell-maven-settings`

## Infrastructure Requirements

- **Cloud provider:** CNV
- **Cluster type:** Multinode
- **OCP version:** 4.20 (minimum; Q8). Claims may already be 4.21.
- **Topology:** Per-student
- **Sizing:** 3 control plane (16 vCPU, 64GB RAM); 2 workers (16 vCPU, 64GB RAM, 2000GB disk)
- **Automation approach:** Ansible (setup) + GitOps Helm + Argo CD
- **AI/MaaS:** None
- **External services (learner egress):** `registry.access.redhat.com` (oc-mirror); `packages.redhat.com` when Nexus is in live-proxy mode. **Not** `github.com`. Gitea is in-cluster. Renovate image pull (`ghcr.io`) is bot-only (V2-24).
- **AAP version:** Not applicable
- **Non-GA products:** None. V2-1: Red Hat Hardened Images / Hummingbird went GA 12 May 2026. Do not list Lightwell or ClusterImagePolicy.

## Assessment Strategy

Classic Showroom **plus** in-cluster **Validate Jobs** (honor system). No guided UI lock. No Solve Job.

Each **gated** module:

1. Short worked example (not paste-identical to the scored file)
2. Learner **changes a real asset**
3. Validate Job inspects cluster/git **state** and a unique short-answer **report** token (ConfigMap per module in `lw-poc-validate`).

Ungated intro has no Job. Catalog wording is `approval_checklist.content.assessment_strategy` in `publishing-house/spec.yaml`.

## What this cluster is not

- Not Project Hummingbird’s Fedora / Konflux factory
- Not FIPS evidence production
- Not a physical air-gap or data diode (5.3 is the procedure)
- Not hosted Konflux (Track 4 is OpenShift Pipelines; mapping appendix only)
- Not a bootc / Satellite / SIEM lab (Track 6 VM is a callout; Epic D)
