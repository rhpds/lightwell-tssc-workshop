# Promote (Module 6.1)

After a successful signed build in `lw-poc-build` (`student_build_namespace`):

1. Tag the image into the stage namespace ImageStream. Showroom 6.1 has the exact `oc` commands.
2. `cosign copy` the build ImageStream to the dest digest, then `cosign sign --key` the dest. `oc tag` copies the image. It does not copy `.sig` tags.
3. Read the ImageStream digest (`sha256:…`).
4. Edit `values.yaml`:
   - set `image.digest` to that digest (include the `sha256:` prefix)
   - leave `replicas: 0`
5. Commit and push to **this** Gitea gitops remote, then hard-refresh the stage Application. Healthy at 0 replicas is expected.
6. Fill `admission/trust-policy.yaml` on this remote (`enforce: true`, no `REPLACE_ME`). Wait until ImagePolicy exists in the stage and prod namespaces and `oc get mcp` shows `UPDATING` False on master and worker.
7. Set `replicas: 1`, commit, and push. Hard-refresh again. That first pull is the one the node checks.

Do not put Maven credentials or registry tokens in this repository.
