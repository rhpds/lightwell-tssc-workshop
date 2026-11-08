# Modules 7–9 — using this scaffold

This tree is the **canonical learner FastAPI application** after the RHDH
Software Template `lightwell-python-service` publishes to Gitea `fastapi-lw-poc`
(Module 7+ scaffold step — mirrors Module 3 for Java).

| Module | Focus | Assets here |
|--------|--------|-------------|
| 7 | Scaffold + PyPI Validated | `requirements.txt`, `pip.conf` |
| 8 | Remediated PyPI (always on) | `pip-remediated.conf`, `lw-workshop-pypi==*+rhlw.*` |
| 9 | Pipeline / signing / GitOps | `.tekton/` (dep-gate → BuildConfig → ACS → SBOM → cosign) |

Clone URL: ConfigMap `lab-gitea` → `student_python_repo_url` (not GitHub).

Promote: `student_python_gitops_repo_url` → Argo app `student_python_argocd_app`
(`lw-fastapi-student`).

Flow: Module 7 learner seed (`student-seed-python-from-templates.sh`) first, then
delete `lw-student/fastapi-lw-poc` and re-publish with this template (Java
Module 2 → Module 3 pattern).
