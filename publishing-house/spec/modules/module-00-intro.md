# Module 00 — Trusted supply chain (ungated intro)

### Brief Overview

Ungated orientation for the seven-track TSSC flow. Learners see what a trusted software supply chain is, how Lightwell Network and Lightwell Clearinghouse Premier fit (Network is scored; Premier is limited-availability and reuses the same proxy/pin/SoR controls), the story (Hummingbird → Lightwell → source → build → sign → prod container → compliance), what this cluster is **not**, and that progress is honor-system (Validate Jobs exist; URLs still work). **No Validate Job.** First Check is 1.1 (V2-31). AsciiDoc page is V2-42 (`index.adoc`).

### Audience and Time

- **Personas:** Application developers, DevSecOps, platform engineers
- **Prerequisites:** RHDP Showroom; oc available
- **Estimated duration:** ~20 min (ungated — no Validate Job)

### Learning Objectives

- State what TSSC proves (named inputs, who built and signed the image, whether vulns are remediated without treating the public internet as trusted)
- Contrast Lightwell Network (available Validated/Remediated catalog, public Disclosure / OSV / VEX) with Lightwell Clearinghouse Premier (limited availability; member-specific versions and embargoed remediations still land in the same enterprise proxy)
- Name the seven TSSC tracks in order and which TSSC objective each observes
- State three things this claim does not pretend to be (hosted Konflux, physical air-gap, Hummingbird factory)
- Know that each later module has a Your change + Check (honor system)

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | What is TSSC; LWN vs Clearinghouse Premier | TBD |
| 2 | How this workshop maps to TSSC (trust chain) | TBD |
| 3 | Seven-track diagram | TBD |
| 4 | What this cluster is not | TBD |
| 5 | Honor system / Validate Jobs | TBD |
| 6 | Official documentation | TBD |

### Detailed Steps

1. Define TSSC and the Red Hat control stack (RHTAS, RHTPA, ACS, GitOps, Pipelines, RHDH). **Visual:** https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/109
2. Contrast Lightwell Network vs Clearinghouse Premier (no SKUs/pricing). Premier is not a second path. **Visual:** https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/110
3. Map tracks to TSSC objectives and the artifact trust chain. **Visual:** https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/111
4. Show the seven-track linear diagram (not FSI-branded). **Visual:** https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/48 — do not invent the PNG here.
5. Call out: Java is scored; Python and Artifactory are in-module callouts; no Modules 7–9 FastAPI path.
6. What this is not: not Konflux-on-the-claim; not a data diode; not FIPS lab evidence; not a live Premier membership; VM/bootc is a Track 6 sentence.
7. Honor system: Validate Jobs grade live cluster/git state and a unique report token; no UI lock; no Solve. Shared rerun snippet is `partials/validate-job-rerun.adoc`.
8. Point at `demo-userinfo-*` ConfigMaps for discovery. Do not send learners to GitHub for lab git.
9. Enablement is **after** the workshop: internal seven-track checklist (V2-46 / `appendix-enablement-checklist.adoc`). Not a live PoV. No visual on that page.

### Key Takeaways

- One linear flow; coverage-first gated modules, not v1 Java-then-Python.
- TSSC is the controls; Lightwell Network is the scored library input; Clearinghouse Premier reuses those controls.
- First scored Check is 1.1, not this page.

### Infrastructure Notes

- No cluster mutation required for this page.
- Diagram assets: `content/modules/ROOT/images/` once the visual issues land (48, 109, 110, 111).
