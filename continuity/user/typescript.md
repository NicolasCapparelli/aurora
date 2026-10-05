# Consuming Aurora from TypeScript

This guide is for apps (and their coding agents) that use Aurora from
TypeScript, such as TokenSeed. Contributors working on the packages themselves
read the [TypeScript contributor guide](../developer/typescript.md).

## Install: an app-owned snapshot

The packages are private and never published to npm. An app commits a built
snapshot exported from an Aurora checkout, so its CI needs no sibling checkout.
From any directory, with Python 3 and Node LTS (corepack) available:

```powershell
python C:\path\to\aurora\tools\vendor.py --typescript --project C:\path\to\my_app
```

The app must already have a `package.json`. The exporter installs and builds
both packages in the Aurora checkout (through `corepack pnpm`), then writes:

```text
vendor/aurora/
  core/    # @aurora/core: package.json, dist/ (ESM + .d.ts), README, NOTICE, MCU license
  react/   # @aurora/react: package.json, dist/, README
  VENDORED.md
  vendor-manifest.json   # kind "typescript", source HEAD and dirty state,
                         # package versions, node/pnpm/tsc versions, SHA-256 per file
```

It exports built ESM with type declarations rather than source, so the app never
compiles Aurora under its own tsconfig settings and needs no build configuration
for it. Copied `package.json` files drop `scripts` and `devDependencies`.

Add both as `file:` dependencies, plus React if the app uses the adapter:

```json
"dependencies": {
  "@aurora/core": "file:vendor/aurora/core",
  "@aurora/react": "file:vendor/aurora/react",
  "react": "^19.0.0"
}
```

`@aurora/react` declares `@aurora/core` and `react` as peer dependencies, so pnpm
links it to the app's single copy of each. This was checked with a scratch pnpm
app outside the Aurora checkout: the adapter's `@aurora/core` resolves to the same
file as the app's, the app typechecks with `skipLibCheck: false`, and app-built
contracts and themes render through `AuroraProvider`. Run `pnpm install` and
commit the vendor directory, `package.json` and the lockfile.

Updates follow the Dart rules. Exporting onto an existing directory fails; pass
`--replace` to swap in a new snapshot. Replacement is refused when the snapshot's
files differ from its manifest (local edits, extra or missing files) or when the
destination holds a Dart snapshot. `--output` picks another app-relative
directory. The exporter never edits `package.json` or runs installs in the app.

## The core API in one page

`@aurora/core` mirrors the Dart core with TypeScript naming. Constructors take
one options object; token-keyed values are a `Map` or an array of
`[token, value]` pairs.

```ts
import {
  AuroraColor, AuroraColorToken, AuroraContract, AuroraFoundation,
  AuroraGenerator, AuroraGenerationRequest, AuroraAliasRule,
  AuroraRuntime, AuroraSelection,
} from '@aurora/core';

// Declare app tokens once, as module constants. Membership is by identity.
export const ticket = new AuroraColorToken('theater.ticket', {
  description: 'Background of a theater ticket.',
});
export const contract = new AuroraContract({ id: 'theater', extensions: [ticket] });

const wicked = AuroraGenerator.generate(new AuroraGenerationRequest({
  contract,
  id: 'wicked',
  name: 'Wicked',
  primary: AuroraColor.hex('#246b35'),
  rules: [[ticket, new AuroraAliasRule(AuroraFoundation.primaryContainer)]],
})).theme;

const runtime = new AuroraRuntime({
  contract,
  themes: [wicked],
  initialSelection: new AuroraSelection({ themeId: 'wicked', appearance: 'system' }),
  fallback: 'preferred',
});
runtime.state.variant.tokens.primary.hex; // '#rrggbbaa'
```

| Dart | TypeScript |
| --- | --- |
| `AuroraAppearance.dark`, `AuroraAppearancePreference.system` | `'dark'`, `'system'` |
| `AuroraVariantFallback.preferred` | `'preferred'` |
| `AuroraGenerationScheme.fidelity`, `AuroraPalette.primary` | `'fidelity'`, `'primary'` |
| `Duration(milliseconds: 200)` | `AuroraDuration.ms(200)` |
| `const AuroraDimension.dp(8)` | `AuroraDimension.dp(8)` |
| `AuroraStrokeStyle.dashes(dashArray: d, lineCap: AuroraLineCap.round)` | `AuroraStrokeStyle.dashes(d, 'round')` |
| `null` (no texture, no pairing) | `undefined` |
| `theme.variants[AuroraAppearance.light]` | `theme.variants.get('light')` |
| `runtime.changes.listen(f)` | `runtime.listen(f)` or `for await (const s of runtime.changes())` |
| `variant.resolveColor(ref)` | `resolveTextureColor(variant, ref)` |
| `AuroraValidationException`, `FormatException`, `ArgumentError`, `StateError` | `AuroraValidationError`, `AuroraFormatError`, `AuroraArgumentError`, `AuroraStateError` |

