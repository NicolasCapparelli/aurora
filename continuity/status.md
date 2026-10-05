# Status

## Current state

- All packages and both examples (theater, textures) are present and, per the last check run, format-clean, analyzer-clean, and passing tests (see Last verified state). Nothing is known to be broken.
- Core (`packages/aurora`): contracts, themes, runtime, DTCG, generator, recipe, CLI, and tooling are implemented in source and exercised by tests.
- Adapter (`packages/aurora_flutter`): controller, scope, engine, Material bridge implemented and exercised by widget tests.
- App-owned package distribution is implemented by `tools/vendor.py`; installation/onboarding use committed in-app snapshots. See [installation](user/installation.md).
- Not exercised in this session: `flutter build web`, `flutter run`, browser UI in a real browser, theme installer against a real app. CLI and theme installer run against temporary projects in tests.
- Themes are colour-only. Textures (non-colour tokens: type, shape, motion, lines, density, chrome, component defaults) are implemented and merged into `main`: core token hierarchy, texture contract/foundation/starter, validation and aliases, runtime selection, texture DTCG, texture recipes, theme-to-texture pairings, portable fixtures, Flutter bridge, `examples/textures`. Persistence, resolver packaging and contract codegen remain unimplemented ([design notes](decisions/design-notes.md)).
- React Native adapter (`packages/aurora_react_native`, `@aurora/react-native`), the `tools/vendor.py --react-native` export mode and `examples/react_native` are implemented and merged into `main` (see Active work).
- TypeScript core (`packages/aurora_ts`, `@aurora/core`) is implemented on branch `feat/typescript-port` and passes every `spec/fixtures` file unchanged, including generation and scheme fixtures (Dart MCU 0.11.1 ported into the package). See [TypeScript guide](developer/typescript.md).

## Active work and last stopping point

- **React Native support for Primer (2026-10-05), implemented, verified and merged into `main` at the owner's request.** Requested by the owner for Primer (Expo/React Native). Delivered: self-contained `@aurora/react-native` (controller, provider and fixed scope with no host view, hooks, `Appearance`, explicit native conversions with strict unsupported reporting), `tools/vendor.py --react-native` with regression tests, `examples/react_native`, docs and the [Primer native handoff](agent/primer-native-handoff.md). `@aurora/core` and `@aurora/react` are unchanged. Decision: [design notes](decisions/design-notes.md#react-native-adapter-decided-2026-10-05). Next: Primer's agent exports from `main` and integrates. Primer was not edited. Open: the exporter refuses destinations inside the Aurora checkout, so the example's git-ignored `vendor/` is exported through a scratch app (see its README).

- **TypeScript port and TokenSeed pipeline (2026-10-05), complete, merged into `main` at the owner's request (2026-10-05).** Requested by the owner for TokenSeed (a React app that themes its own UI with Aurora and exports Aurora themes/textures for Flutter apps). Delivered: `@aurora/core` (`packages/aurora_ts`, with Dart MCU 0.11.1 ported in), `@aurora/react` (`packages/aurora_react`), `tools/vendor.py --typescript`, `spec/bundle-v1.md` with `AuroraBundle` in Dart and TypeScript and shared fixtures, `aurora install --bundle` for Flutter apps, the [producer mapping guide](user/bundle-producers.md) and the [TypeScript consuming guide](user/typescript.md), linked from `AGENT_ONBOARDING.md`. Decisions: [design notes](decisions/design-notes.md#typescript-port-and-the-tokenseed-pipeline-decided-2026-10-05). Next: TokenSeed's agent runs the export into TokenSeed and writes its exporter from the mapping guide. TokenSeed was not edited from here. Decided by the owner: the profiles stay strict. The brief said extra producer tokens are "ignored", but undeclared tokens are rejected, so producers must leave them out; accepting and dropping them would be a profile change.

