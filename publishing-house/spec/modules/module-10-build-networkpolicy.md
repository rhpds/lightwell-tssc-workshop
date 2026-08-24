# Module 10 — 4.3 Build NetworkPolicy

### Brief Overview

`NetworkPolicy` `build-egress` on `lw-poc-build` is seeded **too open**. Learner tightens to deny-egress with DNS + internal registry + Nexus (Gitea in-cluster). **Do not** copy this policy onto app namespaces (`app-operate` on staging/prod stays operate — Track 6).

### Audience and Time

- **Prerequisites:** 4.2; `demo-userinfo-networkpolicy`
- **Estimated duration:** ~25 min

### Learning Objectives

- Replace allow-all egress with the documented allow-list
- Confirm the policy is live on `lw-poc-build` only
- Not score `registry.redhat.io` on the hermetic list

### Lab Structure

| Section | Title | Duration |
|---------|-------|----------|
| 1 | Two policies, two Checks | TBD |
| 2 | Your change: tighten build-egress | TBD |
| 3 | Check: NP spec | TBD |

### Detailed Steps

1. `oc get networkpolicy build-egress -n lw-poc-build` — seed allow-all.
2. Worked example `example-hermetic-egress.yaml` uses fake ns + public CIDR.
3. Learner applies deny-egress + DNS 5353 + image-registry 5000 + Nexus 8081/5000.
4. Check: policy exists, not allow-all, not copied to `lw-poc-staging`.
5. After tighten, Route clones and public Maven hang; kubelet Task-image pulls may still succeed — do not teach “apply Pipeline in 4.2 caches the image” (#106).
6. **Visual:** build hermetic vs app operate NetworkPolicy — `content/modules/ROOT/images/np-build-vs-app-operate.png` (https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/51). Skip a YAML screenshot (Check grades the live object).

### Key Takeaways

- Build hermetic ≠ app operate.
- Gitea is internal git, not a public registry allow.

### Infrastructure Notes

- V2-21 chart wave 10. Validate Job V2-54.
