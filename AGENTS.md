# Working on Aurora

This file is for Aurora library contributors. `AGENT_ONBOARDING.md` is the
entry point for agents integrating Aurora into a user's app. Keep its examples
and instructions aligned with public API changes.

Read `README.md`, `continuity/decisions/design-notes.md`, and `continuity/data/dtcg-profile.md` before changing
public APIs. The accepted vocabulary is contract, foundation, contract extension,
token, role, value, theme, theme variant, appearance, and theme selection.
Integration levels are AuroraTokens, AuroraScope, and AuroraEngine. The pure Dart
selection runtime is AuroraRuntime. Read `spec/README.md` for portability rules.

## Invariants

- `packages/aurora` stays pure Dart; no Flutter or `dart:ui` imports.
- Direct tokens are immutable snapshots, with no global active theme. Flutter
  subscription, native ThemeData mapping, and device access belong in the adapter.
- A scope themes its descendants; an engine owns or borrows a controller according
  to its constructor. Do not dispose an injected controller or reset navigation
  on theme changes. Managed configuration changes require a new engine key.
- Every variant satisfies the entire immutable app contract, including extensions.
- App extensions cannot remove or redefine foundational tokens.
- Reject incomplete/invalid data; rejected selections preserve current state.
- Theme identity is separate from appearance. Missing variant behavior is explicit.
- Keep token meanings documented and use typed declarations rather than string
  lookups in widget code.
- Generated files come from `tools/generate_foundation.py`. Edit the table, then
  regenerate and format. Required foundation additions need a versioning decision.
  The same table generates `spec/foundation-v1.json`. Shared JSON fixtures in
  `spec/fixtures` must remain usable by future ports; do not regenerate expected
  fixtures during normal tests.
- DTCG support is the documented profile; reject unsupported syntax explicitly.

## Verification

Run `./tools/check.ps1` from the root. It runs the Python exporter tests; installs,
builds, typechecks and tests the TypeScript packages through `corepack pnpm`;
resolves Dart dependencies, checks formatting, analyzes the packages and examples,
and runs Dart and Flutter tests. The TypeScript core (`packages/aurora_ts`) must keep
passing every `spec/fixtures` file; behavior changes land in both languages. Run
`flutter build web` in `examples/theater` when changing demo web integration.
Tests should protect behavioral invariants and the public contract.

The seed-based generator lives in the pure Dart core; read `continuity/developer/generator.md`
and `spec/generation-v1.md` when changing it. The Python maintenance script only
generates accessor/mapping source. Preserve app-extension completeness: require
values or declared generation rules. Explicit overrides must not be silently
repaired. Algorithm/dependency changes need a reviewed version and fixture update.
The CLI and browser UI live in `packages/aurora/bin` and `lib/src/tooling`.
Keep their IO imports out of the portable `aurora.dart` barrel. Read `continuity/user/usage.md`
when changing the tool. The agent CLI uses portable `AuroraRecipe.decode`;
read `spec/recipe-v1.md` before changing its input contract. Project installation
must preserve existing files and keep required app-extension validation intact.

## Continuity

Before project work, read the project-root `continuity/agent/instructions.md`, `continuity/status.md`, and complete `continuity/agent/map.md`; reuse unchanged loaded context and follow relevant routes into source. Before every otherwise-authorized commit and every handoff, review changes, update affected Continuity documentation alongside implementation, and review status and changed links. Unaffected documents need no ceremonial edit. Follow all applicable repository instructions.
