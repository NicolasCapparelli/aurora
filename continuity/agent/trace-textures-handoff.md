# AuroraTextures: API summary and Trace U3 mapping

Report for the owner and input for Trace task U3 (`trace/docs/ui-phase.md` §U3),
written 2026-10-04 and merged into `main`. The handoff's "non-colour tokens" are
now **AuroraTextures**, a texture-pack-like layer on top of the colour theme.

## What changed from the handoff

The owner decided that non-colour tokens are a **separate selectable layer**
with its own foundation and extensions, shared by light and dark. So:

- Themes, the theme contract (`AuroraContract`), the generator, theme recipes
  and colour fixtures are unchanged and colour-only.
- Non-colour tokens are declared on an `AuroraTextureContract` and supplied by
  `AuroraTexture`s. A developer may pair a theme with a default texture; the
  pairing can change at runtime, a theme may have none, and an explicit user
  choice wins.
- U3 step 2 ("declare tokens in `traceContract`") and step 3 ("move values into
  the three Aurora themes") become: declare them on a Trace texture contract and
  put the values in three textures (`atlas`, `fieldnotes`, `trace`), registered
  with `texturePairings: {'atlas': 'atlas', 'fieldnotes': 'fieldnotes', 'trace': 'trace'}`
  so each theme keeps its current look. Trace's same-look test for Classic keeps
  working because Classic's pairing reproduces today's values.

## API summary

Core (`package:aurora/aurora.dart`):

| API | Purpose |
| --- | --- |
| `sealed class AuroraToken<T>` (`path`, `description`, `type`) | Base of every token. `AuroraColorToken` is a subclass; existing code is unchanged. |
| `AuroraDimensionToken`, `AuroraNumberToken`, `AuroraFontFamilyToken`, `AuroraFontWeightToken`, `AuroraDurationToken`, `AuroraCubicBezierToken`, `AuroraStrokeStyleToken`, `AuroraBorderToken`, `AuroraShadowToken`, `AuroraTypographyToken`, `AuroraBooleanToken`, `AuroraEnumToken(values:)` | Non-colour token declarations. |
| `AuroraDimension(value, unit)` with `.dp/.px/.rem`, `AuroraFontFamily`, `AuroraFontWeight`, `AuroraCubicBezier`, `AuroraStrokeStyle` (`.solid/.dashed/.dotted/.none/.keyword/.dashes`), `AuroraBorder`, `AuroraShadow`/`AuroraShadowLayer`, `AuroraTypography` | Immutable values. Numbers are `double`, durations `Duration`, booleans `bool`, enums `String`. |
| `AuroraRef<T>`, `AuroraAlias(token)`, `AuroraLiteral(value)` | References. Value classes are their own literal. An alias to a colour token inside a border or shadow refers to the active theme. |
| `AuroraTextureContract(id:, version:, extensions:)` | Texture foundation plus app extensions; rejects colour tokens, reserved `type.`/`shape.`/`motion.` paths, collisions. |
| `AuroraTextureFoundation` | 29 foundation tokens: `brandFamily`, `plainFamily`, `displayLarge` ... `labelSmall`, `extraSmallShape` ... `extraLargeShape`, `short/medium/long/extraLongDuration`, `easingStandard/EmphasizedDecelerate/EmphasizedAccelerate`. |
| `AuroraTextureStarter.material`, `AuroraTextureStarter.texture(contract:, id:, name:, values:)` | Material 3 baseline values; build a texture supplying only extensions and overrides. |
| `AuroraTexture(contract:, id:, name:, values:)` | Complete, validated, immutable texture. `read<T>(token)`, `readEnum(token, Enum.values)`, `authored(token)`, `colorReferences`, `validateColors(themeContract)`. |
| `variant.resolveColor(ref)` | Resolve a texture colour against a theme variant. |
| `AuroraRuntime(textures:, texturePairings:)`, `runtime.textures`, `runtime.texturePairings`, `runtime.pairTexture`, `runtime.textureContract`, `AuroraState.texture` | Texture registration, pairing and selection. |
| `AuroraSelection(textureId:)`, `restore(textureId:, textures:)`, `restoreJson(..., textures:)` | Selection with an optional explicit texture; JSON gains `textureId`; unknown ids restore to null. |
| `AuroraTextureDtcg.encode/decode` | One DTCG 2025.10 document per texture. |
| `AuroraTextureRecipe.decode(json, contract:)`, `decodeContract`, `encodeValue` | Texture recipe v1. |

Flutter (`package:aurora_flutter/aurora_flutter.dart`):

| API | Purpose |
| --- | --- |
| `AuroraController(textures:, texturePairings:)`, `controller.textures`, `controller.texturePairings`, `controller.pairTexture(themeId, textureId?)`, `AuroraEngine.managed(textures:, texturePairings:)`, `AuroraScope.fixed(texture:)` | Register, pair or preview textures. |
| `Aurora.textureOf(context)` / `Aurora.maybeTextureOf(context)` | `AuroraTextureTokens` bound to the active variant; rebuilds on theme, appearance and texture changes. |
| `AuroraTextureTokens`: `read`, `dimension`, `radius`, `borderRadius`, `textStyle`, `borderSide`, `border`, `shadows`, `duration`, `curve`, `fontWeight`, `strokeStyle`, `dashPattern`, `flag`, `choice`, `option`, `color`, `textTheme`, `applyTo(ThemeData)` | Typed reads and conversions. |
| `nearestFontWeight` | Aurora weight to the nearest Flutter `FontWeight`. |

With a texture active and no `themeBuilder`, the engine and scopes apply the
texture foundation (type scale, card/chip/menu/dialog/sheet shapes) to ThemeData.
Trace uses its own `themeBuilder`, so its ThemeData only changes where it calls
`Aurora.textureOf`.

## Trace StylePack mapping (from `ui-phase.md` §3)

| StylePack field | Token type | Suggested paths | Notes |
| --- | --- | --- | --- |
| Families: display, title, body, label | fontFamily | `trace.type.family.display` ... `.label` | Fonts stay bundled by Trace. |
| Route codes, page title, section title, month header, stat value (strip and home), hero value, body, label, kicker | typography, with `fontFamily` aliasing the family tokens | `trace.type.routeCode`, `trace.type.statStrip`, `trace.type.homeStat`, ... | Weights such as 650 and 750 are supported; Flutter gets the nearest `FontWeight` plus a `wght` variation. Flutter treats dp text sizes as sp (text scaling still applies). |
| Kicker uppercase | **no typography field** | `trace.type.kickerUppercase` (boolean) | DTCG typography has no text case; apply it in Trace. |
| Radii: card, group, chip, field, hero, button, small | dimension | `trace.shape.card` ... | Pill is `999 dp`. |
| Card border 1 dp `outlineVariant`, or none | border | `trace.lines.card` | Colour `AuroraAlias(AuroraFoundation.outlineVariant)`; Classic uses `AuroraStrokeStyle.none` (or a boolean `trace.lines.cardBorder`). |
| Equipment divider dashed or none | strokeStyle | `trace.lines.equipmentDivider` | Trace paints the dashes, using `dashPattern`. |
| Elevation per class | number (or shadow) | `trace.depth.card` | All 0 today. |
| `TraceSpace` scale, `TraceSizes`, screen margin, card padding | dimension | `trace.density.*`, `trace.sizes.*` | |
| `TraceMotion` | duration, cubicBezier | `trace.motion.*` | |
| Chrome: logoGlyph, emblemShape, navIndicator, iconStyle | boolean, enum | `trace.chrome.*` | |
| `variantDefaults` (7 slots) | enum per slot, values = registered variant ids | `trace.variants.flightCard` ... | Read with `option(token, FlightCardVariant.values)`. |
| `companionPalette` | **colour, not texture** | theme colour extensions on `traceContract`, if it should vary | Textures cannot hold colours. |
| Material component themes from the pack | Trace's `themeBuilder` reading `Aurora.textureOf(context)` | | Aurora's `applyTo` covers only foundation roles. |

Everything in StylePack is expressible. The open point is how textures pair with
themes (below).

## Pairing textures with themes (decided)

Trace today ties each pack to a theme (`StylePack.id == theme id`). Aurora keeps
textures separate but lets the app pair them: pass `texturePairings` to
`AuroraEngine.managed` or `AuroraController`, and change them with
`controller.pairTexture(themeId, textureId)` (null removes one). The active
texture is the selection's explicit `textureId`, else the theme's pairing, else
none. Trace can keep selections without a `textureId` so choosing Atlas still
brings the Atlas texture, and add a separate texture picker later.

## Verification

- `./tools/check.ps1` green: 7 exporter, 122 core, 30 adapter and 4
  textures-example tests.
- Compatibility: a scratch copy of Trace's current tree (Trace itself untouched)
  re-vendored with this code analyzes clean and passes all 484 of its tests, the
  same as on Trace's current snapshot.
- The textures example was built for web and checked in a browser: corners, dashed
  borders, layout and chip shapes switch with the texture. Font family switching is
  verified by widget tests only, because the example bundles no fonts.

## Vendor command

```powershell
python C:\Users\cappa\Desktop\Projects\aurora\tools\vendor.py --project C:\Users\cappa\Desktop\Projects\trace --replace
```

Vendoring an uncommitted tree works but records `sourceDirty: true`.
