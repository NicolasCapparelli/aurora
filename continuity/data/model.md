# Data model

Aurora has no database. Its data is in-memory immutable objects plus portable JSON boundary formats. Themes are colour-typed; textures hold every other token type.

## Schema routing index

| Model | Authoritative definition | Producers / consumers |
| --- | --- | --- |
| `AuroraColor` (ARGB int) | [color.dart](../../packages/aurora/lib/src/color.dart) | everywhere; Flutter via `flutterColor` in [material.dart](../../packages/aurora_flutter/lib/src/material.dart) |
| Token declaration, contract, validation error | [contract.dart](../../packages/aurora/lib/src/contract.dart) | apps, recipe decoder, generator |
| Foundation tokens (58) | table in [generate_foundation.py](../../tools/generate_foundation.py), generating [foundation.dart](../../packages/aurora/lib/src/foundation.dart), [spec/foundation-v1.json](../../spec/foundation-v1.json), [material.dart](../../packages/aurora_flutter/lib/src/material.dart), and presets in [starters.dart](../../packages/aurora/lib/src/starters.dart) | contract, starters, Material bridge |
| Variant, theme, appearance enums | [theme.dart](../../packages/aurora/lib/src/theme.dart) | runtime, DTCG, generator |
| Selection, state, fallback | [runtime.dart](../../packages/aurora/lib/src/runtime.dart) | Flutter controller/scope/engine |
| DTCG variant document | [dtcg.dart](../../packages/aurora/lib/src/dtcg.dart), [profile](dtcg-profile.md), fixtures in [spec/fixtures](../../spec/fixtures) | generator manifest, installer files, UI downloads |
| Token hierarchy and texture values (`AuroraToken<T>`, `AuroraRef`, `AuroraDimension`, `AuroraTypography`, ...) | [token.dart](../../packages/aurora/lib/src/token.dart), [ref.dart](../../packages/aurora/lib/src/ref.dart), [values.dart](../../packages/aurora/lib/src/values.dart) | textures, DTCG, recipes, Flutter `AuroraTextureTokens` |
| Texture contract, texture, texture foundation and starter | [texture.dart](../../packages/aurora/lib/src/texture.dart), [texture_foundation.dart](../../packages/aurora/lib/src/texture_foundation.dart), [spec/texture-foundation-v1.json](../../spec/texture-foundation-v1.json) | runtime, Flutter controller/scope/engine |
| Texture DTCG document and texture recipe | [texture_dtcg.dart](../../packages/aurora/lib/src/texture_dtcg.dart), [texture_recipe.dart](../../packages/aurora/lib/src/texture_recipe.dart), shared [texture_codec.dart](../../packages/aurora/lib/src/texture_codec.dart), [profile](dtcg-profile.md#aurora-dtcg-texture-profile-v1), [texture recipe v1](../../spec/texture-recipe-v1.md) | apps, example recipes, fixtures |
| Recipe JSON (v1) | [recipe.dart](../../packages/aurora/lib/src/recipe.dart), [recipe-v1](../../spec/recipe-v1.md), example [theater.json](../../examples/recipes/theater.json) | CLI `--json`, installer (stored as `recipe.json`) |
| Generation request/result/manifest | [generator.dart](../../packages/aurora/lib/src/generator.dart), [generation-v1](../../spec/generation-v1.md), fixture [generation-v1.json](../../spec/fixtures/generation-v1.json) | CLI, server, installer |
| Contrast pair/check | [contrast.dart](../../packages/aurora/lib/src/contrast.dart) | manifest `contrast` array |
| Installed theme bundle | [install.dart](../../packages/aurora/lib/src/tooling/install.dart), [CLI guide](../user/usage.md) | user projects (`lib/aurora_themes/<id>/`) |

## Entities and semantics

- **Contract**: foundation (version 1) plus app extensions, identified by `id` and a positive integer `version`. A token's identity within a contract is its dotted path, but membership is checked with `identical` against the contract's own declaration instance, so variants, themes, and the runtime must share the same contract instance. Foundation paths live in the reserved `colors.` namespace. A path may not be both a token and a group prefix.
- **Variant**: complete map of every contract token to an `AuroraColor` for one appearance (light or dark). Inputs are copied into an immutable map; missing, non-color, or undeclared entries fail with all issues listed.
- **Theme**: id, display name, at most one variant per appearance (same contract instance), and a preferred appearance that must exist. Having both light and dark is not required.
- **Texture contract**: texture foundation v1 (29 tokens in the reserved `type`, `shape`, `motion` namespaces) plus app extensions of any non-colour type; same path, collision and instance-identity rules as theme contracts. Colour tokens are rejected.
- **Texture**: id, name and a complete value for every texture-contract token, shared by all appearances. Authored values (keeping aliases, for export) and resolved values are both kept, immutable. Colour fields inside borders and shadows stay as literal colours or theme colour references (`colorReferences`), resolved with `variant.resolveColor`.
- **Selection**: theme id plus preference (light/dark/system), plus an optional explicit `textureId`. The runtime also holds mutable theme-to-texture pairings; the active texture is the explicit id, else the theme's pairing, else none. System resolves through the host-supplied device appearance; the requested preference is retained even when fallback resolves to another appearance.
- **Registry** (runtime): unique theme ids; every theme's contract identical to the runtime's.
- **Lifecycle**: all objects are immutable except the runtime's current state. Disposal closes the stream and later writes throw `StateError`. Selection is not persisted.

## Representations and conversions

- Color: unsigned 32-bit ARGB in memory. CSS hex input is `#RRGGBB` or `#RRGGBBAA` (RGBA order, not ARGB). `AuroraColor.hex` output is always 8 digits.
- Flutter conversions: `Color.auroraColor` preserves ARGB; `AuroraAppearance.brightness` and `AuroraFlutterAppearance.fromBrightness` map concrete appearances without importing Flutter into core. See [conversions.dart](../../packages/aurora_flutter/lib/src/conversions.dart).
- Selection JSON: `themeId` and `appearance` strings. `fromJson` strictly validates structure/names; `restore` and `restoreJson` default unknown identities to a registered caller fallback and unknown preferences to system. No IO or missing-variant resolution occurs during restoration. See [selection spec](../../spec/README.md#selection-semantics).
- DTCG: structured sRGB `components` in [0,1] plus `alpha`. Decoding quantizes to 8 bits. Export emits resolved colors and descriptions only; aliases, `$extensions`, and `$deprecated` are accepted on import and dropped (information loss). A document holds one variant; identity, appearance, and contract id/version are not embedded, so the caller must supply them.
- Recipe to request: hex strings become `AuroraColor`; token paths resolve against the recipe's contract; unknown fields are rejected at every object boundary.
- Manifest (`AuroraGenerationResult.toJson`): `algorithm`, `foundationVersion`, `contract {id, version}`, theme identity, `preferredAppearance`, `variants` (appearance to DTCG document), `contrast` list. It is not itself a DTCG document.
- Contrast: sRGB relative luminance after compositing foreground alpha over an opaque background; translucent backgrounds give a `null` ratio and status `unknown`.

## Invariants and compatibility

- Foundation fields cannot be removed or redefined. Adding required foundation fields changes compatibility and needs an explicit versioning decision ([AGENTS.md](../../AGENTS.md)). Foundation version is 1. There is no portable theme/contract version metadata or migration yet (open design question).
- Generated outputs and checked-in fixtures are pinned by algorithm id `aurora-tonal-v1-mcu-0.11.1`; algorithm or dependency changes need a reviewed version and fixture update.
- `spec/fixtures/*.json` are cross-language references: tests consume them and must not regenerate them.
- Additional brand schemes have distinct `aurora-<schemeName>-v1-mcu-0.11.1` identifiers and separate [scheme fixtures](../../spec/fixtures/generation-schemes-v1.json); the existing default fixture stays unchanged. Foundation-only per-seed variants use their own contract, never the app's extension contract.
