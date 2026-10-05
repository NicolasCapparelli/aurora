# Aurora

A theme engine with one complete app contract, many named themes, and explicit
light/dark variants. Optional textures let users pick type, shape, motion, lines,
density and component defaults independently of the colour theme. First
implementation: pure Dart core and Flutter adapter.

## Integrate with a coding agent

Ask your agent:

> Read `aurora/AGENT_ONBOARDING.md` and integrate Aurora into our app.

[AGENT_ONBOARDING.md](AGENT_ONBOARDING.md) includes implementation workflows for
new apps, existing apps, and scoped features, plus copyable prompts and a runnable
Flutter starting point. Replace `aurora/` with your checkout's actual location.

## Packages

- `packages/aurora`: immutable colors, typed token declarations, contracts,
  validation, starter palettes, DTCG color files, and selection runtime; plus
  textures: non-colour token types, texture contracts, an M3 starter texture, texture
  DTCG files and texture recipes.
- `packages/aurora_flutter`: reactive scope, controller, Flutter colors, and a
  complete Material `ColorScheme` bridge.
- `packages/aurora_ts` (`@aurora/core`): the portable core in TypeScript, held to
  the same `spec/fixtures` as Dart, including byte-for-byte generation.
- `packages/aurora_react` (`@aurora/react`): React 19 provider, fixed scopes, hooks
  and CSS custom properties. TypeScript apps start with
  [consuming from TypeScript](continuity/user/typescript.md).
- `examples/theater`: Wicked and Hadestown identities with light/dark variants,
  required ticket colors, and an appearance selector. Palettes are illustrative,
  not official brand assets.
- `examples/textures`: two colour themes and two textures (Soft and Editorial) chosen
  independently, with Trace-shaped texture tokens and matching recipes in
  `examples/recipes/texture-*.json`.

These packages are not published (`publish_to: none`). For an app that builds
independently of this checkout, export and commit an app-owned snapshot:

```powershell
python C:\path\to\aurora\tools\vendor.py --project C:\path\to\my_app
```

Then add the Flutter adapter as an app-relative path dependency:

```yaml
dependencies:
  aurora_flutter:
    path: vendor/aurora/aurora_flutter
```

Both packages are copied together; the adapter's `../aurora` dependency stays
inside the snapshot. Run `flutter pub get` and commit the vendor directory,
pubspec, and app lockfile. See [installation and updates](continuity/user/installation.md).
External checkout paths are only for deliberate Aurora contributor development.

## Define the contract once

```dart
import 'package:aurora_flutter/aurora_flutter.dart';

const ticketBackground = AuroraColorToken(
  'theater.ticketBackground',
  description: 'Background of a theater ticket.',
);

final contract = AuroraContract(
  id: 'theater',
  version: 1,
  extensions: [ticketBackground],
);
```

Aurora adds its 58 foundational color tokens automatically: 46 nondeprecated
Material color roles plus success, warning, and information families. The
`colors` namespace belongs to Aurora. App extensions use their own namespace.
Foundation fields cannot be removed or redefined. All extension fields are
required for every variant. Use the same contract instance and token declarations
throughout an app.

## Provide complete variants

```dart
final wicked = AuroraTheme(
  id: 'wicked',
  name: 'Wicked',
  preferredAppearance: AuroraAppearance.dark,
  variants: [
    for (final appearance in AuroraAppearance.values)
      AuroraStarter.variant(
        contract: contract,
        appearance: appearance,
        values: {
          ticketBackground: AuroraColor.hex(
            appearance == AuroraAppearance.light ? '#fff4d6' : '#342b18',
          ),
        },
      ),
  ],
);
```

Starter palettes explicitly supply the foundation; `values` supplies extensions
and deliberate overrides. This example retains the starter's accent colors.
For a fully authored variant, construct `AuroraThemeVariant` with all values.
Missing, null, incorrectly typed, or undeclared values throw
`AuroraValidationException` listing the problems. Validated maps are immutable.
Token access is typed; completeness is enforced at construction time in this
version, rather than through generated required constructor arguments.

## Three integration levels

### 1. AuroraTokens: direct values

```dart
final tokens = wicked.variants[AuroraAppearance.light]!.tokens;
final primary = tokens.primary;
final ticket = tokens.read(ticketBackground);
```

`AuroraTokens` is an immutable snapshot of the entire contract's values. It has
no widget-tree or Flutter dependency. You own selection and reactivity at this
level. There is no global active theme. The existing `variant.colors` getter is
a convenience alias for `variant.tokens`.

### 2. AuroraScope: a themed subtree

```dart
AuroraScope(
  controller: controller,
  child: const TicketPreview(),
);
```

