# AGENTS.md

Guidance for agents working in this repository.

## What this repository is

This is the Red Hat Demo Platform (RHDP) Showroom lab **Lightwell Software Supply Chain Security Workshop**. A learner walks one trusted software supply chain on a dedicated OpenShift claim: verify a Hummingbird base, consume Lightwell dependencies, own the application source, build hermetically, sign and attest, promote a production container, then prove continuous compliance.

Java (Maven, `spring-boot-lw-poc`) is the scored application. Python (`pip`) and Artifactory appear as short callouts on the same pages. JavaScript libraries are the same pattern (an enterprise npm registry and an exact package version) and are something the learner can describe; the exercises stay on the Java application. There is no second hands-on path.

The story is seven tracks. Modules are the gated pages inside those tracks.

| Track | What the learner does | Pages |
| --- | --- | --- |
| 1 Hummingbird | Verify the published base, then mirror it into the trust boundary | `module-01`, `module-02` |
| 2 Lightwell dependencies | Point Maven at the enterprise proxy and pin an exact `.rhlw-*` version | `module-03`, `module-04` |
| 3 Application source | Own the app on in-cluster Gitea, bind the base and pins, merge a live Renovate PR | `module-05` through `module-07` |
| 4 Hermetic build | Forbid public fetches, prefetch dependencies, tighten build egress, produce an image and SBOM | `module-08` through `module-11` |
| 5 Sign and attest | Keyless sign, Conforma policy, disconnected verify | `module-12` through `module-14` |
| 6 Production container | Stage GitOps with unsigned-deny admission, then promote the signed digest to the prod repo | `module-15`, `module-16` |
| 7 Continuous compliance | Ingest the SBOM into Trusted Profile Analyzer and report the CVE as remediated via the Lightwell pin | `module-17`, `module-18` |

`index.adoc` is the ungated map. `module-00-intro.adoc` includes it. Appendices (`appendix-*.adoc`) are reference, not gated Checks.

## Repository layout

| Path | What it is |
| --- | --- |
| `content/modules/ROOT/pages/` | Showroom AsciiDoc. This is the learner-facing lab. |
| `content/modules/ROOT/nav.adoc` | Showroom navigation. |
| `content/modules/ROOT/images/` | Diagrams and screenshots cited by `image::` macros. |
| `content/antora.yml` | Antora component name, nav, and page attributes (`{java-validated-url}`, `{student_username}`, and the rest). |
| `site.yml` | Antora playbook. `antora generate site.yml` writes the static site to `www/`. |
| `publishing-house/spec.yaml` | Project spec: title, learning objectives, module list, environment. Read this for project state. |
| `publishing-house/spec/design.md` | Design narrative and module map. |
| `publishing-house/spec/modules/` | Module outlines that the AsciiDoc pages implement. |
| `automation/gitops/components/` | OpenShift GitOps for the claim (Gitea, Nexus, Pipelines, RHTAS, RHTPA, RHACS, validate Jobs, and the rest). |
| `qa-automation/` | Health-check and end-to-end playbooks. |
| `.cursor/rules/content-visuals.mdc` | When a picture would teach better than prose, file a separate visual issue. Do not invent a PNG. |

`mkdocs.yml` is a TechDocs stub and still lists the retired module set. Do not treat it as the lab map. There is no `manifest.yaml`.

## Rules

- Read `publishing-house/spec.yaml` before changing scope, module order, or learning objectives. Do not edit `stage.current`; stage transitions are managed outside this repo.
- Keep one linear Java path. A Python, Artifactory, or JavaScript equivalent is a short callout on the page that owns the control. Do not add a second application, a second track, or a second Check.
- Use attributes from `content/antora.yml` for product URLs and lab identity. Discover claim-specific hosts, digests, and passwords from `demo-userinfo-*` ConfigMaps in the prose. Do not hard-code Route hosts or send learners to GitHub for lab git. Gitea is in-cluster.
- Leave credentials out of pages and commits (`LW_USERNAME`, `LW_PASSWORD`, `student_password`, `cosign.key`).
- A wording change in a module does not authorize a GitOps or Validate Job change. Touch `automation/` or `qa-automation/` only when the task is about cluster behavior.
- Diagrams go in `content/modules/ROOT/images/` and are included with a descriptive alt and `width=700,link=self,window=blank`. Follow `.cursor/rules/content-visuals.mdc` when the asset does not exist yet.

## Module voice

Treat each module as a blog post in voice, clarity, and detail.

This applies to `content/modules/ROOT/pages/module-*.adoc`, and to `index.adoc`, `conclusion.adoc`, and an appendix when the task is to explain rather than to tabulate. Use it on the next content prompts.

**Voice.** Write to one reader, in the second person, in complete sentences. Sound like a technical blog that walks a colleague through a decision, then shows the command. Name the product and the control in workshop language before the syntax. Do not write a ticket checklist, a release note, or a product brochure.

**Clarity.** Open with the point of the page: what the learner will prove, and why this page sits in the track. Give each section one idea. Define a term at the moment it matters. Say what success looks like before the command block.

**Detail.** Name the object, the namespace, the file, and the outcome so a reader can follow the step before they are on the cluster. Keep the lab spine: why this control exists, learning objectives, the explanation, **Your change**, then **Check**. Detail belongs in the explanation. It does not replace the commands or the Validate Job.

A callout stays a short note inside the post. It is not a second article.

```adoc
// Thin: a heading and a command, with no reason.
== Your change
[source,bash]
----
oc apply -f settings.xml
----

// Blog post: the decision, then the scored action.
Field delivery puts an enterprise artifact manager between developers and `packages.redhat.com`.
On this claim that stand-in is in-cluster Nexus.
You complete ConfigMap `stub-03-enterprise-proxy` so Maven resolves a Validated GAV from Nexus.
Copying the finished `lightwell-maven-settings` file fails the Check.
```
