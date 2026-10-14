# 0021 — The UI follows the Claude Design canvas and is built from shared widgets

## Context

The product owner designed the app in a Claude Design canvas ("Household app redesign": https://claude.ai/artifact/HnXaFEUDwB7EvEHvMVr84T, boards Chores, My chores, Quick log, Leaderboard, Lists, Household, New recurring chore, Log in, Register, Household setup). Screens written before it (households, chores, leaderboard) use stock Material widgets. New screens must follow the design and not repeat styling in each screen (AGENTS §9: no colors, radii or font sizes in screens).

## Decision

- The canvas is the visual reference for every new or changed screen. Its colors, radii, spacing and type sizes become tokens in `app/lib/theme/tokens.dart` (`AppTokens`, `AppTypography`); screens use tokens only.
- Screens are assembled from small reusable widgets in `app/lib/ui/widgets/` (`AppPill`, `AppAddPill`, `AppCard`, `ScreenHeader`, `SectionLabel`, `CheckRow`, `AddField`, `ToggleRow`, `NotificationRow`). Each widget owns its semantics (labels, button and selected state, tap actions, `container: true` so it is not merged into its parent) and keeps a 48 px tap target around the design's drawn size. `app/test/widgets_test.dart` covers states, targets, semantics, FR/EN goldens and 200% text scale; the baseline test covers every screen.
- First screen built this way: Lists (T-0024). Next: the notification inbox and settings (T-0028). The canvas has no board for them, only the bell with a coral dot on the Chores board, so they extend the same tokens and widgets; the bell sits on the home screen until the shell of T-0031 exists. A failed request on these screens is always shown (`runGuarded`), never dropped.

## Deviations from the canvas, on purpose

- **Fonts:** the design uses Bricolage Grotesque (titles) and Figtree (text) from Google Fonts. They are not bundled yet; `AppTypography` is the one place to add them (T-0079).
- **Navigation:** built in T-0031, see the addendum.
- **Check box outline:** `#7F8F8A` instead of the design's `#B9C4BF`, which is below the 3:1 contrast of a control boundary.
- **Tab name:** the design says "Lists" where the spec said "Groceries"; the spec is updated to "Lists".
- **Delete item:** the design has no delete control but the spec requires deleting items, so each row has a delete icon.
- **Who checked an item:** the design shows a name beside checked items; the API returns a user id and the app has no member names yet (T-0058).

## Consequences

Restyling the existing screens onto these widgets is separate work (T-0080). Changes to the canvas are followed by token and widget changes in the same commit as the screen that needs them.

## Addendum: navigation shell (T-0031)

- `HomeShell` is the signed-in app: the household switcher in the top bar (a pill with the current household that opens a sheet to switch, create a household or open its details), the notifications bell and sign-out next to it, and a Material 3 `NavigationBar` with the four tabs All chores, My chores, Leaderboard and Lists. The tab screens carry their own `ScreenHeader` instead of an app bar, like the Lists screen did. The household list and the old per-household menu screen are gone; the details (members, invitations, away, leave) are one action in the switcher sheet.
- The selected household lives in `AppSession` and is remembered per user with `shared_preferences` (already in the dependency tree through `oidc_default_store`; now a direct dependency, test doubles use its in-memory mock). A remembered household that no longer exists falls back to the first one.
- The design canvas has no switcher board, so the sheet extends its look (rounded sheet, brand tint for the selected household). Accepting an invitation stays in the household details, as before.