Place this within an existing app. The scope exposes Aurora values and applies
native Material theming to its descendants. Standard widgets using
`Theme.of(context)` participate automatically. Siblings stay outside that scope;
nested scopes can use independent controllers. The caller creates and disposes
the controller. An optional `themeBuilder` composes app typography and shapes.
For galleries, `AuroraScope.fixed(variant: variant, child: preview)` applies an
immutable snapshot without a controller or device subscription. Token reads
work normally; controller lookup within a fixed scope throws.

### 3. AuroraEngine: app-wide integration

Let the engine create and dispose its controller:

```dart
AuroraEngine.managed(
  contract: contract,
  themes: [wicked],
  initialSelection: const AuroraSelection(themeId: 'wicked'),
  fallback: AuroraVariantFallback.preferred,
  builder: (context, theme) => MaterialApp(
    theme: theme,
    home: const MyHomePage(),
  ),
);
```

Keep theme/contract objects stable outside `build`. Managed configuration is
fixed while mounted; changing selection uses the active controller. Install a
new engine key to replace the contract, theme registry, or initial configuration.
Normal parent rebuilds retain selection and controller identity.

For existing apps that already own a controller:

```dart
final controller = AuroraController(
  contract: contract,
  themes: [wicked],
  initialSelection: const AuroraSelection(themeId: 'wicked'),
  fallback: AuroraVariantFallback.preferred,
);

AuroraEngine(
  controller: controller,
  builder: (context, theme) => MaterialApp.router(
    routerConfig: router,
    theme: theme,
    // Keep existing localization, routing, restoration, and other settings.
  ),
);
```

Inside a descendant widget's `build`:

```dart
final tokens = Aurora.tokensOf(context);
final textColor = tokens.onSurface.flutterColor;
final ticketColor = tokens.read(ticketBackground).flutterColor;
```

From an event handler, change the selection:

```dart
Aurora.controllerOf(context).select(
  const AuroraSelection(themeId: 'wicked', appearance: AuroraAppearancePreference.dark),
);
```

Select another theme or appearance with `controller.select(AuroraSelection(...))`.
The scope and engine rebuild dependents and observe device brightness. A system
preference
keeps the selected theme identity while resolving light/dark. Explicit light or
dark ignores device changes. Call `controller.dispose()` from the owning widget;
the scope and injected-controller engine do not own it.
Controller mutations notify Flutter listeners synchronously after accepted state
changes. New controllers read initial platform brightness unless supplied explicitly.
`AuroraSelection.restoreJson(saved, themes: themes, fallbackId: defaultId)`
restores stored names; `selection.toJson()` serializes without persistence IO.
See the onboarding state-layer recipe for save ordering and error handling.

Material receives the
resolved variant's brightness,
so no second `ThemeMode` selection is needed.
When migrating an existing MaterialApp, remove its separate `darkTheme` and
appearance-selection wiring so Aurora remains the single appearance authority.

Fallback is a required policy: `preferred` uses the theme's declared preferred
variant; `reject` throws and leaves the active state unchanged. Use `reject` with
system appearance only when registered themes support both appearances, or
handle rejection deliberately. No missing variant is generated automatically.

The core `AuroraRuntime` has the same selection model without any Flutter import.
It exposes immutable `state` and an asynchronous broadcast `changes` stream.
Read `state` for the current snapshot; the stream supplies subsequent changes.
Dispose the runtime when done. This replaces the original core `AuroraEngine`
name; `AuroraEngine` now denotes the Flutter app integration.

Both scope and engine support `themeBuilder: (context, variant) => ...` to
construct a native theme from the active colors plus your app's styling. Use the
supplied theme in MaterialApp; the engine deliberately retains your app builder
rather than forwarding every MaterialApp parameter. Explicit widget colors and
nested Flutter Theme widgets keep their usual precedence. Simply changing
`colorScheme` through `copyWith` does not replace every existing concrete color.

App-wide access is above the navigator, so pushed routes and root dialogs can
read Aurora. A page-local scope is below that navigator: a dialog pushed outside
it does not inherit its custom Aurora access. Explicitly wrap that dialog in an
AuroraScope using the intended controller, or use a navigator within the scope.
Local scopes update immediately; MaterialApp may animate its native theme while
direct Aurora tokens already expose the target values. Custom-token interpolation
is deferred.

## Textures: type, shape, motion and more

AuroraTextures work like texture packs: a texture is a named, complete set of
non-colour values layered on top of the colour theme. A texture has one value
set shared by light and dark. Textures are opt-in; an app that registers none is
unchanged.

Like themes, a texture contract is an Aurora foundation plus app extensions, and
every texture supplies every token. Texture foundation v1 is the Material 3 baseline:
`type.family.brand|plain`, the 15-role type scale (`type.displayLarge` ...
`type.labelSmall`), `shape.extraSmall` ... `shape.extraLarge`,
`motion.short|medium|long|extraLong` and three easings. The `type`, `shape` and
`motion` namespaces are reserved. Colours are never texture tokens.

