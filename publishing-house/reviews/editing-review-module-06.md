# Editing Review — Module 06: Pipeline, Signing, Policy, and GitOps Promotion (Java)

**File:** `content/modules/ROOT/pages/module-06-pipeline.adoc`
**Review date:** 2026-08-12
**Reviewer:** rhdp-publishing-house:module-reviewer

---

## Summary

| Dimension | Score | Findings |
|-----------|-------|----------|
| Structure | 0.60 | 1 |
| Pedagogy | 0.60 | 1 |
| Style | 0.80 | 4 |
| Technical Accuracy | 0.60 | 3 |
| Formatting | 0.90 | 1 |
| Intro Quality | 1.00 | 0 |
| Demo Structure | 1.00 | 0 |

**Total findings:** 9 (2 High, 3 Medium, 3 Warning, 1 Warning-intro)

---

## Findings

### HIGH — `@@LW_USER@@` literal placeholder in executable code blocks (E.4)

**Lines:** 144, 487  
Two `role=execute` code blocks set `STUDENT_USER='@@LW_USER@@'`. This is neither an Antora AsciiDoc attribute (`{student_username}`) nor a bash variable — it renders literally. When learners click execute, the git clone and git push URLs embed the literal string, causing both commands to fail immediately.

**Fix:** Replace with a dynamic ConfigMap lookup matching the pattern already used elsewhere in the module:
```bash
export STUDENT_USER="$(oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_username}')"
```

---

### HIGH — `[source,bash]` block missing `role=execute` (E.3a)

**Line:** 252  
The fallback `oc -n stackrox create secret generic rhacs-ci-secrets` block is annotated `[source,bash]` without `role=execute`. In classic Showroom, learners who reach this step will not see the terminal execute button.

**Fix:** Add `role=execute`, or wrap in a NOTE admonition if this is intentionally an instructor-only step.

---

### MEDIUM — Em dashes in prose (C.6 / D.8)

**Lines:** 250, 618, 619  
- Line 250: `continue—treat`
- Line 618: `` rhacs-ci-token-mint`)—learners ``
- Line 619: `(Fulcio/Rekor)—do not`

**Fix:** Replace with a comma, semicolon, or restructured sentence.

---

### MEDIUM — Broken list nesting at lines 122–125 (C.7)

**Lines:** 122–125  
Bullet sub-items ("Expected log themes") immediately follow a numbered step at line 122 with no blank line and no `+` continuation marker. AsciiDoc renders these as a disconnected unordered list rather than content nested under step 4, breaking the numbered sequence visually.

**Fix:** Add a `+` continuation marker before the `*` list or restructure as a separate paragraph.

---

### WARNING — Heading capitalization ambiguity (C.9)

**Line:** 49  
`== Architecture of the lab Pipeline` — "Pipeline" is mid-heading capitalized. If this refers to Tekton/OpenShift Pipelines as a branded product name, the intent should be documented. Otherwise lowercase to `pipeline` for sentence-case consistency.

---

### WARNING — Acronyms `VEX` and `SLSA` not expanded (D.2)

**Lines:** 10, 619  
- `VEX` (line 10) — Vulnerability Exploitability eXchange — not expanded in this module
- `SLSA` (line 619) — Supply-chain Levels for Software Artifacts — not expanded in this module

These are first used in Module 05 (SBOM) and Module 01 respectively, so if learners skip those modules, the expansions are unavailable.

**Fix:** Add parenthetical expansions on first use in this module.

---

### WARNING — 3 images missing `link=self,window=blank` (C.1)

**Lines:** 79, 454, 569  
- `module-06-fail-then-pass.png`
- `module-06-rhtas-cosign.png`
- `module-06-argocd-promote.png`

**Fix:** Add `link=self,window=blank` to each image macro's attribute list.

---

### MISSING VERIFY — No `=== Verify` sections in any of 4 exercises (B.12)

All 4 exercises embed verification commands inline (as numbered sub-steps or bullet sub-lists) rather than in a dedicated `=== Verify` section. Classic Showroom pattern requires explicit verification headings.

**Fix:** Add `=== Verify` subsections after each exercise's procedure steps.

---

## Spec Alignment Checks

### SA-1: Outline Coverage — PASS
All outline sections covered: Tekton pipeline architecture, dep-gate trigger, RHACS scan, cosign signing, Argo CD GitOps promotion.

### SA-2: Learning Objectives Match — PASS
4 learning objectives present matching outline-defined goals.

### SA-3: Duration Alignment — PASS
Content volume consistent with 45-minute target (longest module).

### RS-1: Product Name Accuracy — PASS
RHTAS, RHACS, Argo CD, OpenShift Pipelines all use correct full names.

### RS-2: Version Consistency — PASS
No hardcoded OCP version strings; cosign v2.4.3 is a third-party tool pin, not an OCP attribute.

---

## Items Verified Clean

- 4 learning objectives present (≥3 required)
- 4 exercises present (≥2 required)
- All exercise steps use numbered lists
- All code blocks carry `[source,<lang>]` annotations; no bare blocks
- `include::partial$student-username-form.adoc[]` resolves correctly
- YAML PipelineRun heredoc uses consistent 2-space indentation
- All images have descriptive alt text
- All `xref:` links correctly omit `^`; no bare external links without `^`
- All headings sentence-case (except line 49 noted above); no skipped heading levels
- `oc` subcommands lowercase throughout (get, create, apply, tag, annotate, wait, logs)
- All other bash blocks carry `role=execute` (except line 252)
- No undefined `{attribute}` references; all attribute uses are in `antora.yml`
- No vague marketing terms, unsupported superlatives, non-inclusive language
- Gender-neutral pronouns; Oxford comma present; no hardcoded OCP version strings

---

## Recommended Priority

1. **Fix `@@LW_USER@@`** at lines 144 and 487 — breaks git clone/push for all learners
2. **Add `role=execute`** to line 252 — missing terminal execute button
3. **Add `=== Verify` sections** to all 4 exercises — required for classic Showroom pattern
4. **Fix list nesting** at lines 122–125 — rendering bug
5. **Replace em dashes** at lines 250, 618, 619
6. **Expand VEX and SLSA** at lines 10 and 619
7. **Fix heading capitalization** at line 49
8. **Add image link attributes** — lightbox usability (3 images)
