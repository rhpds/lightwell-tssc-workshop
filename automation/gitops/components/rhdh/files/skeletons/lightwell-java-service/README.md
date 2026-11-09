# ${{ values.name }}

${{ values.description }}

Created with the Lightwell Java Service Software Template in Red Hat Developer Hub.
The source lives on the in-cluster Gitea server under `${{ values.repoOwner }}`.
The Software Catalog records this component's owner as `${{ values.owner }}`.

Follow Showroom module 3.1 to review the task, catalog entry, and repository,
then grant Renovate access and prepare the separate stage/prod GitOps repositories.
In module 3.2, edit the runtime Dockerfile FROM and the default Maven version.
In module 3.3, review Renovate's PR on `lightwell-pins.properties`.

The UBI runtime, upstream default dependency, stale pins, and incomplete pipeline
are intentional exercise inputs. `Dockerfile.known-bad` is a negative fixture,
not the active build file. Track 4 completes the build controls before producing
an image. See [docs/MODULES.md](docs/MODULES.md) for the remaining track sequence.

Discover claim-specific URLs and credentials from the workshop lab ConfigMaps.
Keep credentials out of commits and screenshots.
