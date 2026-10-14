# 0023 — Property tests with jqwik and mutation tests with Pitest

## Context

AGENTS §5.1 asks for invariant tests (round robin never picks an ineligible member, the ledger adds up, scores never go negative) and for periodic mutation testing of `tasks` and `scoring`. Example-based tests only check the cases someone thought of.

## Decision

- **jqwik 1.10.2** (EPL-2.0, a JUnit Platform engine, test scope only, managed in the backend `pom.xml`, declared in tasks-service and scoring-service) runs the properties. A property is a plain test class named `*Test`, so Surefire runs it with the rest; jqwik reports only failures and keeps its failed-sample database under `target/` (`jqwik.properties`). It was chosen over hand-rolled random loops because it shrinks a failing input to the smallest one and reports the seed, and over QuickTheories/junit-quickcheck because it is a maintained JUnit 5 engine with stateful (action sequence) testing.
- **Properties run on pure code.** jqwik cannot start Quarkus, so the rules were made pure and are tested for all inputs: `RoundRobin`, `RruleEngine` (compared with a brute-force oracle), `PeriodWindows` over every JDK zone and `LedgerRules` (extracted from `LedgerService` and `ScoreboardService`, same behavior). The ledger's accounting identity is checked as a state machine over random sequences of awards, reversals and adjustments. The wiring to PostgreSQL is covered by seeded random sequences through the real service (`LedgerSequenceTest`) and by concurrency tests.
- **Concurrency tests** start several scheduler instances against the real database and count the effects: spawn (`SpawnConcurrencyTest`), month close, outbox relays and the reminder and overdue jobs each have one.
- **Pitest 1.30.1** (Apache-2.0, `pitest-junit5-plugin` 1.2.3) is a Maven profile (`-Ppitest`, `make mutation`), never part of the normal build. Each service names the classes and tests to mutate in `targetClasses` and `targetTests`: only the pure domain code, since Pitest cannot drive `@QuarkusTest`. It is run periodically and its scores are recorded in the ledger (T-0030).

## Consequences

- Two more build plugins and one test library to keep current; none ships in the services.
- The mutation score only covers the pure domain classes listed in the service poms; extending it means extracting more rules into pure classes, as done for the ledger.
- Last run (2026-10-14): tasks `RoundRobin` + `RruleEngine` 95% (42 of 44 killed; the two survivors are guards that the earlier day logic already makes unreachable), scoring `LedgerRules` + `PeriodWindows` 100% (17 of 17).
- The ledger state machine showed that reversing a task after a manual adjustment can take a member's ledger sum below zero while the score shown stays at zero; see T-0087.
