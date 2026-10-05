# TypeScript packages (contributor guide)

The TypeScript port lives beside the Dart packages in a pnpm workspace at the
repository root. Both packages are private (`"private": true`, the counterpart
of Dart's `publish_to: none`) and reach apps as vendored snapshots (see
[consuming from TypeScript](../user/typescript.md)).

| Package | Location | Counterpart |
| --- | --- | --- |
| `@aurora/core` | `packages/aurora_ts` | `packages/aurora/lib/src` except `tooling/` |
| `@aurora/react` | `packages/aurora_react` | `packages/aurora_flutter` controller, scope and engine (no Material bridge) |
| `@aurora/react-native` | `packages/aurora_react_native` | Same as `@aurora/react`, over React Native `Appearance`, with native style conversions in `src/native.ts` |

`@aurora/react-native` deliberately duplicates the small controller and store
code from `@aurora/react` instead of sharing it, so native apps never install the
browser adapter (see [design notes](../decisions/design-notes.md#react-native-adapter-decided-2026-10-05)).
A behavior change to one controller or provider must be mirrored in the other, with
matching tests. Its tests run in Vitest with jsdom and alias `react-native` to
`test/react-native-mock.ts`. They prove behavior, not native compatibility, which
comes from the Metro/Hermes bundle and the device run of `examples/react_native`.
The package pins React 19.2.3 and React Native 0.86.3 as devDependencies (the
browser adapter keeps its own React). `src` must not touch DOM, Node or browser
globals. Check that by searching `dist` for `window`, `document`, `matchMedia`,
`reportError`, `process` and `Buffer`.

## Toolchain

- Node LTS (22 or newer; observed 24.13.1), pnpm pinned by `packageManager` in the
  root `package.json` (10.28.0, the version TokenSeed uses) and always invoked as
  `corepack pnpm`. A bare `pnpm` is not assumed on PATH and package scripts never
  call it.
- TypeScript ~5.9 in strict mode with `noUncheckedIndexedAccess` and
  `exactOptionalPropertyTypes`, ESM (`module`/`moduleResolution` `NodeNext`), Vitest 3.
- `tsconfig.base.json` sets `types: []` and `lib: ["ES2022"]`, so core sources
  cannot use DOM or Node APIs; each package's `tsconfig.json` adds test-only types.
- `onlyBuiltDependencies` in `pnpm-workspace.yaml` allows esbuild's install
  script, so installs never prompt.

`tools/check.ps1` runs `corepack pnpm install --frozen-lockfile`, then `-r run
typecheck`, `-r run test` and `-r run build`. Commit `pnpm-lock.yaml` with any
dependency change.

## Core layout

`src/` mirrors the Dart files with camelCase names (`textureCodec.ts`,
`textureDtcg.ts`, `textureRecipe.ts`, `textureFoundation.ts`). `src/index.ts` is
the only public entry point; `textureCodec.ts` stays internal, as in Dart.

Generated files (do not edit): `foundation.ts`, `starters.ts`,
`materialRoles.ts` and `textureFoundation.ts`, all written by
`python tools/generate_foundation.py`. The colour foundation comes from the
script's table, like the Dart output. The texture foundation comes from
`spec/texture-foundation-v1.json`, which the Dart texture foundation exports with
`tool/export_texture_fixture.dart`; the script maps paths to the Dart accessor
names (for example `type.family.brand` to `brandFamily`). So the chain for
textures is Dart source, then the spec JSON, then TypeScript. Tests check that both
generated foundations match the spec JSON in order, types, descriptions and
starter values.

## Porting rules that decide parity

- **Identity.** Contracts, tokens and texture contracts are compared by object
  identity, like Dart's `identical`. Value classes are compared with `equals`.
  Kinds are discriminated by a `kind` field (`isKind`, `isAuroraColor`,
  `isAlias`, `isLiteral`), not `instanceof`, so a second module instance does
  not change type checks. It would still break identity, which is why
  `@aurora/react` takes `@aurora/core` as a peer dependency.
- **Errors.** `AuroraValidationError` (with `issues`), `AuroraFormatError`,
  `AuroraArgumentError` and `AuroraStateError` match Dart's
  `AuroraValidationException`, `FormatException`, `ArgumentError` and
  `StateError`. Each has a `category`. Messages may differ; categories may not.
  Check order follows Dart: DTCG decode reports missing and undeclared tokens as
  one validation error before decoding any value; a colour alias cycle is a
  format error but a texture alias cycle is a validation error.
- **Durations** are `AuroraDuration` with integer microseconds, rounded half away
  from zero, so `microseconds / 1000` encodes exactly as Dart's
  `inMicroseconds / 1000`.
- **Numbers.** JSON has no int/double distinction in TypeScript. Contract
  versions and font weights require integers. A JSON `1.0` is an integer in
  TypeScript, while Dart's `jsonDecode` yields a double and rejects it; avoid
  writing `1.0` where an integer is required.
- **Runtime stream.** `AuroraRuntime.listen` and `changes()` deliver accepted
  changes asynchronously (microtasks), in order, like the Dart broadcast stream.
  Adapters that need synchronous notification wrap the runtime, as the Flutter
  and React controllers do.

## Generator parity (MCU 0.11.1)

`spec/generation-v1.md` pins `aurora-*-v1-mcu-0.11.1`. No published npm
`@material/material-color-utilities` reproduces it: 0.3.0 differs on the
on-container tones (light tone 30 instead of 10) and on fidelity/content
containers, 0.4.0 does not import under Node ESM, and 0.2.x lacks the fixed roles.
So `src/mcu/` is a line-by-line port of the needed Dart 0.11.1 sources (HCT, CAM16,
the HCT solver, tonal palettes, contrast, dynamic colors, dislike analysis,
temperature cache and the nine schemes), with the Apache-2.0 license in
`LICENSE-material-color-utilities` and attribution in `NOTICE.md`.

Dart semantics reproduced explicitly: `dartRound` (half away from zero),
`dartMod` (Euclidean `%`), unsigned ARGB (`>>> 0`), `pow(x, 1/3)` rather than
`cbrt`, and the Dart `TemperatureCache` map keyed by Hct equality (ARGB). Every
generation and scheme fixture passes unchanged. Do not update `src/mcu` from a
newer MCU; an algorithm change needs a new version id and reviewed fixtures, as
in Dart.
