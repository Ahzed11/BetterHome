# 0011 — Recurrence computation in Quarkus services

## Context

Task recurrence uses RRULE and household timezones (including DST).

## Decision

Compute next-run times inside the tasks microservice (Quarkus), not in SQL triggers or the Flutter client. A testable domain component owns RRULE evaluation against the injectable `Clock`.

## Consequences

Scheduler jobs claim due rows with `FOR UPDATE SKIP LOCKED`. Timezone bugs are covered by unit tests with a fake clock.