```dart
abstract final class FeelTokens {
  static const cardRadius =
      AuroraDimensionToken('feel.shape.card', description: 'Card corners.');
  static const title =
      AuroraTypographyToken('feel.type.title', description: 'Card titles.');
  static const card =
      AuroraBorderToken('feel.lines.card', description: 'Card border.');
  static const flightCard = AuroraEnumToken('feel.variants.flightCard',
      description: 'Default card layout.', values: ['rich', 'compact']);
}

final textureContract = AuroraTextureContract(id: 'feel', extensions: [
  FeelTokens.cardRadius, FeelTokens.title, FeelTokens.card, FeelTokens.flightCard,
]);

final soft = AuroraTextureStarter.texture( // M3 baseline + your values
  contract: textureContract,
  id: 'soft',
  name: 'Soft',
  values: {
    AuroraTextureFoundation.mediumShape: const AuroraDimension.dp(20),
    FeelTokens.cardRadius: const AuroraAlias(AuroraTextureFoundation.mediumShape),
    FeelTokens.title: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(18),
        fontWeight: AuroraFontWeight.bold,
        letterSpacing: AuroraDimension.dp(0),
        lineHeight: AuroraLiteral(1.3)),
    // Border and shadow colours alias theme colour tokens, so they follow
    // the active theme and appearance.
    FeelTokens.card: const AuroraBorder(
        color: AuroraAlias(AuroraFoundation.outlineVariant),
        width: AuroraDimension.dp(1),
        style: AuroraStrokeStyle.solid),
    FeelTokens.flightCard: 'rich',
  },
);
```

Token types: colour (themes only), dimension (`dp`, `px`, `rem`), number,
fontFamily, fontWeight, duration, cubicBezier, strokeStyle (keywords, `none`,
dash patterns), border, shadow, typography, boolean and enum. Values may alias a
token of the same type with `AuroraAlias`; composite fields may alias their field
types. Aliases resolve at construction; cycles, wrong types, out-of-range values
and enum values outside the declared set fail with every issue reported in one
`AuroraValidationException`. `texture.read(token)` is typed.

Register textures, optionally pair themes with a default texture, and select:

```dart
AuroraEngine.managed(
  contract: contract,
  themes: themes,
  textures: [soft, editorial],
  texturePairings: const {'harbor': 'soft', 'ember': 'editorial'},
  initialSelection: const AuroraSelection(themeId: 'harbor'),
  fallback: AuroraVariantFallback.preferred,
  builder: (context, theme) => MaterialApp(theme: theme, home: const Home()),
);

// In widgets: rebuilds on theme, appearance and texture changes.
final texture = Aurora.textureOf(context);
texture.borderRadius(FeelTokens.cardRadius); // BorderRadius
texture.textStyle(FeelTokens.title);         // TextStyle
texture.border(FeelTokens.card);             // Border, colour from the theme
texture.option(FeelTokens.flightCard, FlightCardLayout.values);
```

The active texture is the selection's `textureId` when the user picked one,
otherwise the theme's paired texture, otherwise none. A theme does not need a
pairing. Change pairings at runtime with
`Aurora.controllerOf(context).pairTexture('ember', 'soft')` (or `null` to
remove one); an explicit user choice is unaffected. Use `Aurora.textureOf` where
a texture is always present and `Aurora.maybeTextureOf` where it may not be.

Conversions also cover `dimension` (logical pixels; `rem` × 16 by default),
`shadows`, `duration`, `curve` (Cubic), `fontWeight` (nearest), `strokeStyle`
and `dashPattern` (Flutter borders cannot dash; paint dashes yourself, as the
example does). With a texture active, the default ThemeData also gets the
foundation type scale and corner shapes for cards, chips, menus, dialogs and
sheets; colour-only apps get exactly the previous ThemeData. Fonts named in a
texture must be available to the app (bundle them as assets for web).

