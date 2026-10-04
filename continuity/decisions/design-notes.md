# Aurora design notes

Working record from the design discussion, September 30, 2026. Confirmed
decisions are separated from proposals; this is not yet an implementation spec.

## Confirmed direction

- Flutter is the first integration. Keep the core independent of Flutter so a
  future TypeScript / React Native port can share concepts and theme data.
- Aurora supplies an immutable foundational contract with useful defaults in
  starter themes. Apps may add fields but cannot remove or redefine foundation
  fields. Theme values are immutable once constructed.
- Each app has one main theme contract: foundation plus app extensions.
- Every theme variant must supply a value of the required type for every field
  in that complete contract. Extensions are required, not optional plugins.
  Themes implement the contract; the contract does not supply theme values.
- Missing or invalid values prevent activation. Prefer static enforcement for
  typed definitions and runtime validation for imported or generated data.
- Theme identity and appearance are separate. A theme may provide light and
  dark variants, but both are not mandatory. Handling an unavailable variant
  must be explicit; do not silently generate it.
- The foundation includes success, warning, and information color roles.
- Prioritize simple APIs, readable documentation, typed access, useful errors,
  and explicit contracts for both humans and coding agents.
- The three integration levels are AuroraTokens (direct values), AuroraScope
  (themed subtree), and AuroraEngine (app integration). AuroraRuntime is the pure
  selection runtime; there is no global active theme.

## Theme generator: shared logic implemented

The pure Dart core now accepts seed colors and returns complete validated themes,
known-pair contrast diagnostics, and JSON-compatible manifests. See [generator guide](../developer/generator.md).
The packaged CLI now opens a plain HTML/CSS/JavaScript browser tool using this
same code through a local Dart server. It includes color pickers and project
installation. The agent CLI accepts portable JSON recipes without a browser.
See [CLI usage](../user/usage.md) and `spec/recipe-v1.md`.

Implemented principles and remaining interface direction:

- Use deterministic color generation by default; AI is not required.
- Produce explicit variants, permit deliberate overrides, and report contrast
  issues for documented foreground/background pairs.
- Validate generated output with the same validator used for authored themes.
- Generate foundation values from known roles. Arbitrary app extensions need
  supplied values or explicit generation rules; their meaning cannot be
  inferred reliably from their names. Fail rather than fabricate missing data.
- Core generation is callable from Dart, with primary plus optional secondary,
  tertiary, and status seeds, explicit values, alias/tone rules, and light/dark
  selection. The CLI preview currently supports foundation-only themes;
  full app contracts are supported through portable agent recipes.

## Accepted vocabulary

App distribution decision (2026-10-01): unpublished Aurora packages are exported
as committed app-owned snapshots by `tools/vendor.py`. External checkout paths
are for contributor development. App builds resolve both packages inside the
app; explicit updates record provenance and refuse local vendor edits. Hosted
publication remains unimplemented. See [installation](../user/installation.md).

Integration feedback decisions (2026-10-01): fixed scopes expose immutable variants
without controllers; per-entity generation returns foundation-only snapshots,
while canonical app generation still requires every extension. Scheme choices
are additive versioned strategies pinned to MCU 0.11.1, with unchanged default
fixtures and independent status palettes. Flutter notifications are synchronous
after accepted mutations; the portable runtime stream stays async. Brightness
conversions belong only in the adapter. Settings helpers restore selection without
persistence IO. Typed token declarations remain the extension-access mechanism;
contract codegen is deferred. Status ThemeExtensions derive existing tokens and
add no required foundation roles.

| Term | Meaning |
| --- | --- |
| Theme contract | Complete set of required token definitions for an app. |
| Foundation | Aurora-owned, immutable portion of that contract. |
| Contract extension | App-defined additions to the main contract. |
| Token | Named, typed field, such as primary or ticketBackground. |
| Role | Meaning and intended use of a token. |
| Value | Concrete data assigned to a token in a theme variant. |
| Theme | Named identity, such as Wicked, with one or more variants. |
| Theme variant | Complete token values for a concrete appearance, such as Wicked dark. |
| Appearance | Concrete light/dark mode. System is a selection preference that resolves to one. |
| Theme selection | Chosen theme identity and appearance preference. |
| Seed color | Input used by the theme generator. |

Use token rather than provision to align with existing design-system language.
This vocabulary was accepted before implementation.

## Foundation v1

Adopt current Material 3 color roles and their established meanings, using
platform-independent value types. Add success, warning, and information roles
explicitly. Proposed status families follow the error family:

