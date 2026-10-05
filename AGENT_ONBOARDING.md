# Aurora agent onboarding

Use this playbook to **implement Aurora in the user's app**, either from scratch
or by migrating an existing app. Complete the requested integration and verify
it; reading this file or generating theme files alone is not completion.

This guide targets Dart/Flutter apps. For TypeScript and React apps, read
[consuming Aurora from TypeScript](continuity/user/typescript.md) instead: it covers
the `@aurora/core` and `@aurora/react` snapshot install, the React provider, fixed
scopes, CSS custom properties and portable bundles. React Native apps use
`@aurora/react-native` from the same guide
([React Native section](continuity/user/typescript.md#react-native-aurorareact-native)).
Never import the browser adapter on native. Follow the user's requested scope and the target app's repository
instructions. Make routine implementation decisions from the app's conventions.
Ask only when missing information prevents meaningful progress; continue any
independent work while waiting. This document does not authorize publishing,
deployment, or unrelated edits.

## TypeScript and React apps

The rest of this playbook is for Flutter. A TypeScript or React app (such as
TokenSeed) uses `@aurora/core` and `@aurora/react`; the full guide is
[consuming Aurora from TypeScript](continuity/user/typescript.md).

1. Export an app-owned snapshot (Python 3 and Node LTS with corepack):
   `python <aurora>/tools/vendor.py --typescript --project <app>`, which writes
   `<app>/vendor/aurora/{core,react}` with built ESM, type declarations and a
   provenance manifest. Commit it.
2. Depend on it from the app's `package.json`:
   `"@aurora/core": "file:vendor/aurora/core"` and
   `"@aurora/react": "file:vendor/aurora/react"` (plus `react` ^19).
3. Theme the app or a subtree:

   ```tsx
   <AuroraProvider contract={contract} themes={themes} fallback="preferred"
     initialSelection={new AuroraSelection({ themeId: 'wicked' })} cssVariables="root">
     <App />  {/* style with var(--aurora-colors-primary); read tokens with useAuroraTokens() */}
   </AuroraProvider>
   ```

   Use `<AuroraFixedScope variant={v} texture={t}>` for previews and thumbnails, and
   its `update()` handle for per-frame live theming.
4. To hand designs to Flutter apps, export a portable bundle with
   `AuroraBundle.encode(...)`, check it with `AuroraBundle.validate(bundle)` in the
   app's tests on every export, and map roles with the
   [producer mapping guide](continuity/user/bundle-producers.md). The Flutter app
   installs it with `dart run aurora install --bundle <file> --project .`.

A React Native or Expo app exports with `--react-native` instead. That writes
`vendor/aurora/{core,react-native}`. Depend on `@aurora/core` and
`@aurora/react-native` through `file:`, wrap the navigator in `AuroraProvider`
(it renders no view and follows `Appearance`), and convert tokens with
`nativeColor` and `useAuroraTexture().native.*`. Unsupported native features
throw unless you pass `{ mode: 'report' }`. See the
[package README](packages/aurora_react_native/README.md).

## Copyable prompts for developers

**Existing app, complete integration**

> Read `aurora/AGENT_ONBOARDING.md` and integrate Aurora into this Flutter app
> across the whole app. Preserve its navigation, typography, component styling,
> and existing behavior. Reuse our brand colors, provide light and dark variants,
> connect the theme controls, and verify the integration. Implement the changes.

**New app**

> Read `aurora/AGENT_ONBOARDING.md` and build the Flutter app described below
> using Aurora for all app-owned UI colors from the start. Use a single typed
> contract, complete named themes, light/dark/system selection, and app-wide
> integration. Implement and verify the app. App brief: [your description].

**Only part of an app**

> Read `aurora/AGENT_ONBOARDING.md` and integrate Aurora only into [screen or
> feature] using AuroraScope. Preserve the appearance of everything outside that
> feature. Implement theme switching and verify that the scope stays isolated.

**Generate and integrate a named theme**

> Read `aurora/AGENT_ONBOARDING.md` and add a theme called [name] inspired by
> [description or seed colors] to our existing Aurora contract. Supply every
> required extension for every requested appearance, register it, expose it in
> our theme selector, and verify switching. Preserve existing themes.

Replace `aurora/` with the actual checkout location. A developer may also simply
ask: “Read `aurora/AGENT_ONBOARDING.md` and integrate Aurora into our app.”
For that request, use app-wide integration unless the app context indicates a
narrower scope. Report assumptions briefly and proceed.

## 1. Inspect and select a route

Find the target app's `pubspec.yaml`, app entry points, MaterialApp or
MaterialApp.router, routing configuration, theme definitions, settings storage,
and tests. Search for ThemeData, ColorScheme, themeMode, darkTheme, explicit
Colors/Color literals, custom component themes, and app-specific palettes.
Read the app's local instructions and preserve unrelated working changes.

Identify the Aurora checkout separately from the target app. Resolve all paths
below relative to **this document's directory**, not the agent's current directory.
Do not apply Aurora's contributor workflow to an unrelated app repository.

| User's scope | Integration | Selection and ownership |
| --- | --- | --- |
| Entire Flutter Material app | AuroraEngine | Prefer `.managed` for a new app; inject an AuroraController when the app's state layer should own it. |
| One screen, feature, or subtree | AuroraScope | Caller owns and disposes its controller. Siblings remain outside the scope. |
| Values only, with app-owned reactivity | AuroraTokens | Immutable snapshots; caller handles selection and rebuilds. |
| Pure Dart app/tool | AuroraRuntime | Caller supplies device appearance and disposes the runtime. |

AuroraEngine's default adapter produces Material ThemeData. For Cupertino or
another UI framework, use direct tokens and an appropriate native bridge rather
than promising that the Material bridge will theme every widget.

## 2. Install the current packages

Aurora is not published (`publish_to: none`). Do not invent a hosted package
version or run a hosted `pub add aurora_flutter`. Export an app-owned snapshot
from the Aurora checkout using Python 3, then commit the entire result:

```powershell
python C:\path\to\aurora\tools\vendor.py --project C:\path\to\my_app
```

From the **target Flutter app**, use app-relative paths:

```yaml
dependencies:
  flutter:
    sdk: flutter
  aurora_flutter:
    path: vendor/aurora/aurora_flutter
```

Preserve the rest of the pubspec. Keep both vendored package directories together:
the adapter depends on its sibling `../aurora`, inside the app. Do not depend on
the external checkout, absolute machine paths, or symlinked packages. For an
existing integration, replace the external dependency path without changing its
theme behavior. See [installation and updates](continuity/user/installation.md).
Run `flutter pub get` in the target app and commit its lockfile along with the
snapshot. Verify in a clean copy that has no sibling Aurora checkout.
Import `package:aurora_flutter/aurora_flutter.dart`; it exports the core API too.
For pure Dart work, depend on `vendor/aurora/aurora` and import `aurora.dart` instead.
Check SDK constraints and dependency resolution; do not silently downgrade the
app's toolchain or change Aurora's pinned generation dependency.
The core pins `material_color_utilities` to 0.11.1 for reproducible output.
A Flutter upgrade that requires another version can break dependency resolution;
resolve that deliberately in Aurora rather than overriding the pin in the app.

## 3. Establish the contract and theme registry

Keep one stable AuroraContract instance and stable typed token declarations for
the app. Reuse them across themes. The foundation already supplies 58 required
colors: Material semantic roles plus success, warning, and information quartets.

Use foundation roles where their meanings fit. Declare required app extensions
only for distinct app semantics, with meaningful descriptions and paired content
colors where needed. Extensions use an app namespace such as `app.ticket`, never
the reserved `colors` namespace. Adding an extension requires updating **every
variant of every registered theme**. A contract declares fields, not defaults.

Theme identity and appearance are independent: “Wicked” can have light and dark
variants. Choose an explicit unavailable-variant policy. `preferred` uses that
theme's declared preferred appearance; `reject` refuses the change without
changing current state. Never generate a missing variant during selection.

Generate an ordinary validated theme with AuroraGenerator, use AuroraStarter
with complete extension values, or author all token values. Preserve exact brand
colors through explicit overrides when requested; seeds guide palettes and do
not guarantee an exact output hex. Check the corresponding foreground colors.
Review contrast diagnostics; never claim that these checks certify the whole app.

### Runnable new-app starting point

This complete `lib/main.dart` example uses a stable registry, two named themes,
system appearance, and a theme-switching control. Adapt names, colors, and screen
content to the user's app brief; it is a starting point, not the final product.

```dart
import 'package:aurora_flutter/aurora_flutter.dart';
import 'package:flutter/material.dart';

final appContract = AuroraContract(id: 'app');

AuroraTheme makeTheme(String id, String name, String seed) =>
    AuroraGenerator.generate(AuroraGenerationRequest(
      contract: appContract,
      id: id,
      name: name,
      primary: AuroraColor.hex(seed),
    )).theme;

final appThemes = [
  makeTheme('forest', 'Forest', '#246b35'),
  makeTheme('ember', 'Ember', '#9a3412'),
];

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => AuroraEngine.managed(
        contract: appContract,
        themes: appThemes,
        initialSelection: const AuroraSelection(themeId: 'forest'),
        fallback: AuroraVariantFallback.preferred,
        builder: (context, theme) => MaterialApp(
          title: 'My app',
          theme: theme,
          home: const Home(),
        ),
      );
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Aurora.controllerOf(context);
    final selection = controller.state.selection;
    return Scaffold(
      appBar: AppBar(title: Text(controller.state.theme.name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          DropdownButton<String>(
            value: selection.themeId,
            items: controller.themes.values
                .map((theme) => DropdownMenuItem(
                    value: theme.id, child: Text(theme.name)))
                .toList(),
            onChanged: (id) {
              if (id != null) {
                controller.select(AuroraSelection(
                    themeId: id, appearance: selection.appearance));
              }
            },
          ),
          DropdownButton<AuroraAppearancePreference>(
            value: selection.appearance,
            items: AuroraAppearancePreference.values
                .map((appearance) => DropdownMenuItem(
                    value: appearance, child: Text(appearance.name)))
                .toList(),
            onChanged: (appearance) {
              if (appearance != null) {
                controller.select(AuroraSelection(
                    themeId: selection.themeId, appearance: appearance));
              }
            },
          ),
          FilledButton(onPressed: () {}, child: const Text('Continue')),
        ]),
      ),
    );
  }
}
```

For custom UI colors inside a themed descendant's build method:

```dart
final tokens = Aurora.tokensOf(context);
final background = tokens.surfaceContainer.flutterColor;
final foreground = tokens.onSurface.flutterColor;
// Custom declaration: tokens.read(AppTokens.ticketBackground).flutterColor
```

There is no global `Aurora.primary` or mutable global active theme. Snapshot reads
outside a reactive scope do not subscribe automatically. Avoid storing Flutter
token snapshots or token-derived StyleSheets once and expecting them to update.

## 4. Integrate into the app

### Existing app, whole-app migration

Wrap the existing MaterialApp/MaterialApp.router in AuroraEngine and pass the
engine-supplied ThemeData to its `theme` property. Retain the app's existing
router/navigator, localization, restoration, providers, builders, and other
settings. Do not replace the root with the demo app or recreate its router on
each theme change. Put Aurora access above the navigator so routes and root
dialogs can read the selected theme.

If an existing state layer owns selection, create AuroraController once in that
owner, inject it with `AuroraEngine(controller: ..., builder: ...)`, and dispose
it when the owner ends. Otherwise use the managed constructor above. Generate
themes outside widget build methods. Managed contract, registry, initial selection,
and fallback are fixed while mounted; change selection through the controller.
Use a new engine key only when intentionally replacing that configuration.

Migrate the old light/dark wiring into AuroraSelection. Remove competing
MaterialApp darkTheme/themeMode authority after the engine controls appearance.
Keep the selected theme ID when changing light/dark/system and keep the requested
appearance preference when changing theme identity.

Preserve typography, shapes, spacing, and component behavior through `themeBuilder`
or existing app theme factories. The callback receives `(context, variant)`;
`variant.toThemeData()` and `variant.toColorScheme()` are available. Audit concrete
colors in TextTheme and component themes too: copying the old ThemeData and only
replacing ColorScheme can leave old colors embedded in component properties.

Migrate app-owned literal colors by meaning, not by hex similarity. Typical pairs
are surface/onSurface, primary/onPrimary, and primaryContainer/onPrimaryContainer.
Success, warning, and info have their own families; secondary/tertiary are accents.
Leave content such as photos, logos, charts with fixed categorical semantics,
and user-authored colors alone when the app intentionally preserves them.
Inspect nested Theme widgets and explicit widget colors that override native
theming. Document intentional remaining exceptions.

Connect the actual app's settings/control UI, not just a demo toggle. Reuse its
storage for theme ID and appearance preference where persistence is requested
or already exists. Aurora does not persist settings itself. Validate restored
IDs/preferences and deliberately handle retired themes or unavailable variants.

### Feature-only migration

For a fixed preview, use `AuroraScope.fixed(variant: variant, child: ...)`.
It owns no controller and ignores platform brightness. Aurora token reads and
native Material widgets use that snapshot; `Aurora.controllerOf` throws within
the fixed scope, even when an outer engine has a controller. Replace the variant
to update the preview. Side-by-side light/dark previews need two fixed scopes.

Place AuroraScope around the requested subtree and retain the outer app theme.
Create/dispose the controller in that feature's owner. Read Aurora values from
descendant contexts. Nested scopes may be independent. A dialog pushed onto an
outer navigator does not inherit the page's Aurora scope: wrap that dialog with
the intended scope or use a navigator inside the scoped feature.

### New app

If the target app does not exist yet, scaffold it with `flutter create` in the
user's intended app directory, using the requested app name and platforms.
Keep an existing repository's files and structure; do not scaffold over an
existing app. Then add Aurora as described above and implement the app brief.

Use the runnable pattern above, adapted to the app brief. Establish the contract
before adding app-specific token uses. Use native themed Material widgets where
possible, and semantic Aurora tokens for custom UI. Keep palette authorship,
settings, and widgets separate using the app's existing architecture conventions.
Implement the actual requested app, not just a themed starter screen.

### Optional: textures (type, shape, motion, component defaults)

Use textures when the app's non-colour design should be user-selectable or vary
between looks: fonts, corner radii, borders, density, motion, or which component
layout is the default. Declare app texture tokens once as typed constants
(`AuroraDimensionToken`, `AuroraTypographyToken`, `AuroraEnumToken`, ...) in an
`AuroraTextureContract`; never declare colours there. Build each texture with
`AuroraTextureStarter.texture(contract:, id:, name:, values:)`, which supplies the
Material 3 foundation so you only provide app extensions and deliberate
overrides. Border and shadow colours alias theme colour tokens
(`AuroraAlias(AuroraFoundation.outlineVariant)`). Pass `textures:` to
`AuroraEngine.managed` or `AuroraController`, plus `texturePairings:` when themes
should come with a default texture; set `textureId` on a selection only when the
user picks a texture. Read values in widgets with `Aurora.textureOf(context)`
(or `maybeTextureOf` when a theme may have none) rather than hard-coded numbers.
Textures share values across light and dark. See the README section "Textures"
and the [textures example](examples/textures/lib/main.dart).

## 5. Use the agent generator when useful

For per-item branding, generate once per seed outside widget builds:

```dart
final branded = AuroraGenerator.variants(brandColor.auroraColor,
    scheme: AuroraGenerationScheme.fidelity);
final tokens = branded[AuroraAppearance.light]!.tokens;
final foreground = AuroraContrast.bestOn(tokens.primaryContainer,
    [tokens.onPrimaryContainer, AuroraColor.hex('#000000'), AuroraColor.hex('#ffffff')]);
```

These are foundation-only snapshots with their own contract; they do not enter
the app's theme registry or satisfy its required extensions. For a scoped app
feature that needs extensions, generate against the canonical app contract and
provide every extension value/rule. `bestOn` returns the candidate with highest
contrast; it does not guarantee a threshold and requires an opaque background.
`result.debugReport()` formats generation issues without logging them.

The default single-seed generation at contrast level zero matches Flutter's
`ColorScheme.fromSeed` tonal-spot values for all 46 supported Material roles on
the verified SDK. Other scheme names are `fidelity`, `vibrant`, `expressive`,
`content`, `monochrome`, `neutral`, `rainbow`, and `fruitSalad`. Supply `scheme:`
on `AuroraGenerationRequest`, or `"scheme": "fidelity"` in a recipe. Explicit
overrides and additional secondary/tertiary seeds change this comparison.
The MCU pin preserves Aurora output across upgrades; recheck equality after a
Flutter upgrade rather than assuming future SDK algorithms remain identical.

Agents should use JSON mode; opening the visual generator is optional. From the
Aurora checkout's `packages/aurora` directory, resolve dependencies once:

```sh
dart pub get
dart run aurora generate --json --input /absolute/path/to/recipe.json
```

After adding the target app's Aurora dependency, optionally install a bundle:

```sh
dart run aurora generate --json --input /absolute/path/to/recipe.json --project /absolute/path/to/app
```

The global `aurora` command is optional. Do not assume it exists or activate it
globally merely to integrate an app. The installer writes a new
`lib/aurora_themes/<id>/` folder and refuses overwrites. It does **not** register
the theme or edit app startup; finish those steps yourself. Import generated
factories with a prefix when installing several themes, since each exports
`createAuroraTheme`. Pass the app's canonical contract, and supply any extensions
absent from the generated bundle through `extensionValues` for every appearance.
Use actual resolved paths in commands and quote paths containing spaces.

Minimal recipe:

```json
{
  "schemaVersion": 1,
  "id": "forest",
  "name": "Forest",
  "primary": "#246b35",
  "appearance": "both"
}
```

For an app with extensions, declare the **entire app contract** in the recipe and
supply explicit values or rules for each extension. See
[the complete theater recipe](examples/recipes/theater.json) and
[recipe v1](spec/recipe-v1.md). Recipe declarations describe portable fields;
the returned Dart request has its own contract instance. Do not register its
theme against a separately constructed app contract even if IDs match. Use the
generated factory with the canonical contract, decode DTCG variants against that
contract, or generate directly in Dart using that contract.

Success emits one JSON object on stdout with `schemaVersion` and `theme`, plus
`installation` when requested. Failures use structured stderr and a nonzero exit
code. Check the exit code before consuming output. Contrast issues live in
`theme.contrast` and may accompany successful generation. The CLI's outer JSON
object and the theme manifest are not DTCG documents; `theme.variants.light` and
`theme.variants.dark` are individual DTCG documents. There is no manifest decoder;
use AuroraDtcg.decode per variant or the generated Dart factory.

## 6. Verify before reporting completion

Run formatting, dependency resolution, analysis, and the target app's relevant
tests from the **target app**, using its normal commands. For Flutter, typically:

```sh
dart format lib test
flutter analyze
flutter test
```

Only include existing format directories. Run the app's platform build/smoke check
where appropriate and available. If editing Aurora itself, follow its AGENTS.md
and `tools/check.ps1` in addition to app checks. Do not claim checks you did not run.

Cover behavior rather than implementation details:

- Each registered theme is complete for the canonical app contract.
- Theme and appearance changes update custom tokens and native widgets.
- System appearance changes preserve identity; missing variants follow policy.
- App-wide switching preserves navigation and page state, and reaches dialogs.
- Feature-only scopes update descendants while leaving siblings unchanged.
- Controller ownership is correct; injected controllers survive engine unmount.
- Existing settings restoration and important screens still work when applicable.

### Widget test recipe

Construct a complete registry outside the test's widget build, then exercise an
injected engine with Flutter's test platform dispatcher:

```dart
testWidgets('system selection follows brightness', (tester) async {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final controller = AuroraController(
    contract: appContract, themes: appThemes,
    initialSelection: AuroraSelection(themeId: appThemes.first.id),
    fallback: AuroraVariantFallback.reject,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(AuroraEngine(
    controller: controller,
    builder: (context, theme) => MaterialApp(theme: theme,
      home: Builder(builder: (context) => Text(Aurora.of(context).appearance.name))),
  ));
  expect(find.text('dark'), findsOneWidget);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  await tester.pumpAndSettle();
  expect(find.text('light'), findsOneWidget);
  expect(controller.state.selection.themeId, appThemes.first.id);
});
```

For same-look migrations, generate using the old seed and scheme, compare
`variant.toColorScheme()` with `ColorScheme.fromSeed(seedColor: oldSeed,
brightness: variant.appearance.brightness, dynamicSchemeVariant: oldScheme)`
role by role, and test component styling separately. A full role comparison is
in [from_seed_test.dart](packages/aurora_flutter/test/from_seed_test.dart).
Controller listeners run synchronously after successful mutations; widgets still
need a pump, and MaterialApp animations may need `pumpAndSettle`.

### State-layer and persistence recipe

At bootstrap, initialize Flutter, load stored settings, create the stable
contract/themes, restore selection, and construct the controller. Hold it in
the app's services owner and inject it into AuroraEngine. Dispose it with that
owner. The controller reads platform brightness by default; pass
`systemAppearance:` explicitly for a deterministic host override. Scopes and
engines observe subsequent device changes.

```dart
final restored = AuroraSelection.restoreJson(savedSettings,
    themes: appThemes, fallbackId: appThemes.first.id);
final controller = AuroraController(
  contract: appContract, themes: appThemes, initialSelection: restored,
  fallback: AuroraVariantFallback.preferred,
);
```

`restore` also accepts `themeId:` and a preference name. Unknown identities use
the registered fallback; unknown preferences use system. Restoration does not
resolve missing variants: choose the runtime fallback policy deliberately.
`toJson` writes `themeId` and `appearance`; `fromJson` is a strict data decoder,
while `restoreJson` tolerates retired or malformed stored fields. Aurora performs
no storage IO. Wrap AuroraSelection in an app settings state when needed; avoid
maintaining a second appearance authority.

For an existing Cubit, adapt this method to its state and storage types:

```dart
Future<void> applySelection(AuroraSelection next) async {
  services.aurora.select(next); // Rejected changes throw before saving/emitting.
  emit(state.copyWith(selection: next, saveError: null));
  try {
    await services.settings.saveSelection(next.toJson());
  } catch (error) {
    emit(state.copyWith(saveError: error)); // Keep the applied visual selection.
  }
}
```

Serialize rapid saves in the app's storage layer so an earlier write cannot
overwrite a later selection. Show save failures using the app's normal error UI.

### Concrete migration audit

Search the target app's `lib/` for `Color(0x`, `Colors.`,
`ColorScheme.fromSeed`, `themeMode`, and `darkTheme`. Review each result, plus
colors embedded in TextTheme, button, app-bar, input, card, navigation, and dialog
themes. Audit nested Theme widgets and custom painters. Convert app UI colors
by semantic role, then review remaining matches and document explicit exceptions.
User-authored stored colors (such as traveler colors), logos, and intentional
categorical chart colors can remain outside the theme as one documented policy.

Use `tokens.read(AppTokens.role)` for typed extension reads; app-owned getters
may wrap that call, without string paths in widgets. Native status colors are
available as `Theme.of(context).extension<AuroraStatusColors>()!` when using
`variant.toThemeData()`. A custom themeBuilder should include
`AuroraStatusColors.fromTokens(variant.tokens)` in its ThemeData extensions.
`Color.auroraColor` preserves ARGB, `appearance.brightness` converts to Flutter,
and `AuroraFlutterAppearance.fromBrightness` converts back. Flutter conversion
cannot be a core enum constructor because the core must remain pure Dart.

Report integration level, themes/appearances added, extension declarations,
how selection is controlled, what was verified, and material remaining limitations.
Link the app files changed. If tooling is unavailable, distinguish implemented
code from unverified behavior and state the concrete blocker.

## Focused reference map

Read these when the selected route needs them; all links are checkout-relative.

| Need | Source |
| --- | --- |
| Public API and integration patterns | [README.md](README.md) |
| Complete working Flutter app | [theater example](examples/theater/lib/main.dart) |
| Generation, overrides, rules, contrast | [generator guide](continuity/developer/generator.md) |
| CLI invocation, installer, JSON protocol | [CLI guide](continuity/user/usage.md) |
| Portable recipe fields | [recipe v1](spec/recipe-v1.md) |
| Installing a theme/texture bundle made by another tool (TokenSeed) | [bundle v1](spec/bundle-v1.md), [CLI guide](continuity/user/usage.md#install-a-bundle-from-another-tool) |
| TypeScript and React apps | [consuming from TypeScript](continuity/user/typescript.md) |
| Token interchange and supported limitations | [DTCG profile](continuity/data/dtcg-profile.md) |
| Foundation role paths and descriptions | [foundation v1](spec/foundation-v1.json) |
| Texture foundation paths and starter values | [texture foundation v1](spec/texture-foundation-v1.json) |
| Textures in a working app, recipes | [textures example](examples/textures/lib/main.dart), [texture recipe v1](spec/texture-recipe-v1.md) |
| Ownership, scope, navigation examples | [Flutter integration tests](packages/aurora_flutter/test/integration_test.dart) |

If prose and the installed source differ, inspect the public exports and current
implementation rather than inventing an API. Keep library internals out of app
imports; use the public barrels. Aurora's root AGENTS.md is for library contributors;
this onboarding file is the app-integration entry point.
