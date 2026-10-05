# Producing Aurora bundles (mapping guide)

This guide is for tools outside Aurora that export designs as an
[Aurora bundle](../../spec/bundle-v1.md), such as TokenSeed's exporter. It lists
everything a bundle must supply, what each token means, and what Aurora checks.
Aurora's side ends at the spec, the validators (`AuroraBundle.validate` in
`@aurora/core` and the Dart core), the fixtures and the Flutter installer; the
mapping from a producer's own model is the producer's job.

## Checklist

1. Build a manifest: `bundleVersion: 1`, the theme id (lowercase, installable as
   a directory name) and name, the included `variants` and `preferredAppearance`,
   optionally the texture id and name and the suggested `pairing`, and
   `provenance` (`generator` such as `tokenseed@0.2.0`, a `sourceHash` of the
   source design, and an RFC 3339 `createdAt`).
2. For each included appearance write `<appearance>.tokens.json`: all 58 colour
   roles below, nothing else, as DTCG structured sRGB colours (aliases between
   them are allowed).
3. If the design has non-colour values, write `texture.tokens.json`: all 29
   texture tokens below, nothing else.
4. Run `AuroraBundle.validate(bundle)` from `@aurora/core` in the producer's tests
   on every export. Both cores agree on validity; a bundle that passes in
   TypeScript passes in Dart. Treat any issue as an export bug.
5. Optionally review contrast: `AuroraContrast.check(variant)` reports the pairs
   below. Aurora reports them as diagnostics and never changes colours.

The simplest correct producer builds Aurora objects and calls
`AuroraBundle.encode({ theme, texture, provenance })`, which writes exactly this
format.

## What does not fit

Aurora's contracts do not grow for a producer. When exporting:

- **Wide-gamut and OKLCH colours**: convert to sRGB, clip to the gamut, and write
  components that quantize to the intended 8-bit value (`round(c * 255)`). Aurora
  stores 8-bit sRGB only; `display-p3` and other colour spaces are rejected.
- **Extra modes** such as high contrast: drop them. A bundle has `light` and/or
  `dark` only. Give the closest standard pair to `light` and `dark`.
- **Extra tokens** (palette ramps, component tokens, spacing scales): leave them
  out. Undeclared tokens make the bundle invalid. App-specific tokens belong to the
  receiving app's contract, which supplies their values when it registers the
  theme.
- **Translucent backgrounds**: allowed, but contrast for pairs over a translucent
  background is reported as unknown.

## Colour roles (58, every variant)

These are the 46 Material 3 colour roles plus success, warning and info families.
Path, then meaning; a producer maps its own palette onto these meanings. The
`on*` roles are text and icons drawn on the role they name. `*Fixed` roles keep
the same value in light and dark. `surfaceTint` is usually `primary`.

### Primary, secondary and tertiary accents

| Token | Meaning |
| --- | --- |
| `colors.primary` | Accent for prominent actions. |
| `colors.onPrimary` | Text and icons on primary. |
| `colors.primaryContainer` | Lower-emphasis container for prominent actions. |
| `colors.onPrimaryContainer` | Text and icons on primaryContainer. |
| `colors.primaryFixed` | Container accent that stays constant across appearances. |
| `colors.primaryFixedDim` | Stronger fixed primary accent. |
| `colors.onPrimaryFixed` | Text and icons on fixed primary accents. |
| `colors.onPrimaryFixedVariant` | Lower-emphasis content on fixed primary accents. |
| `colors.secondary` | Accent for less prominent actions. |
| `colors.onSecondary` | Text and icons on secondary. |
| `colors.secondaryContainer` | Lower-emphasis container for less prominent actions. |
| `colors.onSecondaryContainer` | Text and icons on secondaryContainer. |
| `colors.secondaryFixed` | Container accent that stays constant across appearances. |
| `colors.secondaryFixedDim` | Stronger fixed secondary accent. |
| `colors.onSecondaryFixed` | Text and icons on fixed secondary accents. |
| `colors.onSecondaryFixedVariant` | Lower-emphasis content on fixed secondary accents. |
| `colors.tertiary` | Accent for contrasting accents. |
| `colors.onTertiary` | Text and icons on tertiary. |
| `colors.tertiaryContainer` | Lower-emphasis container for contrasting accents. |
| `colors.onTertiaryContainer` | Text and icons on tertiaryContainer. |
| `colors.tertiaryFixed` | Container accent that stays constant across appearances. |
| `colors.tertiaryFixedDim` | Stronger fixed tertiary accent. |
| `colors.onTertiaryFixed` | Text and icons on fixed tertiary accents. |
| `colors.onTertiaryFixedVariant` | Lower-emphasis content on fixed tertiary accents. |