- success, onSuccess, successContainer, onSuccessContainer
- warning, onWarning, warningContainer, onWarningContainer
- info, onInfo, infoContainer, onInfoContainer

The first implementation defines 46 nondeprecated Material color roles plus
these 12 status roles, for 58 required foundational tokens. The checked-in table
in `tools/generate_foundation.py` is the source for accessors, presets, and the
Flutter bridge. Foundation version is 1. Adding required fields affects existing
theme compatibility and needs an explicit versioning decision.

## Portable format research and recommendation

Recommend DTCG Format 2025.10 for portable token values. It provides typed JSON,
groups, descriptions, aliases, and structured colors. It is a stable Community
Group specification, not a W3C standard. It does not prescribe Aurora's token
roles or enforce an app's complete contract.

The published Resolver 2025.10 module covers contexts such as light/dark.
Evaluate it before defining a custom mechanism for portable variant resolution;
do not depend on preview drafts. A simple file per complete variant is an
alternative for v1. Identity, selection policy, and app-contract validation
remain Aurora responsibilities.

Style Dictionary documents DTCG support; Tokens Studio also supports DTCG,
while documenting compatibility differences. Do not promise universal tool
interoperability. Specify and test Aurora's supported feature subset, including
color spaces and reference handling. Dart authors should still get typed APIs;
JSON should not be mandatory for ordinary app development.

Compared alternatives: custom JSON is simpler initially but requires Aurora-owned
interop work; legacy tool-specific JSON ties interchange to particular tooling;
Dart-only definitions do not meet the cross-language theme-data goal.

Sources:

- https://api.flutter.dev/flutter/material/ColorScheme-class.html
- https://fluent2.microsoft.design/color-tokens/
- https://carbondesignsystem.com/elements/color/overview/
- https://www.designtokens.org/tr/2025.10/format/
- https://www.designtokens.org/tr/2025.10/resolver/
- https://styledictionary.com/info/tokens/
- https://docs.tokens.studio/manage-settings/token-format

## First implementation

- `packages/aurora`: pure Dart colors, contracts, immutable validated variants,
  named themes, explicit fallback, and an asynchronous selection-change stream.
- `packages/aurora_flutter`: controller, native themed scope, app-wide engine with
  managed/injected ownership, observed device appearance, and Material mapping.
- `examples/theater`: required ticket tokens with Wicked and Hadestown variants.
- Color tokens are typed; completeness is enforced at construction/import time.
  Generated required app-contract constructors remain a potential later addition.
- DTCG v1 is one complete variant per document, supporting nested groups,
  structured sRGB colors, and whole-token aliases. See [DTCG profile](../data/dtcg-profile.md).
- Starter palettes are explicit values; they do not automatically supply app
  extensions or invent unavailable variants. Generation is an explicit operation.
- `spec/` contains a generated language-neutral foundation and shared JSON
  conformance fixtures consumed by core tests.

## Next design questions

- Define portable theme/contract version metadata and compatibility migrations.
- Build agent and human interfaces on the shared generator, including portable
  input recipe parsing and export UX.
- Evaluate app-contract code generation for static completeness guarantees.
- Evaluate published Resolver packaging before supporting additional contexts.

## Textures: non-colour tokens (decided 2026-10-04)

Source: Trace's handoff "non-colour tokens in Aurora" plus the owner's answers to
its two open decisions. The owner's answers change the handoff's shape, so the
mapping below is the authority where they differ. The owner named the layer
**AuroraTextures** (after Minecraft texture packs). See the README "Textures"
section.

### Owner decisions

- **Separate selectable layer.** Non-colour design values (type, shape, motion,
  lines, density, chrome and component defaults) are a *texture*, chosen by the
  user independently of the colour theme. Selection becomes theme + appearance +
  texture. Textures are opt-in: an app that registers no textures behaves exactly as
  before.
- **Texture foundation plus extensions.** Like themes, a texture contract is an
  Aurora-owned foundation plus app extensions, and every texture supplies every
  token in its contract.
- **Optional, changeable theme pairing.** A developer may pair a theme with a
  default texture. Pairings are configuration, not hard-coded into themes: they
  can change at runtime, and a theme may have no texture at all. An explicit
  user choice wins over the pairing.
- **Shared across appearances.** A texture has one value set. Light and dark use
  the same values. Colours a texture needs (border and shadow colours) refer to
  theme colour tokens and are bound late to the active variant, so they still
  follow light/dark.

### Mapping from the handoff

