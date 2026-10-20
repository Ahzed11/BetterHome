# 0026 — Publish the service images to GHCR on every merge into master

## Context

The images were only built locally by Compose. Deploying to OpenShift (T-0004, T-0035) needs images in a registry that the cluster can pull from, built from exactly the merged commit.

## Decision

[publish-images.yml](../../.github/workflows/publish-images.yml) runs on every push to `master` (a merged pull request) and on demand (the job only runs on `master`, so a manual run from another branch cannot move `latest`). It builds the jars with the Maven wrapper, builds the five images with Podman through `tooling/build-images.sh` (the same script works locally and on the self-hosted runner, which has no Buildx) and pushes `ghcr.io/<owner>/betterhome-<service>` tagged with the commit SHA and `latest`. It authenticates with the job's `GITHUB_TOKEN` (`packages: write`, granted to this job only), so no secret is stored. It follows `CI_RUNNER` like [check.yml](../../.github/workflows/check.yml). Runs are queued, never cancelled, so `latest` ends on the newest merge. It does not re-run the tests: merging already required a green `check`.

## Consequences

Images are traceable to a commit. Packages inherit the repository's visibility (private), so the cluster needs a pull secret. Images are not signed and not scanned yet, and tags are mutable (`latest`); the SHA tag is the one to deploy. The first publication cannot be tested before the first merge: a failure shows as a red `publish-images` run on `master`, which AGENTS §10 says to fix first.