- **AuroraTextures (2026-10-04), merged into `main`.** Implements Trace's handoff `trace/docs/handoffs/aurora-style-tokens.md` as reshaped by the owner: non-colour tokens are a separate texture layer ("AuroraTextures") with a foundation plus extensions, shared across light/dark, and optional runtime-changeable theme-to-texture pairings. Themes, generator, theme recipes and colour fixtures are unchanged. See [design notes](decisions/design-notes.md#textures-non-colour-tokens-decided-2026-10-04). Next: Trace task U3 re-vendors (`tools/vendor.py --project <trace> --replace`) and moves Trace's style packs onto textures, using pairings for Atlas, Fieldnotes and Classic. Trace has not been edited. API summary and the Trace StylePack mapping: [trace-textures-handoff](agent/trace-textures-handoff.md).

- **No active Aurora work. Trace migration is handed off.** Package vendoring, documentation, tests, and the prompt are included in this commit at the user's request. Trace has not been edited. See [Trace migration prompt](agent/trace-vendoring-prompt.md).
- Investigation confirmed Trace's pubspec, lockfile, and resolved package configuration point to the sibling Aurora checkout. Aurora's former onboarding instructed that integration. The new exporter copies both packages without caches, preserves internal sibling paths, records revision/dirty state/versions/SHA-256, and refuses overwrite or modified snapshots unless an unchanged managed export is explicitly replaced. No runtime APIs changed.
- Implemented: controller-free fixed scopes; foundation-only per-seed snapshots; nine pinned generation schemes in Dart, recipes, and browser UI; synchronous Flutter notifications and initial platform brightness; selection JSON/restoration; Flutter conversions; contract getter; readable foreground and diagnostic report helpers; generated native status colors; installer registration snippets; onboarding recipes. Typed app-token reads already existed and are clarified rather than replaced with contract codegen.
- The prior integration-feedback commit includes the `docs/` migration into Continuity alongside implementation, tests, new scheme fixtures, and affected documentation. Original generation fixtures and required foundation roles are unchanged. That earlier task left no intended uncommitted work; the package-vendoring changes described above are new.

## Next steps and context

Requested downstream work: the agent in Trace implements the [migration prompt](agent/trace-vendoring-prompt.md) and verifies that app. No further Aurora task established. Optional candidates (not selected): see "Next milestones" in [README](../README.md) and "Next design questions" in [design notes](decisions/design-notes.md). Start from the [agent map](agent/map.md).

## Blockers and open questions

