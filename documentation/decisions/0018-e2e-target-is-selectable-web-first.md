# 0018 — End-to-end target is selectable, web first

## Context

AGENTS §6.2 runs the end-to-end journeys on an Android emulator. The emulator crashes on the development VM (T-0045), which blocked the whole suite. The Flutter web build runs the same `integration_test` journeys in a headless browser.

## Decision

`make e2e` runs the same journeys on a target chosen with `E2E_TARGET`: `web` (default, headless Chrome for Testing through chromedriver) or `android` (headless emulator). `E2E_STACK=running` reuses a stack that is already up. Journeys live in `app/integration_test/` and never depend on the target; only `tooling/e2e.sh` knows how each target is launched. Chrome for Testing and chromedriver are pinned with checksums in `tooling/versions.env`, installed by `tooling/install-dev-tools.sh` and checked by `make doctor`.

The services allow the web origin through CORS (`CORS_ORIGINS`, default `http://localhost:8090`, set in the local Compose stack only). Android keeps working without it.

## Consequences

The suite runs wherever Chrome runs, so CI does not need an emulator for now. Web cannot prove Android-only behavior (AppAuth redirect, push registration, native layout), so those journeys need the `android` target once the emulator works. `flutter_appauth` does not support web, so the web target signs in with a Keycloak token obtained by the script until T-0006 settles a web sign-in.