Selection JSON gains an optional `textureId`; `AuroraSelection.restore` takes
`textures` and restores an unknown id to null (the theme's pairing). Pairings
are app configuration, not part of the stored selection. `AuroraTextureDtcg.encode/decode` and
`AuroraTextureRecipe.decode` read and write textures; see the
[DTCG profile](continuity/data/dtcg-profile.md) and
[texture recipe v1](spec/texture-recipe-v1.md).

**Migration:** nothing changes for existing apps. `AuroraColorToken` is now one
subclass of the sealed `AuroraToken<T>`, and `AuroraColor` is an
`AuroraRef<AuroraColor>`; existing code compiles unchanged. To adopt textures,
declare a texture contract, build textures with `AuroraTextureStarter.texture`,
pass `textures:` (and optional `texturePairings:`) to the engine or controller,
and set `textureId` on selections when the user picks a texture.

## Portable theme values

`AuroraDtcg.encode(variant)` returns a JSON-compatible DTCG token document.
`AuroraDtcg.decode(document, contract: contract, appearance: appearance)` validates
and constructs a complete variant. See [the supported profile](continuity/data/dtcg-profile.md).
Identity and appearance are passed separately; no custom envelope is embedded
inside the token document.

Colors use 8-bit sRGB. `AuroraColor.hex` accepts CSS `#RRGGBB` or `#RRGGBBAA`;
`AuroraColor(int)` accepts ARGB. Neither starter palettes nor structural
validation constitute an accessibility audit of the app's final color usage.

## Generate a theme

```dart
final result = AuroraGenerator.generate(AuroraGenerationRequest(
  contract: contract,
  id: 'wicked',
  name: 'Wicked',
  primary: AuroraColor.hex('#246b35'),
  rules: {
    ticketBackground: const AuroraAliasRule(AuroraFoundation.primaryContainer),
  },
));

final generatedTheme = result.theme;
final contrastIssues = result.issues;
```

This produces complete light/dark variants. Secondary and tertiary seeds are
optional. Every app extension needs an explicit value or generation rule.
Choose `scheme: AuroraGenerationScheme.fidelity` (or vibrant, expressive,
content, monochrome, neutral, rainbow, fruitSalad) when tonal-spot does not suit
the brand. Each scheme has a pinned algorithm identifier. Defaults retain the
existing tonal-spot output. At contrast level zero with one seed and no
overrides, all 46 Material roles match `ColorScheme.fromSeed` on the verified
Flutter SDK; regression tests check this. Recheck after Flutter upgrades.

For per-entity branding, `AuroraGenerator.variants(seed)` returns immutable light
and dark foundation-only snapshots without registration. These snapshots cannot
replace a canonical app variant requiring extensions. Use
`AuroraContrast.bestOn(background, candidates)` to choose the highest-contrast
candidate over an opaque background, and `result.debugReport()` to format issues.
Shared and per-variant overrides preserve exact requested colors; diagnostics
report contrast problems without silently changing them.

The generator is pure Dart and deterministic, with an explicit algorithm version.
It returns ordinary Aurora themes and JSON-compatible manifests containing DTCG
variant documents. See [the generator guide](continuity/developer/generator.md) for inputs, rules,
precedence, diagnostics, and portability. Run `dart run example/generate.dart`
from `packages/aurora` for a standalone example. Agent endpoints and a visual
preview use this same logic. See [the CLI guide](continuity/user/usage.md).

## Open the theme generator

From `packages/aurora`, run:

```powershell
dart run aurora generate
```

This opens a local HTML/CSS interface in your browser with seed inputs, light/dark
previews, all foundation tokens, contrast diagnostics, and JSON downloads.
To use `aurora generate` directly, activate the package as described in the
[CLI guide](continuity/user/usage.md). Stop the local server with Ctrl+C.

Color pickers complement exact hex inputs. Launch with `--project PATH_TO_APP`
to enable Add to project, which installs a theme bundle and Dart factory while
preserving existing files. Register the returned theme with your app's controller.

Agents can generate without a browser:

```powershell
dart run aurora generate --json --input ../../examples/recipes/theater.json
```

This accepts a portable app-contract recipe and writes a JSON result to stdout.
See [recipe v1](spec/recipe-v1.md) for extension rules and overrides.

Themes and textures made in other tools (such as TokenSeed) arrive as a
[portable bundle](spec/bundle-v1.md). From an app that depends on Aurora:

```powershell
dart run aurora install --bundle C:\path\to\ocean.aurora.json --project .
```

## Run and verify

From `examples/theater`:

```powershell
flutter pub get
flutter run -d chrome
```

From the repository root, run `./tools/check.ps1` for Python exporter tests,
TypeScript install, build, typecheck and tests, Dart dependency resolution, format
checking, analysis, core tests, widget tests, and example analysis. Python 3, Dart,
Flutter and Node LTS (with corepack) must be on PATH.
The demo can also be compiled with `flutter build web` in `examples/theater`.

Foundation accessors, explicit presets, and the Material bridge are generated
from a single checked-in table. To change that table:

```powershell
python tools/generate_foundation.py
dart format packages/aurora/lib packages/aurora_flutter/lib
```

## Next milestones

- App-contract authoring support in the visual generator.
- More color-space support as real use cases require.
- A texture foundation v2 (elevation, spacing, state layers) and themes that
  recommend a default texture; texture support in the CLI and browser tool.
- Evaluate the published DTCG Resolver for portable variant packaging.
- A React Native adapter on top of `@aurora/core`.

The [portable specification](spec/README.md), generated foundation definitions,
and checked-in JSON conformance cases describe the cross-language boundary.

Terminology and decisions are tracked in [design notes](continuity/decisions/design-notes.md).
