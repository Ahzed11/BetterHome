# 0024 — A self-hosted fallback runner for when hosted minutes run out

## Context

CI runs on GitHub-hosted runners, which are billed in minutes on this private repository. When the quota is exhausted, jobs fail without starting a step. GitHub has no built-in "try hosted, then self-hosted", and an automatic fallback after any failure would run real test failures twice.

## Decision

A GitHub Actions runner labelled `fallback` is installed on the development machine (`~/actions-runner`, user service `github-runner.service`, registered to this repository only). Every job in [check.yml](../../.github/workflows/check.yml) uses `runs-on: ${{ vars.CI_RUNNER || 'ubuntu-24.04' }}`. By default CI runs hosted. When the minutes run out, set the repository variable `CI_RUNNER` to `fallback`; delete it to switch back. The service sets `DOCKER_HOST` to the user's Podman socket so Testcontainers works; the workflow no longer sets `DOCKER_HOST`, since the default socket is the hosted one.

## Consequences

The switch is manual and visible, with no double runs. The runner executes workflow code as the machine's user with no isolation, so it is acceptable only while the repository is private with trusted collaborators; do not enable it for fork pull requests. The machine must be on, and its local stack (`make up`, `make e2e`) must not run at the same time (fixed ports). Golden images are compared on one platform (ADR 0012), so the fallback host's Linux image rendering may differ from Ubuntu's; the first run on it must confirm `make test-app` passes.
