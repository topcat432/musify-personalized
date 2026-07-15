# Musify Personalized visual system

## Status and scope

This document records the visual language already established by the
personalized import, review, destination, backup, and updater work. It is a
maintenance guide, not approval to redesign unrelated product surfaces.

The implementation remains the source of truth, especially:

- `lib/widgets/personalized_ui.dart`
- `lib/theme/app_themes.dart`
- `lib/theme/app_colors.dart`
- `lib/widgets/review_swipe_deck.dart`
- `lib/widgets/personalized_update_dialog.dart`
- the personalized import and review screens under `lib/screens/`
- `tool/visual_review_test.dart`; its golden run generates output under
  `tool/visual_review_goldens/`

## Direction

The intended experience is warm, dark, premium, cinematic, and driven by music
and album art. Peach/copper warmth is the established accent direction, but the
shared personalized components currently inherit the active Material
`ColorScheme` so they remain coherent with dynamic color, light, dark, and
pure-black modes. Do not replace semantic theme colors with a fixed palette
without an explicit design decision and coverage for every supported theme.

Avoid Aqua, space, Orbit, SaaS-dashboard, or developer-tool styling. A new
screen should feel like part of the listening experience: expressive but calm,
layered rather than flat, and clear enough for repetitive review work.

## Color and elevation

Use semantic `ColorScheme` roles rather than new hard-coded colors:

- `primary` and `primaryContainer` for emphasis, selected state, positive
  progress, and icon accents;
- `surface`, `surfaceContainerLow`, and `surfaceContainerHigh` for layered
  content surfaces;
- `onSurface` for primary copy and `onSurfaceVariant` for supporting copy;
- `outlineVariant` at restrained opacity for separation;
- `tertiaryContainer` for warning or pending states;
- `error` and `errorContainer` only for failures and genuinely destructive
  actions.

The shared hero blends `primaryContainer` into `surfaceContainerHigh` and uses a
subtle outline. Shared surfaces default to `surfaceContainerLow`. Preserve
contrast in light, dark, pure-black, and system-derived schemes. Album artwork
may create atmosphere, but text and controls must remain legible when artwork is
missing, unusually bright, or unusually dark.

Status color is semantic, not decorative. Neutral, success, warning, and error
messages use `PersonalizedStatusBanner`; do not communicate state through color
alone.

## Typography

Use the active `ThemeData.textTheme`. The existing app theme uses `paytoneOne`
for app-bar titles; personalized surfaces use theme typography with deliberate
weight and spacing rather than introducing another font.

- Heroes use `headlineSmall` or `titleLarge` in compact mode, weight 800, tight
  line height, and slightly negative tracking.
- Section headings use `titleLarge`, weight 700.
- Supporting descriptions use `bodyLarge` or `bodyMedium`, increased line
  height, and `onSurfaceVariant`.
- Eyebrows use uppercase `labelMedium`, weight 800, positive tracking, and the
  primary color.
- Metrics use a prominent `titleLarge` value and a quieter `labelMedium` label.

Large headings need compact alternatives. Test long track, artist, album,
playlist, and translated strings; do not rely on a single English screenshot.

## Shape, spacing, and composition

Rounded, layered cards are the primary composition language. Existing shared
defaults provide the baseline:

- hero radius: 28, or 24 in compact mode;
- shared surface radius: 24;
- status radius: 18;
- hero internal padding: 22, or 18 in compact mode;
- shared surface internal padding: 18;
- empty-state internal padding: 24.

These values describe current components, not a requirement to repeat one
radius everywhere. Reuse the shared components before introducing another card
primitive. Keep a visible hierarchy between page background, grouped surface,
selection state, and primary action.

Use generous page margins and consistent vertical rhythm. Dense, repetitive
review controls may be more compact, but touch targets and readable labels take
priority. Floating and fixed actions must not cover the mini-player, final
content card, bottom navigation, keyboard, or system insets. Bottom actions use
`SafeArea`; modal content accounts for view insets.

## Shared personalized components

- `PersonalizedHero`: page identity, short explanation, optional stage eyebrow,
  icon, and footer.
- `PersonalizedSurface`: grouped content and animated state changes.
- `PersonalizedSectionHeading`: section title, supporting copy, and optional
  trailing action.
- `PersonalizedStatusBanner`: neutral, success, warning, and error feedback.
- `PersonalizedMetric`: compact semantic counts with animated value changes.
- `PersonalizedReveal`: staggered entrance that respects disabled animations.
- `personalizedPageRoute`: consistent fade/slide navigation with a no-motion
  path.
- `showPersonalizedDestructiveConfirmation`: explicit destructive confirmation.
- `PersonalizedEmptyState`: a complete, actionable empty state.

Prefer these shared primitives so fixes to theme behavior, motion, spacing, and
accessibility propagate through the personalized workflow.

## Motion and interaction

Motion should explain continuity: a card follows the swipe, the next card is
revealed, values change in place, and routes enter and leave coherently. It must
not make high-volume review slower.

Current shared timing establishes the vocabulary:

- surface changes: 220 ms, `easeOutCubic`;
- metric changes: 240 ms with fade and scale;
- page entry/exit: 320/240 ms with fade and slight slide;
- shared reveal: 360 ms plus its stagger delay;
- review-deck actions: approximately 220-260 ms for commit or recovery.

Use `MediaQuery.disableAnimations` for reduced-motion behavior. Shared reveal
and route helpers already collapse to no motion. New motion must handle
interruption, rapid taps, back navigation, cancellation, and state changes while
an animation is active. Haptics should confirm meaningful decisions, not every
minor tap.

## States, language, and accessibility

Every personalized flow needs intentional loading, empty, error, disabled,
success, cancellation, and retry states. Messages must distinguish what was
saved, what was not changed, and what remains recoverable. Never make a toast or
picker return look like verified backup, restore, import, routing, or update
success.

Provide semantic labels for metrics and icon-only actions, useful tooltips,
adequate touch targets, readable contrast, and non-color state cues. Destructive
actions require clear scope and confirmation. Permanent exclusion copy must not
sound like temporary “no match” handling.

## Visual acceptance checklist

Before a UI change is ready for merge, verify:

- standard and compact phone sizes;
- dark, pure-black, and any supported light/system-color behavior;
- long text, missing artwork/metadata, and large counts;
- loading, empty, error, disabled, success, and cancellation states;
- keyboard, safe-area, mini-player, and navigation overlap;
- entrance, exit, interruption, back navigation, and rapid taps;
- reduced-motion behavior;
- relevant widget tests and golden screenshots.

Record what was inspected and what remains unverified on a real device. Golden
or widget success is not phone verification.
