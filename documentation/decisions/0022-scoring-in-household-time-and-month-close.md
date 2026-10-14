# 0022 — Scoring windows in household time and the scheduled month close

## Context

Spec §3.4 cuts the scoreboard into week, month and year views and closes each month "at the household's local month boundary". The first scoring code cut everything at UTC midnight, and the month was closed only when an admin called an endpoint. A household in Brussels saw a chore done at 00:30 on 1 April counted for March, and nobody got a month-end recap unless an admin asked.

## Decision

- **One calculator.** `PeriodWindows` (pure, no database) gives the window `[from, to)` of a period in a timezone: a week starts on Monday at local midnight, a month and a year at the local midnight of their first day. An instant exactly on a boundary belongs to the window that starts there. Local midnights come from `ZonedDateTime`, so daylight saving makes a window an hour longer or shorter, never a gap or an overlap (also where midnight does not exist on the change day). The scoreboard, the admin close and the scheduled close all use it, so they cannot disagree. Week, month and year windows now carry their end as well as their start.
- **The zone comes from households-service** (`GET /v1/internal/households/{id}/settings`, service role, as for members). Unknown household or an invalid zone name means UTC; an outage means 503, as for the other calls.
- **A scheduled close.** `month_close_cursor` holds, per household with ledger rows, the next month to close and the instant that month ends locally. Every five minutes each replica claims the oldest due household with `FOR UPDATE SKIP LOCKED`, in its own transaction, re-reads the household's zone and records the recap of every month that has really ended, then moves the cursor. Months missed while the service was down are caught up. A household is registered the first time the job sees its ledger rows, at the month of its first row.
- **What a recap is.** The winner has the most points; a member never counts below zero (as on the scoreboard); a tie goes to the lowest user id, the same order as the scoreboard's ranks. A month in which nobody scored gets no recap. An existing recap (an admin closed the month by hand) is never overwritten by the job; the admin endpoint still refreshes one.
- **Seen by me.** The winners list tells each caller whether they have already seen the confetti of a month (`celebrated`), so the app shows it once per user.

## Consequences

- A household that changes its timezone: the cursor's stored end time is re-checked when it passes, so a later boundary is respected; an earlier boundary only takes effect at the stored time (up to a month late in the worst case). Accepted: timezone changes are rare, and a recap is never closed too early.
- If households-service is down the household is tried again a minute later; nothing is half done, since each household is one transaction.
- The job scans the ledger for households without a cursor on every run; fine at this size, an index or a registration event can replace it.
- Notifying the winner of a closed month is not part of this change (spec §5 has no such type).

## Addendum: the recap in the app

On the leaderboard the app shows the recap of the newest month the user has not seen, with confetti, once per user: it asks the server to record it as seen first and shows it only if that worked, so it cannot come back. Product decision (2026-10-14): every member sees it, not only the winner; the winner is named ("You won ..."), a month nobody scored in says so. Months missed are shown one per visit, newest first. Confetti (`ConfettiBurst`) is decoration: ignored by touch and screen readers, and not played when the user asked for reduced motion. The dialog's text scrolls so large text sizes keep the button on screen.

