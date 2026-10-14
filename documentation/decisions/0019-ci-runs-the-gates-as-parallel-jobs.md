# 0019 — CI runs the gates as parallel jobs

## Context

One job ran `make check`: docs, then the five services one after another in a single Maven reactor, then the app. A green check took about 5 minutes, of which about 3m47 was the services built in sequence (each starts its own PostgreSQL through Dev Services), plus 39 s of Flutter setup that the backend does not need.

## Decision

[.github/workflows/check.yml](../../.github/workflows/check.yml) runs the same gates as parallel jobs: `docs` (`make test-docs`), one `backend` job per directory under `backend/services` (`make test-backend SERVICE=<name>`, which builds common-domain with it), and `app` (`make test-app`). The service list is read from the directory, so a new service is covered without editing the workflow. A final job named `check` needs all of them and fails unless each succeeded; it is the one result to require on `master` (T-0053). `make check` is unchanged for local use.

## Consequences

The wait is the slowest job instead of the sum (about 1.7 minutes expected, from about 5). More runner minutes are used in total, and common-domain is built once per service job. A gate added to `make check` must also be added as a job; the header comment of the workflow says so. The full-reactor `make test-backend` (no `SERVICE`) remains what `make check` runs.

Update (T-0073): an `e2e` job runs `make e2e` (web target) beside these jobs, and the `check` job requires it too.
