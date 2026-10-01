# Aurora generator v1

Shared pure Dart logic for future agent APIs, CLIs, and human preview tools.
Generation has no widget-tree, file, network, or device dependency. Call it
explicitly; theme switching never generates a missing variant automatically.

```dart
final result = AuroraGenerator.generate(AuroraGenerationRequest(
  contract: theaterContract,
  id: 'wicked',
  name: 'Wicked',
  primary: AuroraColor.hex('#246b35'),
  secondary: AuroraColor.hex('#625b71'), // Optional.
  tertiary: AuroraColor.hex('#805600'),  // Optional.
  rules: {
    TheaterTokens.ticketBackground:
      const AuroraAliasRule(AuroraFoundation.primaryContainer),
    TheaterTokens.onTicket:
      const AuroraAliasRule(AuroraFoundation.onPrimaryContainer),
  },
  contrastPairs: [
    AuroraContrastPair(
      foreground: TheaterTokens.onTicket,
      background: TheaterTokens.ticketBackground,
    ),
  ],
));

final theme = result.theme; // Register with AuroraRuntime / AuroraController.
final diagnostics = result.issues;
final manifest = result.toJson(); // JSON-compatible; export is a caller decision.
```

## Inputs

`contract`, `id`, `name`, and an opaque `primary` seed are required. Secondary
and tertiary seeds are optional. Optional success, warning, and info seeds default
to `#146c2e`, `#805600`, and `#0061a4`. Status palettes stay independent of the
brand palette. All seeds must be opaque; transparency is valid for explicit
token values but does not have an unambiguous palette-generation meaning.

By default generate light and dark, preferring light. To generate only dark,
provide `appearances: [AuroraAppearance.dark]` and
`preferredAppearance: AuroraAppearance.dark`. Appearances must be unique and
include the preferred appearance. Output order is light then dark.

## App extensions and overrides

Every requested variant must satisfy every field in the app contract. There are
three ways to supply app tokens:

- `values`: explicit values shared by requested variants; these can also override
  foundation colors.
- `variantValues`: explicit values for a particular requested appearance.
- `rules`: declarative alias or palette-tone generation for app extensions.

Precedence is generated foundation, then shared values, then variant values.
Rules fill only unresolved app tokens. Aliases resolve final values, including
overrides and other app rules. Cycles fail unless an explicit value breaks the
dependency cycle. Unknown tokens and rules replacing foundation fields are
rejected. Missing required app tokens fail generation; no partial theme is returned.

```dart
ticketBackground: AuroraToneRule(
  palette: AuroraPalette.primary,
  lightTone: 92.5,
  darkTone: 20,
)
```

Available palettes: primary, secondary, tertiary, neutral, neutralVariant, error,
success, warning, info. Tones are finite HCT values in `[0, 100]`; fractional
tones are supported. Alias/tone rules are data, not arbitrary callbacks, so their
semantics can be reproduced by other language ports and future JSON interfaces.

## Algorithm and reproducibility

Algorithm id: `aurora-tonal-v1-mcu-0.11.1`. The pure Dart Material Color Utilities
dependency is pinned to 0.11.1 to avoid silently changing output.

1. Build a tonal-spot scheme from the primary seed at contrast level zero.
   An explicit `scheme` selects fidelity, vibrant, expressive, content,
   monochrome, neutral, rainbow, or fruitSalad instead. The default stays fixed.
2. Keep its primary, neutral, neutral-variant, and default secondary/tertiary palettes.
3. If secondary/tertiary seeds are supplied, replace those palettes with HCT
   palettes using the supplied seed's actual hue and chroma.
4. Resolve all 46 Material foundation roles through that dynamic scheme. Aurora's
   `onInverseSurface` maps to MCU's `inverseOnSurface`.
   `surfaceTint` maps to resolved primary, matching Flutter `fromSeed` (MCU's
   standalone surfaceTint differs for fidelity/content).
5. Build independent tonal-spot schemes for the three status seeds. Use each
   scheme's primary/onPrimary/primaryContainer/onPrimaryContainer quartet for
   the corresponding status quartet.
6. Apply explicit values, resolve extension rules, validate the full contract,
   and calculate diagnostics on the final values.

Seeds guide hue/chroma; they are not a guarantee of an exact output hex. Use a
token override to preserve a specific color. A palette tone rule still uses the
generated palette even if a single token in that palette was overridden.

Algorithm changes need a new identifier and reviewed portable fixtures. Future
TypeScript ports must match the pinned behavior, not merely depend on the latest
Material library release. See `spec/generation-v1.md`.

Additional identifiers are `aurora-<schemeName>-v1-mcu-0.11.1`, with exact enum
names. Status quartets always use independent tonal-spot schemes. Extra
secondary/tertiary seeds replace palettes after scheme selection as before.
New outputs are pinned separately in `spec/fixtures/generation-schemes-v1.json`;
the original fixture remains untouched. The deliberate maintenance command is
`dart run tool/export_scheme_fixture.dart`, never part of normal tests.

`AuroraGenerator.variants(seed, scheme: ...)` returns foundation-only immutable
snapshots for per-entity branding; there is no registry or app-extension inference.
Cache these outside widget builds. Use the full request for canonical app contracts.
Single-seed generation without overrides matches Flutter's `ColorScheme.fromSeed`
for all 46 supported Material roles at contrast zero on the verified SDK. Adapter
tests cover three seeds, all schemes, and both appearances; upstream changes may
break equivalence while Aurora's pinned generation remains stable.

## Contrast diagnostics

`result.checks` contains immutable checks for known foundation foreground/background
pairs plus declared app pairs. `result.issues` includes failed and unknown checks.
Each check exposes appearance, token paths, minimum ratio, measured ratio, and
`pass`, `fail`, or `unknown` status. Defaults are 4.5 for content pairs and 3 for
outline against surface. Custom pairs can specify a threshold in `[1, 21]`.

The calculation uses sRGB relative luminance. Translucent foregrounds are
composited over opaque backgrounds before measuring. A translucent background
without a known backing color produces `unknown`, not a fabricated measurement.
Explicit overrides are never repaired silently. A structurally valid theme can
therefore be returned with contrast issues. These are diagnostics for declared
usage pairs, not certification of all text sizes, widget states, or layouts.

The contrast utility also works independently:
`AuroraContrast.check(variant, additionalPairs: ...)` and
`AuroraContrast.ratio(foreground, background)`.
`AuroraContrast.bestOn(background, candidates)` returns the highest-contrast
candidate, choosing the first on ties. It rejects empty candidates or translucent
backgrounds; candidate alpha is composited normally. It makes no minimum-contrast
promise. `result.debugReport()` formats failed/unknown checks without logging.

Reference: [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

## Output boundary

`result.theme` is an ordinary validated AuroraTheme usable at any integration
level. `toJson()` produces an Aurora manifest with algorithm and contract metadata,
one DTCG document per variant, and diagnostics. The manifest itself is not DTCG;
its individual `variants.light` / `variants.dark` values are DTCG documents.
The manifest has no decoder yet and does not include a replayable input recipe.

The packaged CLI and browser preview consume this core; see [CLI usage](../user/usage.md).
The agent CLI accepts app recipes through the portable `AuroraRecipe.decode`
API; see `spec/recipe-v1.md`. Persistence and image extraction remain separate
capabilities to build on this core.
