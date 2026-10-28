# Promote (Module 9)

After a successful signed build in your **lab** namespace:

1. Discover promote targets from `lab-gitea`:

```bash
oc -n gitea get configmap lab-gitea \
  -o jsonpath='{.data.student_python_promote_namespace}{"\n"}{.data.student_python_argocd_app}{"\n"}{.data.student_python_gitops_repo_url}{"\n"}'
```

2. Tag the lab ImageStream into the product namespace (replace placeholders):

```bash
PROMOTE_NS="$(oc -n gitea get configmap lab-gitea -o jsonpath='{.data.student_python_promote_namespace}')"
oc tag <lab-namespace>/fastapi-lw-poc:latest "${PROMOTE_NS}/fastapi-lw-poc:latest"
```

3. Read the ImageStream digest (`sha256:…`):

```bash
oc -n "${PROMOTE_NS}" get istag fastapi-lw-poc:latest -o jsonpath='{.image.dockerImageReference}{"\n"}'
# Use the digest portion (sha256:…) for image.digest
```

4. Edit `values.yaml` in **this** gitops remote:
   - set `image.digest` to that digest (include the `sha256:` prefix)
   - set `replicas: 1`
5. Commit and push to `student_python_gitops_repo_url`.
6. Confirm Argo CD Application `student_python_argocd_app` (`lw-fastapi-<username>`) is Synced/Healthy and open the Route.

Do not put PyPI credentials or registry tokens in this repository.
