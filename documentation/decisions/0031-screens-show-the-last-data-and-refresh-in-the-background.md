# 0031 — Screens show the last data they had and refresh it in the background, kept in memory only

## Context

Every tab switch rebuilt the tab, fetched its data again and drew the text "Loading…" until the answer arrived, and a screen that reloaded after an action swapped data it already had for "Loading…". Opening a screen the user had just left looked like a first visit. The repositories cache nothing.

## Decision

The app keeps the **last answer to each read in memory** (`ReadCache`, owned by `AppSession`, a concrete class: no new interface). A screen asks for its data through `CachedRead`: it gets the cached answer at once, when there is one, and a refresh starts in the background on every visit. The old answer stays on screen while the refresh runs, and when the refresh fails (only a failed request is handled, by name; the next visit retries). Only a read that never had an answer shows a loading state, or an error when its first request fails. Two readers who ask for the same thing at the same time share one request.

Screens that need the same thing (the members, the household) use the same key, so one request serves them, and requests that do not depend on each other are started together. An entry is shared with screens that are still mounted under a pushed one, so a change made while a frame is being built is announced when the frame ends, never in the middle of it.

Once the first tab has its answer, the other tabs of the selected household are filled in the background (`prefetchOtherTabs`), one tab after the other, only where an entry has no answer yet; the reads are described once (`ReadSpec`, `reads.dart`), so the entry a prefetch fills is the one a screen opens. The product owner chose this on 2026-10-29 and accepted the extra requests at startup.

A key says what was asked: the kind of read, the signed-in user, the household and the parameters (`AppSession.readKey`). The cache is emptied when the signed-in user changes, at sign-out, at account deletion, and when a repository is replaced; a request that is still running then writes into an entry nobody can reach.

Nothing is written to disk. Considered and not chosen, by the product owner on 2026-10-29: keeping the tabs alive and reloading only on request (a housemate's change stays invisible until then), a fixed time-to-live of 30 seconds (changes up to 30 seconds late, and a stale screen is still a first visit after the delay), and saving the last data on the phone (works offline, but household data would have to be cleared at sign-out and deletion and survives a lost phone; the web build's tokens are already kept in memory only, T-0072).

## Consequences

A first visit to a tab that was prefetched has its data in its first frame too. A screen opened again has its data in its first frame and a housemate's change appears a moment after opening it. Each visit still costs one request per read, as before, but nothing waits on it. There is no polling: a screen that stays open does not refresh by itself, and pull to refresh (T-0129) is the way to ask. The first launch of the app, and every first visit to a screen, draws skeletons: placeholders with the shape of the screen's content (T-0124). The cache is not a source of truth for rules: actions still go through the repositories and the services decide. Every screen that shows household data reads through it (T-0125, T-0126). A refresh asked for after the user's own change queues one more request behind any that is already running, because that one may have read the data before the change. A decision that must not rest on an old answer, such as showing a month's recap, waits for a fresh one.
