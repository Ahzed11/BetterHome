# 0013 — Push notification gateway behind a `PushSender` seam

## Context

Push delivery must not couple domain transactions to vendor SDKs.

## Decision

Domain code writes an outbox row in the same transaction as the change, then a worker calls `PushSender`. Phase 0 ships `NoOpPushSender`.

## Consequences

Tests assert outbox contents. The real gateway is wired in Phase 4 without changing call sites.

## Update

The vendor behind the seam is Gotify, not FCM / APNs: see [ADR 0027](0027-push-through-gotify.md).
