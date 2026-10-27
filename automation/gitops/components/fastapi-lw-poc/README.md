# charts/components/fastapi-lw-poc — Python FastAPI sample (Modules 7–9)

Learner workload: **FastAPI / Python** greeting API with OpenAPI, demonstrating Lightwell Network **Validated** and **Remediated** (`.rhlw-*`) PyPI consumption.

Mirrors [`spring-boot-lw-poc`](../spring-boot-lw-poc/) for the Python track (epic [#144](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/144), issue [#146](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/146)).

## Layout

```
fastapi-lw-poc/
├── Chart.yaml / values.yaml / templates/   # GitOps deploy (Deployment, Route, docs)
└── app/                                    # Python project sources (Gitea isolation root)
    ├── requirements.txt.example            # FastAPI + uvicorn + httpx; Gitea seed → requirements.txt
    ├── pip.conf                            # Validated index + public PyPI fallback
    ├── pip-remediated.conf                 # Remediated index (always on for this workshop)
    ├── Dockerfile
    └── main.py
```

## Dependency model (mirror of Java commons-lang3)

| Package | Source | Role |
|---------|--------|------|
| `fastapi`, `uvicorn` | Public PyPI | Framework (Dockerfile + local venv) |
| `httpx==0.27.2` | Lightwell **Validated** (seeded Nexus) | LWN demo dependency |
| `lw-workshop-pypi==1.0.0+rhlw.00001` | Lightwell **Remediated** (required) | Module 8 `.rhlw-*` marker |

### Why `requirements.txt` (not `pyproject.toml`)

Workshop labs and most client FastAPI estates still standardize on `pip install -r requirements.txt`. That keeps Module 7–9 copy-paste close to Tekton/`pip` CI.

**`pyproject.toml` implications (for authors / client ports):** PEP 621 / Poetry / uv projects may declare the same pins under `[project] dependencies` (or tool-specific lockfiles). If you adopt `pyproject.toml` later, keep `httpx==0.27.2` as the LWN Validated pin, preserve a pip-installable path for Showroom (export/sync a `requirements.txt` or document `pip install .`), and do not make Gitea isolation or Module labs depend on Poetry/uv unless the pipeline Tasks (#149) are updated to match.

## Learner commands

Students use the **Gitea** FastAPI remote (seeded from `workshop-templates` via
[#147](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/147)),
not a monorepo checkout. Discover `student_python_repo_url` /
`template_python_app_repo_url` from ConfigMap `demo-userinfo-gitea`; Module 7
runs `student-seed-python-from-templates.sh`. Operators still author sources
under `./app` in this chart.
The GitHub copy of the pip manifest is `app/requirements.txt.example` so
Dependabot cannot bump the scored `httpx==0.27.2` pin. Seed renames it to
`requirements.txt` on Gitea. Local operator pip: `pip install -r requirements.txt.example`.

```bash
# Learner (Showroom): clone Gitea fastapi-lw-poc — requirements.txt at repo root
cd /tmp/fastapi-lw-poc
export LIGHTWELL_NEXUS_URL=https://nexus-lightwell-repo.apps.<domain>
# Rewrite NEXUS_BASE in pip.conf, or use ConfigMap lightwell-pip-settings
python3 -m venv .venv && source .venv/bin/activate
PIP_CONFIG_FILE=$PWD/pip.conf pip install -r requirements.txt
PIP_CONFIG_FILE=$PWD/pip.conf pip install --force-reinstall --no-deps httpx==0.27.2
uvicorn main:app --host 0.0.0.0 --port 8080

# Remediated marker (Module 8 — channels.pypiRemediated.enabled=true):
PIP_CONFIG_FILE=$PWD/pip-remediated.conf pip install lw-workshop-pypi==1.0.0+rhlw.00001

# SBOM for RHTPA
syft packages dir:. -o spdx-json > sbom.spdx.json
```

Endpoints (after Route is up): `/api/greeting`, `/api/healthz`, `/docs`.

## Image / deploy

Default `replicas: 0` and empty `image.digest` keep Argo **Healthy** before promote.

1. Prefer digest pin after Module 9 promote: set `image.digest: sha256:…` and `replicas: 1`.
2. When `image.repository` is empty, the image is derived as `{registry}/{namespace}/{name}`.
3. Chart renders an ImageStream for `oc tag` promote into the product namespace.
4. **Workshop runtime path:** keep root-app `components.fastapiLwPoc.enabled=false` (V2-12). Chart files stay in git for V2-44 / V2-90. Do not create namespace `lw-fastapi-student`.

## Sync waves

| Wave | Resources |
|------|-----------|
| `0` | Namespace |
| `1` | Lab docs ConfigMap + ImageStream |
| `2` | Deployment + Service |
| `3` | Route |
| `4` | RHDP userinfo |

Root App-of-Apps places this chart at sync wave **`40`**.

## Related

- Issue [#146](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/146)
- Epic [#144](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/144)
- Artifact manager PyPI: [#145](https://github.com/NA-FSI-Services/lightwell-tssc-workshop/issues/145)
- Java twin: [`spring-boot-lw-poc`](../spring-boot-lw-poc/)
