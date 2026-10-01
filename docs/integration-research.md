# Making Aurora easy to adopt

Research and proposed API direction, September 30, 2026. The APIs below are
the initial proposals. The subsequently accepted names and implementation are
AuroraTokens (direct values), AuroraScope (themed subtree), and AuroraEngine
(app-wide integration). AuroraRuntime is the portable selection runtime. Refer
to README.md for the current APIs; the original proposal names below are historical.

## Recommendation

Use Flutter's existing ThemeData/ColorScheme pipeline as the main integration
point. Existing widgets that use Theme.of(context) should continue to work.
Aurora-specific reads are useful for contract extensions, not mandatory for
every widget. Keep the existing low-level scope, add a themed subtree wrapper,
and add a root builder integration that retains the user's MaterialApp.

Current AuroraScope only provides reactive Aurora access. It does not wrap its
child in a Material Theme. The current example manually constructs MaterialApp
inside a Builder and supplies the resolved ThemeData. A root helper can package
that wiring, while a subtree helper can supply both AuroraScope and Theme.

## Proposed surfaces

### AuroraScope: low-level access

Retain its current role for apps that already own theme composition or only need
Aurora token access. Caller owns its controller. Document this distinction.

### AuroraThemeRegion: a themed subtree

Compose scope with Flutter Theme (or AnimatedTheme), accepting a caller-owned
controller and an optional theme composition callback. Standard Material widgets
and custom Aurora consumers should agree on the resolved variant. Support nesting
without changing the controller for the surrounding app.

Local route/dialog behavior needs explicit tests: showDialog generally pushes to
the root navigator and captures InheritedTheme instances, not arbitrary inherited
providers. Our current Aurora scope is an InheritedNotifier, not an InheritedTheme.
Evaluate a capturable scope or a helper that carries the region controller to
overlays. Do not promise automatic local-scope propagation or live updates in an
already-open dialog without verifying it. Nested navigators are another option.

### AuroraApp: root integration

Illustrative target usage:

```dart
AuroraApp(
  controller: controller,
  builder: (context, theme) => MaterialApp.router(
    routerConfig: router,
    theme: theme,
    // Existing localization, observers, restoration, and other settings stay here.
  ),
);
```

Internally compose scope plus reactive theme building. Place scope above the app's
navigator. Support both MaterialApp and MaterialApp.router without duplicating
their large constructor APIs. Preserve stable keys/router objects and test that
theme changes do not reset navigation or local widget state.

The generated theme has resolved brightness. Aurora should be the sole appearance
selector in this integration; do not independently toggle MaterialApp.darkTheme
and themeMode. Keep existing MaterialApp.builder composition available.

Offer a convenience constructor that owns its controller, alongside the injected
controller path. Clearly distinguish lifecycle: dispose internally created
controllers; never dispose an injected controller. Owned controller creation
should occur once, not on every build. Handling changes to configuration requires
a documented policy and tests.

Prefer this builder approach first over an AuroraMaterialApp forwarding all
MaterialApp constructor arguments. A replacement app class is superficially
shorter but couples Aurora to Flutter's routing and localization API evolution.

## Migrating an existing app

1. Import the app's existing light/dark ColorScheme roles as an initial named
   Aurora theme. Require explicit status-family and app-extension values; do not
   guess success/warning/info from unrelated Material accents. A future importer
   should copy colors from their declared color space deliberately.
2. Add the root integration while retaining the app's MaterialApp settings and
   controller/state-management architecture.
3. Compose typography, shape, density, and component settings through a theme
   builder receiving the active variant. Preserve non-color intent while reviewing
   explicit component/text colors.
4. Existing ColorScheme consumers and Material defaults participate immediately.
   Replace literal widget colors and detached local themes incrementally.
5. Add named themes only after their complete variants validate against the app
   contract. Imported themes do not bypass validation.

Important: ThemeData.copyWith(colorScheme: ...) is not a comprehensive recolor.
Flutter's implementation retains unspecified fields, including scaffoldBackgroundColor,
textTheme, and component themes. These may contain concrete old colors. A migration
adapter must define which color fields it replaces and which overrides it preserves.
Recreating a ThemeData from the new scheme and deliberately applying structural
customizations is often clearer. Avoid claiming a lossless automatic conversion
of arbitrary ThemeData.

## Flutter ThemeExtension bridge

Consider storing the active Aurora color values as a Flutter ThemeExtension, with
proper copyWith/lerp support. This lets custom Flutter widgets participate in native
theme lookup and animated transitions. It is an adapter to the complete Aurora
contract, not permission for themes to omit app extensions. Preserve unrelated
existing ThemeExtensions when composing ThemeData.

Decide whether Aurora.of reads the selected immutable variant or animated native
theme values. The current implementation returns target values immediately while
MaterialApp may animate Material colors. Do not silently mix these two semantics.
Tests must cover extension interpolation, local overrides, and overlay behavior.

## Scope of the promise

In the current color-only library, app-wide integration controls color themes and
appearance. Typography, spacing, motion, native system chrome, and Cupertino-only
apps require additional adapters or future contract types. Material Theme provides
some Cupertino inheritance, but that is not a full CupertinoApp integration.
Explicit widget colors take precedence over inherited themes; nested Theme widgets
can override the app theme. Document those normal Flutter rules prominently.

## Prioritized implementation plan

1. Root AuroraApp builder and themed region helper, with concise adoption examples.
2. Existing ColorScheme import requiring status and extension values.
3. Explicit theme composition hooks and a migration guide for concrete overrides.
4. Native ThemeExtension/animation and dialog capture behavior.
5. Agent-friendly color audit tooling for incremental migrations; suggestions must
   be reviewed by role rather than replacing every repeated hex value identically.

## Primary sources

- [Flutter theme recipe](https://docs.flutter.dev/cookbook/design/themes): app/local
  theming and precedence of widget styling over local and app themes.
- [MaterialApp.theme](https://api.flutter.dev/flutter/material/MaterialApp/theme.html):
  app-wide default theme data and appearance selection.
- [Theme](https://api.flutter.dev/flutter/material/Theme-class.html): native lookup,
  rebuilds, inherited Cupertino styling, and AnimatedTheme support.
- [MaterialApp.builder](https://api.flutter.dev/flutter/material/MaterialApp/builder.html):
  placement above Navigator/Router and requirement to retain the supplied child.
- [ThemeData.copyWith](https://api.flutter.dev/flutter/material/ThemeData/copyWith.html):
  unspecified fields retain their existing values.
- [ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html):
  custom fields and interpolation for theme changes.
- [showDialog](https://api.flutter.dev/flutter/material/showDialog.html): distinct
  dialog context, root navigator default, and captured inherited themes.
