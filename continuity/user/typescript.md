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
