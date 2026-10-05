# Primer: React Native handoff

For Primer's agent (Expo/React Native app at `primer/app`). Aurora now ships
`@aurora/react-native`. Primer owns its contract, extensions, themes, texture,
fonts, package manifest, lockfile and the vendoring step. This handoff did not
edit Primer.

## Export into Primer

From any directory, with Python 3 and Node LTS (corepack) available:

```powershell
python C:\Users\cappa\Desktop\Projects\aurora\tools\vendor.py --react-native --project C:\Users\cappa\Desktop\Projects\primer\app
```

It writes `app/vendor/aurora/{core,react-native}`, `VENDORED.md` and
`vendor-manifest.json` (kind `react-native`, source revision, dirty state,
versions, SHA-256 per file). It never writes `@aurora/react`. To update later,
add `--replace`. That is refused if the snapshot was edited or is of another
kind. Then add these to `app/package.json`:

```json
"@aurora/core": "file:vendor/aurora/core",
"@aurora/react-native": "file:vendor/aurora/react-native"
```

Run `npm install`, confirm `npm ls @aurora/core react` shows one copy of each,
and commit the snapshot, `package.json` and `package-lock.json`. Export from a
committed Aurora revision so the manifest records `sourceDirty: false`.

## Public imports

```ts
import {
  AuroraController, AuroraProvider, AuroraFixedScope, systemAppearance,
  useAuroraScope, useAuroraVariant, useAuroraTokens, useAuroraToken,
  useAuroraTexture, useMaybeAuroraTexture, useAuroraController, useAuroraState,
  nativeColor, nativeColorWithAlpha, nativeDimension, nativeBorderRadius,
  nativeTypography, nativeStrokeStyle, nativeBorder, nativeShadow,
  nativeDuration, nativeCubicBezier, AuroraNativeUnsupportedError,
} from '@aurora/react-native';
```

Contracts, tokens, themes, textures and selections come from `@aurora/core`.
Never import `@aurora/react` on native.

## Integration shape for Primer

```tsx
// app/_layout.tsx: chrome follows the device appearance; navigation never remounts.
<AuroraProvider contract={contract} themes={[primer]} textures={[primerTexture]}
  initialSelection={new AuroraSelection({ themeId: 'primer', textureId: 'primer' })}
  fallback="preferred">
  <Stack />
</AuroraProvider>

// Canvas screen: the playground stays dark inside appearance-aware chrome.
<AuroraFixedScope variant={primer.variants.get('dark')!} texture={primerTexture}>
  <Canvas />
</AuroraFixedScope>

// Inside a node: app extensions and texture tokens, typed.
const ready = useAuroraToken(primerTokens.statusReady);       // AuroraColor
const view = useAuroraTexture();
const stroke = view.native.border(primerTokens.relationshipStroke); // aliases resolved
const title = view.native.typography(primerTokens.nodeTitle, { fontFamilyResolver });
<View style={[{ backgroundColor: nativeColor(ready) }, stroke, view.native.shadow(primerTokens.currentNodeGlow)]} />
```

Declare the extension tokens (known, ready, completed, current-node outline,
relationship strokes, canvas and phase fills) in Primer's contract with values in
every variant. They do not belong in Aurora's foundation. For a camera or other
per-frame state, keep it outside Aurora. Theme changes re-render only hook readers.

## Conversions and limits

Full table: [package README](../../packages/aurora_react_native/README.md#conversions).

- **Colours** become `#rrggbb`, or `#rrggbbaa` when they have alpha.
  `nativeColorWithAlpha(c, a)` replaces the alpha.
- **Dimensions:** dp and px map 1:1. rem multiplies by `remBase` (default 16).
- **Typography:** `lineHeight` is absolute dp (Aurora's multiplier × font size).
  `fontWeight` is `'100'`…`'900'`. The first family is used unless
  `fontFamilyResolver(families, weight)` picks one. On Android, custom fonts
  choose weight by family name.
- **Fonts:** Primer loads and bundles Fraunces and DM Sans itself.
- **Borders** give width, colour (alias resolved against the active variant) and
  style `solid`, `dashed` or `dotted`. `none` gives a width of 0.
- **Shadows** become a New Architecture `boxShadow` list.
- **Motion:** durations are milliseconds and curves are `{ x1, y1, x2, y2 }` for
  `Easing.bezier`.
- **Unsupported:** `double`, `groove`, `ridge`, `outset` and `inset` strokes,
  custom dash patterns, line caps, and font weights that aren't a multiple of 100.
  These throw `AuroraNativeUnsupportedError` (naming the token path) unless you
  pass `{ mode: 'report' }`, which returns `{ style, unsupported }`.
  Relationship strokes with dash patterns need Primer's own SVG drawing.

## Verified

See [status](../status.md#last-verified-state) for commands and results.

- **Consumer versions:** Expo ~57.0.26, React 19.2.3, React Native 0.86.3,
  TypeScript 6.0.3 and Hermes, as in Primer's `app/package.json` on 2026-10-05.
- **Android:** verified on an Android 34 emulator (x86_64) through
  `examples/react_native`.
- **iOS:** not built or run. There is no macOS here.
