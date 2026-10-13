# 0012 — Golden tests compared on one platform

## Context

Flutter golden pixel tests differ across operating systems and font renderers.

## Decision

Golden images are produced and compared on Linux only (`make update-goldens` / CI Linux runners).

## Consequences

Developers on macOS/Windows regenerate goldens via Linux (CI or container). Cross-OS golden failures are not treated as product bugs.
