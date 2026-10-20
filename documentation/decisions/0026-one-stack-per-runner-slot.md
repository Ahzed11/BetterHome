# 0026 — Each runner gets its own stack, chosen by a slot

## Context

The local stack (Podman Compose: Postgres, Keycloak, five services) used fixed names and ports: project `betterhome` (network, containers and volume names), host ports 5432, 8081-8085, 8180, the web app on 8090 (also written into the Keycloak realm's redirect URIs), chromedriver on 4444, and the `e2e` job's Podman socket and process files under `/tmp`. Two stacks on one host were therefore one stack: the second `up` reused the first one's containers and Postgres volume, a Keycloak lookup by project name could reach the other run's Keycloak, and one job's teardown (`make down`, `pkill` on the shared socket) destroyed the other's. ADR 0024 avoided this by letting a single self-hosted runner (`fallback-e2e`) take the `e2e` job, so e2e jobs queue instead of running together. That is serialization, not isolation, and it does not help two agents or a runner and a developer sharing a machine.

## Decision

A stack is identified by a **slot**, a digit 0-9, set by `E2E_SLOT`. When it is not set, a self-hosted runner named `<name>-<n>` takes slot `n-1` and everything else takes slot 0 (`tooling/stack-env.sh`). The slot decides the Compose project name (`betterhome` for slot 0, `betterhome-s<slot>` otherwise) and shifts every host port by `slot * 1000` (slot 1: services 9081-9085, Keycloak 9180, web app 9090, chromedriver 5444, Postgres 6432). Slot 0 keeps today's names and ports, so nothing changes for a developer who sets nothing.

`stack-env.sh` is the single place that knows the names and ports; the Makefile, the deploy scripts, `e2e.sh` and `run-app.sh` read them from it, and `podman-compose.yml` takes them with the old values as defaults. Keycloak listens on the same number inside and outside its container, because tokens issued for `localhost:<port>` and validated by services as `keycloak:<port>` must carry one issuer. Container-side ports of the services and the in-network names (`postgres`, `keycloak`, `*-service`) stay fixed, since the project network is private. The realm file is rendered per stack by `make up` (`deploy/render-realm.sh`) so its web origin follows the slot's web port; the checked-in file keeps 8090.

The `e2e` job runs on any runner: its Podman socket, process files and Chrome wrapper live in `$RUNNER_TEMP`, `pkill` matches only its own socket, and it runs `make down` for its own project before starting, because a self-hosted runner keeps whatever a killed run left behind.

## Consequences

- The `fallback-e2e` label is no longer needed: ADR 0024's rule that only the first runner takes `e2e` is replaced by this one. Its advice on the number of runners still stands, because isolation does not add CPU or memory (with two or three runners on the 8-core, 15 GB machine, Testcontainers' Postgres already took 150-200 s to start).
- Runner names are what pick the slot by default. A runner whose name does not end in `-<n>` gets slot 0, so two such runners would collide again: set `E2E_SLOT` in each runner's `.env` file.
- Backend jobs were already isolated (Testcontainers Postgres on a random port, `quarkus.http.test-port=0`, T-0093) and are unchanged.
- The Chrome for Testing install under `~/dev-tools/chrome` is shared by the runners and is only written when its pinned version changes, so the first run after a version bump should not overlap another `e2e` job.
- Slots above 9 are refused, which keeps every port below 65535.
