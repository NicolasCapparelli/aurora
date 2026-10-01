# Aurora CLI

The `aurora` package includes an executable. From `packages/aurora`:

```powershell
dart pub get
dart run aurora generate
```

For the short command, activate the local package once:

```powershell
dart pub global activate --source path C:\path\to\aurora\packages\aurora
aurora generate
```

The directory reported by Dart for global executables must be on PATH. The
packages are not published yet; use path activation rather than a hosted install.

`aurora generate` starts a loopback-only Dart HTTP server on an automatically
assigned port and opens your default browser. The UI is plain HTML, CSS, and
JavaScript packaged with the executable: no Flutter build, frontend dependencies,
CDN, or external service. If browser launch fails, open the printed URL yourself.
The server runs until you stop the terminal process with Ctrl+C; closing the tab
does not stop it. Files are written only when Add to project is clicked, and only
under the project selected at launch.

```powershell
aurora generate --no-open
aurora generate --port 8080
aurora --help
```

Pick colors visually using the native color pickers, or enter exact six-digit hex
values. Auto clears an optional seed so the generator supplies its default.
Enter a theme name and ID, a primary seed, and optional secondary,
tertiary, or status seeds. Choose both appearances or just one, then Generate.
Choose a scheme (default tonalSpot) to control brand palette style; status
palettes remain independent. The same names are accepted by recipes and Dart.
The page shows illustrative components, all 58 tokens with descriptions, and
contrast diagnostics. Edits take effect when you generate again; exports always
contain the last successfully generated result.

Downloads use your browser's usual save behavior:

- **Theme JSON:** the Aurora manifest containing metadata, variants, and diagnostics.
- **Light/dark tokens:** an individual DTCG document importable with `AuroraDtcg.decode`.

This first UI generates the foundation contract (`aurora-foundation`, version 1).
It does not infer or import your app's required extensions. Use the Dart generator
API for app contracts, extension rules, and token overrides. A foundation-only
download will fail validation if imported against a contract requiring extensions.
The component preview illustrates color usage; it is not a native Flutter preview.

## Add to project

First [install the packages as an app-owned snapshot](installation.md).
This command installs theme data only; it does not copy Aurora packages or
change dependencies.

```powershell
aurora generate --project C:\path\to\my_app
```

The target must contain a pubspec with an `aurora` or `aurora_flutter` dependency.
The UI shows the selected target. Generate a theme, then click Add to project.
The server writes the **generated preview**, not unsaved edits, to a new folder:

```text
lib/aurora_themes/<theme-id>/
  theme.dart
  theme.json
  recipe.json
  light.tokens.json
  dark.tokens.json
  README.md
```

Only requested variants are included. Existing destinations are never overwritten;
choose a new theme ID instead. Output parents must not be symlinks or files.
The folder is prepared before installation so incomplete bundles are not exposed.

Import `theme.dart` and register `createAuroraTheme(contract: yourContract)` with
your runtime/controller. The factory binds values to your existing typed contract.
Supply required app fields using its per-appearance `extensionValues` parameter;
missing extensions still fail validation. The tool installs the bundle without
editing routing, app startup, dependencies, or your existing theme registry.
The installed README includes a registration snippet for `lib/main.dart`, and
installation JSON includes `registrationSnippet`. Adjust its import location,
canonical contract variable, and registry. This is a manual startup step and
does not change an already-mounted managed engine's registry.

## Agent interface

```powershell
aurora generate --json --input recipe.json
Get-Content -Raw recipe.json | aurora generate --json --input -
aurora generate --json --input recipe.json --project C:\path\to\my_app
```

JSON mode starts no browser or server. Success emits exactly one JSON object on
stdout: `{ "schemaVersion": 1, "theme": <Aurora manifest> }`. With `--project`,
the same safe installer runs and an `installation` object lists its directory,
files, and next step. Without `--project`, the command writes no files.

Errors emit `{ "error": { "code": ..., "message": ... } }` on stderr, leave
stdout empty, and exit nonzero. Exit codes: 64 for malformed input/usage, 65 for
invalid arguments or contract validation, 74 for filesystem failures. Validation
errors also include `issues`. Contrast warnings remain successful output within
the manifest's `contrast` array; no overrides are silently repaired.

Recipes support full app contracts, alias/tone rules, shared/per-variant values,
appearance selection, and custom contrast pairs. See
[recipe v1](../../spec/recipe-v1.md) and [the theater recipe](../../examples/recipes/theater.json).
The pure Dart `AuroraRecipe.decode` API supports the same data without a CLI.

The local HTTP endpoint is an internal UI transport, not a stable public agent API.
The server and page live in `lib/src/tooling` and are not exported by `aurora.dart`.
The core generator remains independent of networking, browser, and filesystem code.
