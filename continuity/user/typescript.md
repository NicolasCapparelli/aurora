# Consuming Aurora from TypeScript

This guide is for apps (and their coding agents) that use Aurora from
TypeScript, such as TokenSeed. Contributors working on the packages themselves
read the [TypeScript contributor guide](../developer/typescript.md).

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
