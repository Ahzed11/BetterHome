# 0024 — A self-hosted fallback runner for when hosted minutes run out

> The `fallback-e2e` label and the rule that only the first runner takes `e2e` are replaced by [ADR 0026](0026-one-stack-per-runner-slot.md): every runner has its own stack.

## Context

CI runs on GitHub-hosted runners, which are billed in minutes on this private repository. When the quota is exhausted, jobs fail without starting a step. GitHub has no built-in "try hosted, then self-hosted", and an automatic fallback after any failure would run real test failures twice.

## Decision

A GitHub Actions runner labelled `fallback` is installed on the development machine (`~/actions-runner`, user service `github-runner.service`, registered to this repository only). Every job in [check.yml](../../.github/workflows/check.yml) uses `runs-on: ${{ vars.CI_RUNNER || 'ubuntu-24.04' }}`. By default CI runs hosted. When the minutes run out, set the repository variable `CI_RUNNER` to `fallback`; delete it to switch back. Three runners (`fallback`, `fallback-2`, `fallback-3`, one directory and user service each) are installed, but only the first is enabled. Running the jobs in parallel first failed on a fixed test port (fixed by T-0093), and then, with the port fixed, made CI less reliable on this 8-core, 15 GB machine: with two or three runners, `e2e` failed in 3 of 5 runs and Testcontainers' Postgres took 150-200 s to start (timeout) in several backend jobs; with one runner `e2e` passed 4 of 5. Reliability won over speed: one runner, jobs one after another (about 15 minutes). To try parallelism again: `systemctl --user enable --now github-runner-2`, and watch `e2e` and the backend jobs. The `e2e` job needs the label `fallback-e2e`, carried by the first runner only, because its stack uses fixed ports and a project name: e2e jobs queue there, which a `concurrency` group would not do without cancelling queued runs. The service sets `DOCKER_HOST` to the user's Podman socket so Testcontainers works; the workflow no longer sets `DOCKER_HOST`, since the default socket is the hosted one.

## Consequences

The switch is manual and visible, with no double runs. The runner executes workflow code as the machine's user with no isolation, so it is acceptable only while the repository is private with trusted collaborators; do not enable it for fork pull requests. The machine must be on, and its local stack (`make up`, `make e2e`) must not run at the same time (fixed ports). Golden images are compared on one platform (ADR 0012), so the fallback host's Linux image rendering may differ from Ubuntu's; the first run on it must confirm `make test-app` passes.
