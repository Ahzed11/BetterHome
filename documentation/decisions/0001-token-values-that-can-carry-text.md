# 0001 — Token values that can carry text

## Context

Design tokens (colors, spacing, radii, type) must stay consistent across Flutter screens and avoid hard-coded literals.

## Decision

Semantic design tokens are defined in the project specification (§8) and referenced from the Flutter design system. Screens consume tokens, not raw values.

## Consequences

UI changes that alter look and feel update tokens (and goldens) in one place. Dark mode can be added later by swapping token values.