### Error and status (success, warning, info)

| Token | Meaning |
| --- | --- |
| `colors.error` | Error and destructive feedback. |
| `colors.onError` | Text and icons on error. |
| `colors.errorContainer` | Lower-emphasis error container. |
| `colors.onErrorContainer` | Text and icons on errorContainer. |
| `colors.success` | Success feedback. |
| `colors.onSuccess` | Text and icons on success. |
| `colors.successContainer` | Lower-emphasis success container. |
| `colors.onSuccessContainer` | Text and icons on successContainer. |
| `colors.warning` | Warning feedback. |
| `colors.onWarning` | Text and icons on warning. |
| `colors.warningContainer` | Lower-emphasis warning container. |
| `colors.onWarningContainer` | Text and icons on warningContainer. |
| `colors.info` | Info feedback. |
| `colors.onInfo` | Text and icons on info. |
| `colors.infoContainer` | Lower-emphasis info container. |
| `colors.onInfoContainer` | Text and icons on infoContainer. |

### Surfaces, outlines and overlays

| Token | Meaning |
| --- | --- |
| `colors.surface` | Default page and component surface. |
| `colors.onSurface` | Primary text and icons on surfaces. |
| `colors.surfaceDim` | Dimmest surface tone. |
| `colors.surfaceBright` | Brightest surface tone. |
| `colors.surfaceContainerLowest` | Lowest surface container level. |
| `colors.surfaceContainerLow` | Low surface container level. |
| `colors.surfaceContainer` | Default distinct surface container. |
| `colors.surfaceContainerHigh` | High surface container level. |
| `colors.surfaceContainerHighest` | Highest surface container level. |
| `colors.onSurfaceVariant` | Lower-emphasis text and icons on surfaces. |
| `colors.outline` | Boundaries requiring emphasis. |
| `colors.outlineVariant` | Subtle decorative boundaries and dividers. |
| `colors.shadow` | Color of cast shadows. |
| `colors.scrim` | Color of obscuring modal overlays. |
| `colors.inverseSurface` | Surface contrasting with surrounding appearance. |
| `colors.onInverseSurface` | Text and icons on inverseSurface. |
| `colors.inversePrimary` | Primary accent on inverseSurface. |
| `colors.surfaceTint` | Accent used by Material surface tint treatments. |

## Texture tokens (29, when a texture is included)