Errors carry a `category` (`validation`, `format`, `argument`, `state`) that
matches Dart. A validation error lists every issue in `issues`.

Token paths, values, validation results and selection behavior are those of the
[portable spec](../../spec/README.md). Generation is the pinned
`aurora-*-v1-mcu-0.11.1` algorithm and matches Dart byte for byte at 8 bits.

## React: `@aurora/react`

The counterpart of the Flutter controller, scope and engine. `react` ^19 and
`@aurora/core` are peer dependencies: the app installs both, so there is exactly
one core instance. Token membership is checked by identity, so a second copy of
the core would make the app's tokens unknown to the adapter's foundation.

```tsx
import { AuroraFixedScope, AuroraProvider, useAuroraController, useAuroraTokens } from '@aurora/react';

<AuroraProvider
  contract={contract}
  themes={[wicked, hadestown]}
  initialSelection={new AuroraSelection({ themeId: 'wicked' })}
  fallback="preferred"
  cssVariables="root"           // or 'element' (default) or 'none'
>
  <App />
</AuroraProvider>;

function Header() {
  const tokens = useAuroraTokens();              // re-renders on accepted changes only
  const controller = useAuroraController();      // select(), pairTexture()
  return <h1 style={{ color: 'var(--aurora-colors-primary)' }}>…</h1>;
}
```

- **Ownership.** Pass `controller={c}` to borrow a controller you created
  (`new AuroraController({...})`, or `AuroraController.borrow(runtime)` over a
  runtime you own); the provider never disposes it. Pass runtime options instead
  and the provider creates the controller and disposes it on unmount
  (StrictMode-safe). Managed configuration (contract, fallback, themes,
  textures) is fixed while mounted: changing it throws, so give the provider a
  new `key`.
- **System appearance** comes from `matchMedia('(prefers-color-scheme: dark)')`
  and follows live changes (`followSystemAppearance={false}` to opt out). A
  change the selection cannot show under the `reject` fallback leaves the state
  unchanged and goes to `onSystemAppearanceError` (or `reportError`).
- **Hooks:** `useAuroraTokens()`, `useAuroraVariant()`, `useAuroraTexture()`
  (throws without a texture), `useMaybeAuroraTexture()`, `useAuroraToken(token)`
  (typed read of any token: a colour token reads the variant, a texture token
  reads the texture), `useAuroraController()` (throws in a fixed scope),
  `useAuroraState()` and `useAuroraScope()`.
- **Fixed scopes** (`<AuroraFixedScope variant={v} texture={t}>`) theme a subtree
  with no controller or media subscription. They are cheap enough to nest by the
  dozen for gallery thumbnails; emitted declarations are cached per variant and
  texture.

### Live theming

For a chrome that follows a system being edited, give a fixed scope a new variant
on every frame, either as a prop from a parent whose `children` element is
stable, or without rendering at all through its handle:

```tsx
const scope = useRef<AuroraScopeHandle>(null);
<AuroraFixedScope ref={scope} variant={initial}>{chrome}</AuroraFixedScope>;
// on each slider frame:
scope.current!.update(nextVariant, nextTexture);
```

Either path writes CSS variables to the scope's element imperatively, touching
only those whose values changed, and re-renders only components that read
Aurora through hooks. Style the chrome with `var(--aurora-…)` so it updates
without React work.

### CSS custom properties

`auroraCssVariables(variant, texture?, { prefix })` returns the declarations as an
object; `auroraCssText(selector, declarations)` renders a rule;
`applyAuroraCssVariables(element, next, previous)` writes a diff. All work
outside React.

Names are stable: `--{prefix}-{token path with "." replaced by "-"}`, keeping
case. The default prefix is `aurora`, so `colors.onPrimaryContainer` is
`--aurora-colors-onPrimaryContainer` and `type.bodyLarge` is
`--aurora-type-bodyLarge`. A theme token and a texture token that would produce the
same name are rejected.

| Value | CSS |
| --- | --- |
| colour | `#rrggbb`, or `#rrggbbaa` when translucent |
| dimension | `12px` for dp and px (1dp = 1px), `0.75rem` for rem |
| number, fontWeight | the number |
| fontFamily | quoted names, generic families (`serif`, `system-ui`, …) unquoted |
| duration | `200ms` |
| cubicBezier | `cubic-bezier(0.2, 0, 0, 1)` |
| strokeStyle | a `border-style` keyword; a dash pattern becomes `dashed` plus `-dashArray` (`4px 2px`) and `-lineCap` |
| border | the `border` shorthand, plus `-width`, `-style`, `-color` |
| shadow | the `box-shadow` list (`inset` first when set), or `none` |
| typography | the `font` shorthand (`600 20px/1.3 "Fraunces", serif`), plus `-fontFamily`, `-fontSize`, `-fontWeight`, `-letterSpacing`, `-lineHeight` |
| boolean | `1` or `0` |
| enum | the value |