- Theme contract, theme variant, generator, theme recipe v1 and colour DTCG stay
  colour-only and unchanged. Foundation v1 (58 colour roles), generation
  fixtures and the algorithm id are untouched. `AuroraContract` keeps accepting
  only `AuroraColorToken`; non-colour tokens are declared on the texture contract.
- Kept as specified, applied to textures: the sealed `AuroraToken<T>` hierarchy
  with `AuroraColorToken` as a source-compatible subclass; every listed token
  type; complete validation reporting all issues; typed `read<T>`; same-type
  aliases with cycle rejection, kept as references in DTCG; DTCG 2025.10 types
  with booleans/enums under `$extensions["dev.aurora"]`; recipes; the Flutter
  conversions and context helpers; portable fixtures.
- "Generator fills non-colour values" no longer applies: textures are authored
  values (Dart, DTCG or a texture recipe), starting from an Aurora starter texture.

### Design

- **Tokens.** `sealed class AuroraToken<T>` (path, description) in
  `token.dart`, re-exported by `contract.dart`. Types: colour, dimension
  (`AuroraDimension`, unit dp/px/rem), number, fontFamily, fontWeight (1-1000),
  duration, cubicBezier, strokeStyle (DTCG keywords, `none`, and the dash
  object form), border, shadow (layers), typography, boolean, and enum (allowed
  values declared on the token).
- **References.** `AuroraRef<T>` is either a literal (value classes are their
  own literal) or `AuroraAlias<T>(token)`. Texture tokens may alias texture tokens
  of the same type; composite fields may alias their field types. An alias to a
  colour token inside a border or shadow is a theme colour reference, resolved
  against the active variant at read time.
- **Validation.** `AuroraTexture` resolves aliases at construction, rejects
  cycles, wrong types, ranges and enum values outside the allowed set, and
  reports every issue in one `AuroraValidationException`. Colour references are
  checked against the theme contract when the runtime, controller or a fixed
  scope pairs textures with themes.
- **Texture foundation v1.** Material 3 baseline roles, kept small because every
  texture must supply them forever: `type.family.brand` and `type.family.plain`;
  the 15-role type scale `type.displayLarge` ... `type.labelSmall`;
  `shape.extraSmall|small|medium|large|extraLarge`;
  `motion.short|medium|long|extraLong`; and the easings
  `motion.easing.standard|emphasizedDecelerate|emphasizedAccelerate`. The
  `type.`, `shape.` and `motion.` namespaces are reserved. Aurora ships an M3
  baseline starter texture so apps only supply what they change.
- **Selection and pairing.** `AuroraSelection.textureId` is an optional,
  explicit user choice, additive in JSON. The runtime holds theme-to-texture
  pairings (`texturePairings`, `pairTexture(themeId, textureId?)`), validated
  against registered ids. Active texture = explicit id, else the active theme's
  pairing, else none (`AuroraState.texture` null). Pairing changes notify only
  when the active texture changes and never override an explicit choice.
  Pairings live outside `AuroraTheme` so themes stay pure colour data and the
  pairing can change without rebuilding themes. Restoration maps unknown ids to
  null.
- **DTCG.** One document per texture. Dimensions in dp export as `px` with
  `$extensions["dev.aurora"].unit = "dp"` so other tools read logical pixels and
  Aurora round-trips exactly.
- **Recipes.** A separate texture recipe v1 (`spec/texture-recipe-v1.md`) declares
  the extension tokens with types and supplies values in DTCG value syntax,
  optionally starting from a starter `base`. Theme recipe v1 is unchanged.
- **Encoding details.** A texture token may not mix dp and px (the DTCG marker is
  per token). `none` strokes export as a single zero-length dash, and an
  all-zero dash pattern decodes as `none`, so authored zero-only patterns are
  rejected. Booleans and enums carry no `$type`.
- **Flutter.** `Aurora.textureOf(context)` returns typed reads plus conversions
  (dimension to double, typography to TextStyle, border to BorderSide/Border,
  shadow to BoxShadows, duration, Cubic, nearest FontWeight, stroke style enum).
  It rebuilds on theme, appearance and texture changes. When a texture is active
  the default ThemeData also maps the foundation type scale and shapes;
  colour-only apps get exactly the previous ThemeData.

### Deferred

- Per-theme texture restrictions (limiting which textures a theme allows).
- Generating textures from inputs; CLI and browser-tool support for texture recipes.
- Additional foundation roles (elevation, spacing, state layers) need a texture
  foundation version decision.