The Material 3 baseline type scale, corner shapes and motion. The starter column
is Aurora's Material value, in texture recipe syntax, for producers without an
opinion. In the DTCG document dimensions in dp are written as `px` with
`$extensions["dev.aurora"].unit = "dp"`; see the
[texture profile](../data/dtcg-profile.md#aurora-dtcg-texture-profile-v1). Typography
values are composite: `fontFamily`, `fontSize`, `fontWeight`, `letterSpacing` and
`lineHeight` (a multiplier of the font size). Font families must be available to
the receiving app; name fallbacks.

| Token | Type | Meaning | Material starter |
| --- | --- | --- | --- |
| `type.family.brand` | fontFamily | Expressive typeface for display and headline text. | `"Roboto"` |
| `type.family.plain` | fontFamily | Readable typeface for titles, body and labels. | `"Roboto"` |
| `type.displayLarge` | typography | Largest display text, for short hero numbers or words. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 57.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": -0.25, "unit": "dp"}, "lineHeight": 1.1228070175438596}` |
| `type.displayMedium` | typography | Medium display text. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 45.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.1555555555555554}` |
| `type.displaySmall` | typography | Small display text. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 36.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.2222222222222223}` |
| `type.headlineLarge` | typography | Large headlines on prominent screens. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 32.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.25}` |
| `type.headlineMedium` | typography | Medium headlines. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 28.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.2857142857142858}` |
| `type.headlineSmall` | typography | Small headlines. | `{"fontFamily": "{type.family.brand}", "fontSize": {"value": 24.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.3333333333333333}` |
| `type.titleLarge` | typography | Large titles, such as app bar titles. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 22.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.0, "unit": "dp"}, "lineHeight": 1.2727272727272727}` |
| `type.titleMedium` | typography | Medium titles, such as list headers. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 16.0, "unit": "dp"}, "fontWeight": 500, "letterSpacing": {"value": 0.15, "unit": "dp"}, "lineHeight": 1.5}` |
| `type.titleSmall` | typography | Small titles. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 14.0, "unit": "dp"}, "fontWeight": 500, "letterSpacing": {"value": 0.1, "unit": "dp"}, "lineHeight": 1.4285714285714286}` |
| `type.bodyLarge` | typography | Large body text. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 16.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.5, "unit": "dp"}, "lineHeight": 1.5}` |
| `type.bodyMedium` | typography | Default body text. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 14.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.25, "unit": "dp"}, "lineHeight": 1.4285714285714286}` |
| `type.bodySmall` | typography | Small body text, such as captions. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 12.0, "unit": "dp"}, "fontWeight": 400, "letterSpacing": {"value": 0.4, "unit": "dp"}, "lineHeight": 1.3333333333333333}` |
| `type.labelLarge` | typography | Large labels, such as button text. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 14.0, "unit": "dp"}, "fontWeight": 500, "letterSpacing": {"value": 0.1, "unit": "dp"}, "lineHeight": 1.4285714285714286}` |
| `type.labelMedium` | typography | Medium labels. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 12.0, "unit": "dp"}, "fontWeight": 500, "letterSpacing": {"value": 0.5, "unit": "dp"}, "lineHeight": 1.3333333333333333}` |
| `type.labelSmall` | typography | Small labels, such as badges. | `{"fontFamily": "{type.family.plain}", "fontSize": {"value": 11.0, "unit": "dp"}, "fontWeight": 500, "letterSpacing": {"value": 0.5, "unit": "dp"}, "lineHeight": 1.4545454545454546}` |
| `shape.extraSmall` | dimension | Corner radius for small elements such as text fields and menus. | `{"value": 4.0, "unit": "dp"}` |
| `shape.small` | dimension | Corner radius for chips and small cards. | `{"value": 8.0, "unit": "dp"}` |
| `shape.medium` | dimension | Corner radius for cards. | `{"value": 12.0, "unit": "dp"}` |
| `shape.large` | dimension | Corner radius for large surfaces such as navigation drawers. | `{"value": 16.0, "unit": "dp"}` |
| `shape.extraLarge` | dimension | Corner radius for dialogs and sheets. | `{"value": 28.0, "unit": "dp"}` |
| `motion.short` | duration | Duration of small, quick transitions such as selection changes. | `{"value": 100.0, "unit": "ms"}` |
| `motion.medium` | duration | Duration of standard transitions. | `{"value": 300.0, "unit": "ms"}` |
| `motion.long` | duration | Duration of large transitions such as full-screen changes. | `{"value": 500.0, "unit": "ms"}` |
| `motion.extraLong` | duration | Duration of slow, emphasized transitions. | `{"value": 800.0, "unit": "ms"}` |
| `motion.easing.standard` | cubicBezier | Easing for transitions that begin and end on screen. | `[0.2, 0.0, 0.0, 1.0]` |
| `motion.easing.emphasizedDecelerate` | cubicBezier | Easing for elements entering the screen. | `[0.05, 0.7, 0.1, 1.0]` |
| `motion.easing.emphasizedAccelerate` | cubicBezier | Easing for elements leaving the screen. | `[0.3, 0.0, 0.8, 0.15]` |

