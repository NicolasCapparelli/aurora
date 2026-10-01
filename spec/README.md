# Portable Aurora behavior, version 1

These definitions and fixtures are language-independent inputs for future ports.
They are JSON, not Dart or Flutter objects. A port may use native naming conventions
while preserving token paths, values, validation, and selection behavior.

## Boundaries

- **AuroraTokens** exposes an immutable snapshot of a complete variant's values.
  It has no global active theme, device access, widget subscriptions, or framework
  color types. Foundation properties and typed app-token reads refer to the same
  snapshot.
- **AuroraRuntime** validates the registry and resolves a selection to a concrete
  variant. The host supplies device appearance. Changes are transactional: an
  invalid request does not change the selected identity or active values.
- **AuroraScope** is an adapter concept: bind native theme consumers and Aurora
  consumers to the nearest selected variant within a subtree.
- **AuroraEngine** is an app integration concept: install root access, resolve
  device appearance, and coordinate native app theming. Controller creation and
  disposal belong to adapters, not portable theme data.

No framework import belongs in the core. Flutter's BuildContext, ChangeNotifier,
ThemeData, and WidgetsBinding are isolated in aurora_flutter. A React adapter can
use context/subscriptions; React Native can map values to its own styling system.

## Contract

`foundation-v1.json` is a generated list of all required foundation fields, their
types, and descriptions. `tools/generate_foundation.py` owns that table. This is
a contract definition document, not a DTCG values document.

App declarations add fields to one contract. They cannot redefine the foundation.
Every concrete variant satisfies the entire app contract. Ports need not reproduce
Dart object identity checks; they must use an equivalent safe mechanism for binding
token declarations and themes to their owning contract.

Colors are unsigned 32-bit ARGB internally in Dart; the portable format uses sRGB
components and alpha. CSS hex input is RGBA, not ARGB. See `docs/dtcg-profile.md`
for the supported interchange subset and 8-bit quantization.

## Conformance fixtures

`fixtures/light.tokens.json` is a complete foundation plus required `demo.ticket`
extension, including transparency. `fixtures/variant-cases.json` describes mutations
to that document and expected outcomes:

- `valid`: decode, then compare the listed token values as CSS #RRGGBBAA.
- `validation`: a required/declared-field contract violation.
- `format`: malformed or unsupported values/references.

Each case starts with a fresh copy. Mutations address object fields using path
arrays. `remove` deletes a field; `set` replaces it with the specified value.
Dart consumes these cases in `packages/aurora/test/portable_test.dart`. Future
TypeScript and other ports should consume the same fixtures, without rewriting
their expected values. Error class names/messages may differ across languages.

To deliberately refresh the baseline fixture, run
`dart run tool/export_portable_fixture.dart` from `packages/aurora`. Do not regenerate
it as part of normal tests; it is a checked-in interoperability reference.

## Selection semantics

- Identity and appearance preference are independent.
- Preference is light, dark, or system; concrete variants are light or dark.
- A system change preserves identity. Explicit preference ignores system changes.
- Unavailable variants either reject or use the declared preferred variant,
  according to a required policy. Never generate values implicitly.
- A fallback preserves the requested preference even when resolved appearance differs.
- Theme registration rejects duplicate identities and incompatible contracts.
- Direct tokens are snapshots; reactive adapters subscribe explicitly.

Seed-based generation is documented in `generation-v1.md`, with additional
cross-language fixtures. Portable authoring inputs are documented in `recipe-v1.md`.
Persistence, more token types, and system UI chrome are
separate future capabilities. Do not couple them to framework widget APIs.
