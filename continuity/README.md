# Aurora

Aurora is a theme engine with one complete app contract, many named themes, and explicit light/dark variants. The first implementation is a pure Dart core plus a Flutter/Material adapter. A TypeScript port of the core (`packages/aurora_ts`) follows the same `spec/` fixtures; the core and `spec/` stay framework-free so ports can share behavior.

## Purpose and audience

- **App developers** define a typed token contract once (Aurora's 58 foundation color tokens plus app extensions), supply complete variants, and select a theme and appearance at runtime.
- **Coding agents** integrate Aurora into a user's app by following the root [AGENT_ONBOARDING.md](../AGENT_ONBOARDING.md).
- **Theme authors** generate complete light/dark themes from seed colors with the `aurora generate` CLI or browser tool.
- **Library contributors** (including agents) start with [AGENTS.md](../AGENTS.md) and the Continuity documents here.

## Scope and maturity

Implemented (source-observed; checks in [status](status.md)): immutable colors, contracts, validated variants, pure Dart selection runtime, DTCG color import/export, deterministic seed-based generator with contrast diagnostics, recipe decoding, CLI and local browser UI, project installer, Flutter controller/scope/engine and Material bridge, and a theater example app. Packages are local (`publish_to: none`, version 0.1.0). Color tokens only. Planned items are listed under "Next milestones" in the root [README](../README.md) and [design notes](decisions/design-notes.md) and are not implemented.

## Find what you need

| Task | Start here |
| --- | --- |
| Understand this documentation framework | [What is Continuity?](about.md) |
| Install, build, run, or test | [Setup](developer/setup.md) |
| Use the CLI / theme generator | [CLI guide](user/usage.md) |
| Integrate Aurora into an app | [Root README](../README.md), [agent onboarding](../AGENT_ONBOARDING.md) |
| Use Aurora from TypeScript | [Consuming from TypeScript](user/typescript.md) |
| Understand components and flows | [Architecture](developer/architecture.md) |
| Understand data and schema ownership | [Data model](data/model.md) |
| Resume work after an absence | [Status](status.md) |
| Locate implementation context | [Agent map](agent/map.md) |
| Work as an agent | [Reading and maintenance contract](agent/instructions.md) |
| Accepted vocabulary and design decisions | [Design notes](decisions/design-notes.md) |

Also: [generator guide](developer/generator.md), [DTCG profile](data/dtcg-profile.md), [integration research (historical)](history/integration-research.md). Root README, AGENT_ONBOARDING, AGENTS.md, and `spec/` remain in place; see [architecture](developer/architecture.md#documentation-ownership).