Theme colour references inside textures (`{colors.outline}`) resolve against the
variant the texture is shown with, so borders and shadows follow light and dark.

## React Native: `@aurora/react-native`

A separate, self-contained native adapter (`packages/aurora_react_native`). It
never imports `@aurora/react`, and it has no DOM, CSS, `window`, `matchMedia` or
Node code. Peer dependencies are `@aurora/core` (one instance, as above), `react`
`>=19.0.0 <20` and `react-native` `>=0.79.0`. The qualified combination is Expo
~57.0.26, React 19.2.3, React Native 0.86.3, TypeScript 6.0.3 and Hermes, on
Android only. iOS has not been built or run. The full API, the conversion
table and the font notes are in the
[package README](../../packages/aurora_react_native/README.md).

Install with the native export mode. It writes `core/` and `react-native/`
(never `react/`) and a manifest of kind `react-native`:

```powershell
python C:\path\to\aurora\tools\vendor.py --react-native --project C:\path\to\my_app
```

```json
"dependencies": {
  "@aurora/core": "file:vendor/aurora/core",
  "@aurora/react-native": "file:vendor/aurora/react-native"
}
```

Then run `npm install` (pnpm and Yarn work too), check `npm ls @aurora/core react`
shows one copy of each, and commit the snapshot, `package.json` and lockfile.
npm links `file:` dependencies into `node_modules`, and Metro resolves them
through the packages' `exports`. Replacement follows the rules above. A
snapshot of another kind (`typescript` or Dart) is never replaced, and
`--typescript` with `--react-native` is rejected.

It differs from the browser adapter in a few ways:

- **`AuroraProvider` and `AuroraFixedScope` render no native view.** They render
  only a context provider, so theme and appearance changes never remount
  navigation. They take no CSS or wrapper props.
- **System appearance comes from `Appearance`.** The provider reads
  `getColorScheme()` initially, then follows `addChangeListener`. `dark` is
  dark, and anything else (including `null`) is light. A rejected change goes to
  `onSystemAppearanceError`, or to `console.error` when that is absent.
- **The rules carry over.** Ownership, StrictMode-safe disposal, fixed managed
  configuration, hooks and fixed-scope `update()` handles behave as described
  above.
- **Native conversions are explicit.**
  - `nativeColor` returns `#rrggbb`, or `#rrggbbaa` when the colour has alpha.
  - `nativeDimension` maps dp and px 1:1 and multiplies rem by `remBase`
    (default 16).
  - `nativeTypography` gives line height as absolute dp (Aurora's multiplier
    times the font size) and weight as `'100'`…`'900'`. An optional
    `fontFamilyResolver` picks a family per weight.
  - Also available: `nativeBorder`, `nativeShadow` (RN `boxShadow`, New
    Architecture), `nativeDuration` (ms) and `nativeCubicBezier`.
  - `useAuroraTexture().native.*` does the same from texture tokens, resolving
    colour aliases against the active variant.
- **Unsupported features throw.** By default `AuroraNativeUnsupportedError`
  names the token path and the feature. With `{ mode: 'report' }` you get
  `{ style, unsupported }` instead. Unsupported features are the stroke keywords
  `double`, `groove`, `ridge`, `outset` and `inset`, custom dash patterns, line
  caps, and font weights that aren't a multiple of 100 in 100…900.
- **Fonts are the app's job.** The app loads and bundles them.

`examples/react_native` is a runnable reference that consumes the exported snapshot.

## Portable bundles: exporting designs to Flutter apps

A TypeScript producer exports a theme and an optional texture as an
[Aurora bundle](../../spec/bundle-v1.md); a Flutter app installs it with
`dart run aurora install --bundle <file-or-folder> --project <app>` (see the
[CLI guide](usage.md#install-a-bundle-from-another-tool)).

```ts
import { AuroraBundle } from '@aurora/core';

// theme and texture use AuroraBundle.foundationContract and
// AuroraBundle.textureFoundationContract (foundation-only by default).
const bundle = AuroraBundle.encode({
  theme,
  texture,                         // optional; pairing suggested by default
  provenance: { generator: 'tokenseed@0.2.0', sourceHash: 'sha256:…', createdAt: new Date().toISOString() },
});
const report = AuroraBundle.validate(bundle);   // { valid, issues: [{ category, file, message }], contents }
```

Run `AuroraBundle.validate` in the producer's tests on every export; the Dart
validator accepts exactly the same bundles (shared fixtures check it).
`AuroraBundle.load` returns the theme, texture and pairing or throws by category.
What each of the 58 colour roles and 29 texture tokens means, and how to map
wide-gamut colours, extra modes and extra tokens, is in the
[producer mapping guide](bundle-producers.md).