## Diagnosed contrast pairs

Generation and `AuroraContrast.check` evaluate these foundation pairs for every
variant (WCAG ratio, foreground alpha composited over an opaque background).
Producers should meet them; Aurora reports failures and never repairs colours.

| Foreground | Background | Minimum ratio |
| --- | --- | --- |
| `colors.onPrimary` | `colors.primary` | 4.5 |
| `colors.onPrimaryContainer` | `colors.primaryContainer` | 4.5 |
| `colors.onSecondary` | `colors.secondary` | 4.5 |
| `colors.onSecondaryContainer` | `colors.secondaryContainer` | 4.5 |
| `colors.onTertiary` | `colors.tertiary` | 4.5 |
| `colors.onTertiaryContainer` | `colors.tertiaryContainer` | 4.5 |
| `colors.onError` | `colors.error` | 4.5 |
| `colors.onErrorContainer` | `colors.errorContainer` | 4.5 |
| `colors.onSuccess` | `colors.success` | 4.5 |
| `colors.onSuccessContainer` | `colors.successContainer` | 4.5 |
| `colors.onWarning` | `colors.warning` | 4.5 |
| `colors.onWarningContainer` | `colors.warningContainer` | 4.5 |
| `colors.onInfo` | `colors.info` | 4.5 |
| `colors.onInfoContainer` | `colors.infoContainer` | 4.5 |
| `colors.onPrimaryFixed` | `colors.primaryFixed` | 4.5 |
| `colors.onPrimaryFixedVariant` | `colors.primaryFixed` | 4.5 |
| `colors.onPrimaryFixed` | `colors.primaryFixedDim` | 4.5 |
| `colors.onPrimaryFixedVariant` | `colors.primaryFixedDim` | 4.5 |
| `colors.onSecondaryFixed` | `colors.secondaryFixed` | 4.5 |
| `colors.onSecondaryFixedVariant` | `colors.secondaryFixed` | 4.5 |
| `colors.onSecondaryFixed` | `colors.secondaryFixedDim` | 4.5 |
| `colors.onSecondaryFixedVariant` | `colors.secondaryFixedDim` | 4.5 |
| `colors.onTertiaryFixed` | `colors.tertiaryFixed` | 4.5 |
| `colors.onTertiaryFixedVariant` | `colors.tertiaryFixed` | 4.5 |
| `colors.onTertiaryFixed` | `colors.tertiaryFixedDim` | 4.5 |
| `colors.onTertiaryFixedVariant` | `colors.tertiaryFixedDim` | 4.5 |
| `colors.onSurface` | `colors.surface` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surface` | 4.5 |
| `colors.onSurface` | `colors.surfaceDim` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceDim` | 4.5 |
| `colors.onSurface` | `colors.surfaceBright` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceBright` | 4.5 |
| `colors.onSurface` | `colors.surfaceContainerLowest` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceContainerLowest` | 4.5 |
| `colors.onSurface` | `colors.surfaceContainerLow` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceContainerLow` | 4.5 |
| `colors.onSurface` | `colors.surfaceContainer` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceContainer` | 4.5 |
| `colors.onSurface` | `colors.surfaceContainerHigh` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceContainerHigh` | 4.5 |
| `colors.onSurface` | `colors.surfaceContainerHighest` | 4.5 |
| `colors.onSurfaceVariant` | `colors.surfaceContainerHighest` | 4.5 |
| `colors.onInverseSurface` | `colors.inverseSurface` | 4.5 |
| `colors.inversePrimary` | `colors.inverseSurface` | 4.5 |
| `colors.outline` | `colors.surface` | 3 |