- None blocking. Migration is complete with exceptions: root README, AGENT_ONBOARDING.md, AGENTS.md, and `spec/` intentionally stay in place (see [architecture](developer/architecture.md#documentation-ownership)). Whether `spec/` should also move is the user's call; it was kept because fixtures/tools use fixed paths.
- Unknown (future-work only): intended foundation versioning policy when adding tokens ([AGENTS.md](../AGENTS.md) says it needs a decision).

## Last verified state

2026-10-05, `feat/react-native` as committed (base `58dc00c`):

- `./tools/check.ps1`: exit 0 after the documentation updates. 17 Python exporter tests (the earlier 11 plus 6 React Native mode); `@aurora/core` 97, `@aurora/react` 11 and `@aurora/react-native` 40 tests; Dart and Flutter unchanged and passing. No fixtures changed.
- `examples/react_native` (Expo ~57.0.26, React 19.2.3, React Native 0.86.3, TypeScript 6.0.3) consumed a `--react-native` snapshot through npm `file:` dependencies; `npm ls` showed one `@aurora/core` and one `react`. `npx tsc --noEmit` passed. With `skipLibCheck: false` the only error was Expo's own missing `@react-native/assets-registry` types.
- `npx expo export --platform android` produced Hermes bytecode (611 modules). In a non-minified bundle, the 34 Aurora and app modules contain no `window`, `matchMedia`, `reportError`, `process.env`, `Buffer` or `fs`. `document` appears only as a local name in core's DTCG decoder and in comments. Single copies of core, the controller and React.
- Android 34 emulator (x86_64, AVD `aurora_smoke`), release build through `expo prebuild` and Gradle: the app ran on Hermes with no JS or runtime errors. `adb shell cmd uimode night yes/no` and the in-app theme and appearance buttons changed the variant with the mount counter staying at 1. A screenshot showed the fixed dark canvas inside light chrome.
- iOS was not built or run (Windows host). jsdom tests cover adapter behavior only; native compatibility rests on the Metro/Hermes bundle and the emulator run.

2026-10-05, `feat/typescript-port` as committed:

- `./tools/check.ps1`: exit 0, in the working tree and again in a fresh clone of the branch (no `node_modules` or `dist`). 11 Python exporter tests (7 Dart-mode, 4 TypeScript-mode); TypeScript install, build, typecheck and tests (97 `@aurora/core`, 11 `@aurora/react`); Dart/Flutter formatting and analysis; 148 core tests (the previous 122 unchanged plus 24 bundle conformance and 2 bundle install tests), 30 Flutter adapter tests and 4 textures-example tests.
- Every `spec/fixtures` file passes unchanged in TypeScript, including `generation-v1.json` and `generation-schemes-v1.json`. Existing fixtures, `spec/foundation-v1.json` and `spec/texture-foundation-v1.json` are untouched; `generate_foundation.py` reproduces the Dart outputs byte for byte. New fixtures: `bundle.json` (created with `tool/export_bundle_fixture.dart`) and hand-written `bundle-cases.json`; TypeScript `AuroraBundle.encode` reproduces `bundle.json` exactly.
- `vendor.py --typescript` was run against a scratch pnpm app outside the checkout: `file:` dependencies install, the app typechecks with `skipLibCheck: false`, app-built contracts render through `AuroraProvider` server-side, and the adapter resolves the app's single `@aurora/core`. Not tested in a browser or a Vite build; jsdom covers the React adapter.
- `aurora install --bundle` installed the fixture bundle into temporary Dart projects; the generated snippet compiled and ran with app extensions, the texture and the pairing, and an invalid bundle exited 65 without writing. In a scratch Flutter app depending only on a vendored `aurora_flutter`, `dart run aurora install --bundle ... --project .` installed the fixture, a second install was refused, and `flutter analyze` passed on a `main.dart` registering the theme, texture and pairing with `AuroraEngine.managed`. The app was not built or run.
- 242 relative documentation links and anchors resolved. One spec text fix: `texture-recipe-v1.md` said `kind: "style"`; the code and fixture use `"texture"`.

2026-10-04, AuroraTextures as committed and merged into `main`:

- `./tools/check.ps1`: exit 0; 7 Python exporter tests, formatting and analysis for core, adapter, theater and the textures example; 122 core tests, 30 Flutter adapter tests and 4 textures-example tests pass. Baseline before the change was 73 core and 22 adapter tests, all still passing unchanged.
- Generation fixtures, `spec/foundation-v1.json` and existing portable fixtures untouched. New texture fixtures were created with `tool/export_texture_fixture.dart` (texture.tokens.json, texture-foundation-v1.json); `texture-cases.json` and `texture-recipe.json` are hand-written.
- `flutter build web` for the example (before the rename to textures) succeeded and the page was checked in a browser: switching Soft to Editorial changes corners, border dash style, layout and chip shapes. Named fonts (Nunito, Georgia) are not bundled, so the web build falls back to Roboto; widget tests check the requested families. Not rebuilt for web after the rename and pairing changes; widget tests cover them.
- A scratch copy of Trace's current tree re-vendored from this code analyzes clean and passes all 484 Trace tests, the same as on Trace's existing snapshot. Trace itself was not modified, vendored or built.

2026-10-01, package-vendoring implementation included in this commit:

- Final `./tools/check.ps1`: exit 0; 7 Python exporter tests (including Windows junction rejection), formatting/analysis, 73 core tests, and 22 Flutter tests pass; theater analyzed.
- Exporter tests cover source removal, sibling dependency retention/cache exclusion, explicit updates, local edits/extra files, unmanaged/escaping destinations, invalid manifests/missing source, symlink/junction rejection, and rollback after failed installation. Export directories inherit the app's permissions, verified by a consumer running under a different Windows account.
- Separate Flutter consumer outside the Aurora checkout (no sibling source directory) resolves both packages from its own vendor snapshot and passes `flutter pub get`, `flutter analyze`, and a Flutter smoke test exercising generation and Material mapping for both appearances. Fresh package configuration points to `../vendor/aurora/aurora` and `../vendor/aurora/aurora_flutter` relative to `.dart_tool`. This verifies the package export, not Trace's integration or a platform app build.
- No Trace files changed and no Trace tests/builds run. No demo web integration changes or web build. Implementation verification predates the final commit-status-only documentation update; implementation is unchanged.
- Implementation/docs/handoff diff reviewed; `git diff --check` passed. All 171 relative documentation links/anchors in 17 documents resolved after the handoff documentation updates.

2026-10-01, implementation included in this handoff commit:

- `./tools/check.ps1`: exit 0; dependencies resolved, formatting and analysis passed for core, adapter, and theater; 73 core tests and 22 Flutter tests passed.
- Flutter same-look regression compares all 46 supported Material roles for three seeds, nine schemes, and both appearances. Default portable generation fixtures pass unchanged. New versioned scheme fixtures are read by normal tests; only their explicit maintenance export was run to create them.
- Installer tests compile/execute the returned registration snippet in a temporary project and preserve required-extension rejection. Controller and fixed-scope widget regressions pass.
- Foundation sources regenerated from `tools/generate_foundation.py` and formatted. No foundation token/version change. No demo web integration edits, so web build was not run.
- Browser UI source/server inputs changed and server/generation tests passed; visual browser interaction was not exercised. Trace was not modified or re-tested; this request changed Aurora.
- Commit/handoff review: relevant implementation and staged diffs reviewed; whitespace checks passed; all 159 relative documentation paths/anchors in 19 documents resolved after the final Continuity updates.

Earlier verification history:

Date 2026-09-30, base commit `0e782d2` with only untracked `continuity/` and documentation edits (no source changes):

- `./tools/check.ps1` from the root: exit 0 (pub get, format check, analyze, tests in all three projects).
- Core `dart test` in `packages/aurora`: 59 tests passed. Flutter `flutter test` in `packages/aurora_flutter`: 17 tests passed. `examples/theater` has no `test/` dir; analyzed only.
- Not run: `flutter build web` (examples/theater), `flutter run -d chrome`, `dart run aurora generate` (browser/server), `python tools/generate_foundation.py`, `dart run tool/export_*_fixture.dart` (these refresh checked-in fixtures; do not run casually).
- After the documentation migration (docs moved, links repaired), `./tools/check.ps1` was re-run: exit 0. A script confirmed all relative links/anchors in Continuity, `AGENTS.md`, `README.md`, `AGENT_ONBOARDING.md`, and the two edited spec files resolve. The only remaining mention of `continuity/migrate.md` is generic explanatory text in `about.md`.
- Counts are as observed; no historical count was compared.

## Last meaningful update

2026-10-05 — TypeScript port, React adapter, TypeScript vendoring, portable bundles and the Flutter bundle installer completed and merged into `main` at the owner's request. No active Aurora work; TokenSeed integration is handed off with the [TokenSeed integration prompt](agent/tokenseed-integration-prompt.md).

2026-10-04 — AuroraTextures (non-colour token layer with optional theme pairings) implemented with tests, fixtures, example and docs; committed on `feat/textures` and merged into `main` at the owner's request.

2026-10-01 — App-owned package snapshots replace external-checkout installation guidance; exporter, integrity checks, regression tests, and Trace migration prompt included in this commit at the user's request. No further Aurora task established.

2026-10-01 — Integration-feedback implementation and Continuity migration committed at the user's request; repository checks passed on the implementation before the final status-only documentation update.
