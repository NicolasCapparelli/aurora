# Architecture

## Components and boundaries

| Component | Location | Responsibility |
| --- | --- | --- |
| Core (pure Dart) | `packages/aurora/lib` | Colors, token declarations, contract, validated variants/themes, selection runtime, DTCG codec, generator, contrast, recipe decoding. No Flutter or `dart:ui`. Barrel: `lib/aurora.dart`. |
| Tooling (IO) | `packages/aurora/bin/aurora.dart`, `lib/src/tooling/` | CLI, local HTTP server with embedded HTML UI, project installer. Deliberately **not** exported from the barrel. |
| Flutter adapter | `packages/aurora_flutter/lib` | `AuroraController` (ChangeNotifier over `AuroraRuntime`), `AuroraScope`, `AuroraEngine`, `AuroraBinding` (device brightness observer + inherited notifier), Material `ColorScheme`/`ThemeData` bridge. |
| TypeScript core | `packages/aurora_ts` (`@aurora/core`) | Port of the portable core (not tooling), including a port of the needed MCU 0.11.1 sources so generation matches Dart. No DOM/React/Node APIs. Private pnpm workspace package. [Contributor guide](typescript.md). |
| Example | `examples/theater` | Wicked/Hadestown themes with required `theater.*` extensions and an appearance selector. |
| Specs and fixtures | `spec/` | Language-neutral portable behavior and shared JSON fixtures for future ports. |
| Maintenance script | `tools/generate_foundation.py` | Generates foundation accessors, starter presets, Material mapping, and `spec/foundation-v1.json` from one table, plus the TS core's foundation, starters, Material role mapping and texture foundation (the latter from `spec/texture-foundation-v1.json`). |
| Package exporter | `tools/vendor.py` | App-owned copies of both packages with provenance/hashes and explicit verified updates; no app pubspec or runtime changes. [Installation](../user/installation.md). |

## Representative flows

- **Authoring a theme:** declare `AuroraColorToken`s, then `AuroraContract` (adds the 58 foundation tokens; rejects duplicates, `colors.` namespace use, and path/group collisions), then `AuroraThemeVariant` (every token required and an `AuroraColor`; all issues collected into one `AuroraValidationException`), then `AuroraTheme` (same contract instance, unique appearances, preferred appearance must exist). Variants may come from `AuroraStarter.variant`, `AuroraDtcg.decode`, or `AuroraGenerator`.
- **Selection:** `AuroraRuntime` resolves `AuroraSelection(themeId, appearance preference)` plus the host-supplied system appearance to a variant, applying `AuroraVariantFallback` (`reject` throws, `preferred` uses the theme's preferred variant). Resolution happens before commit, so rejected selections or system changes leave state intact. Changes go to a broadcast stream.
- **Flutter:** `AuroraController` wraps a runtime, reads initial platform brightness unless explicitly supplied, and synchronously notifies accepted state changes. `AuroraBinding` observes subsequent brightness and exposes the controller through an inherited notifier. `AuroraScope.fixed` instead exposes a variant snapshot with no controller/device subscription. `AuroraScope` wraps descendants in a `Theme`; `AuroraEngine` hands ThemeData to the app builder. Lookups use the nearest inherited scope; controller lookup within a fixed scope throws. The native bridge includes interpolated `AuroraStatusColors` from existing status tokens; conversions live in the adapter.
- **Generation:** recipe JSON (CLI/agents) goes through `AuroraRecipe.decode`, `AuroraGenerationRequest`, and `AuroraGenerator.generate` to themes plus contrast checks, then `toJson` gives a manifest with DTCG variants. The optional installer writes `lib/aurora_themes/<id>/`. The browser UI posts foundation-only inputs through `generateToolTheme`.

## Constraints and reasoning

Sources: [AGENTS.md invariants](../../AGENTS.md), [design notes](../decisions/design-notes.md).

- The core stays Flutter-free so ports share behavior; the TypeScript core (`packages/aurora_ts`) is that port and is held to the same `spec/fixtures`. Adapters own subscription, native theme mapping, and device access.
- Direct tokens are immutable snapshots; there is no global active theme.
- Controller ownership: the engine owns a controller only in `AuroraEngine.managed`; injected controllers are never disposed by the engine; managed configuration changes throw `FlutterError` and need a new engine key; theme changes do not reset navigation (covered by tests).
- Contract completeness and foundation immutability are enforced at construction/import time rather than by generated constructors (design notes record code generation as an open question).
- Theme identity is separate from appearance; missing variants are never generated implicitly.
- Invalid data is rejected rather than repaired; explicit overrides in generation are never silently changed (contrast problems are reported, not fixed).
- Installer safety (source-observed): the target is chosen by the CLI user, never by a web request; symlinked or non-directory output parents and existing theme directories are refused; the bundle is staged in a temp dir and then renamed.
- Local server safety (source-observed): loopback only, Host check, per-run token header on POST, nonce CSP, 64 KiB request cap, generation cache bounded at 16.

### Generator and contrast

Algorithm id `aurora-tonal-v1-mcu-0.11.1` (SchemeTonalSpot from `material_color_utilities` 0.11.1; secondary/tertiary seeds replace those palettes; status palettes come from separate seeds). Precedence: generated foundation, then shared `values`, then per-appearance `variantValues`. `rules` (alias or tone) fill only unresolved app tokens. Cycles and unresolved tokens fail with no partial theme. Contrast is evaluated on documented foreground/background pairs only (`AuroraContrast.foundationPairs` plus recipe pairs); translucent backgrounds yield `unknown`. Normative detail: [generator guide](generator.md), [generation spec](../../spec/generation-v1.md).

## Documentation ownership

After the 2026-09-30 migration, ordinary docs live in Continuity:

- [design-notes](../decisions/design-notes.md) (vocabulary, decisions; dated 2026-09-30), [integration-research](../history/integration-research.md) (historical proposal; its original API names are superseded), [dtcg-profile](../data/dtcg-profile.md), [generator](generator.md), [CLI usage](../user/usage.md).
- Retained outside Continuity as required entry points/exceptions: root [README.md](../../README.md) (public API walkthrough), [AGENT_ONBOARDING.md](../../AGENT_ONBOARDING.md) (playbook that user-facing prompts name by path), [AGENTS.md](../../AGENTS.md) (contributor rules), and `spec/`: [spec/README.md](../../spec/README.md), [generation-v1](../../spec/generation-v1.md), [recipe-v1](../../spec/recipe-v1.md), and fixtures. `spec/` is the language-neutral portable contract with checked-in fixtures consumed by tests and tools at fixed relative paths, so it was kept intact as a standalone artifact rather than split. No source/spec mismatch was identified; the only check was that the fixture-driven tests pass.
