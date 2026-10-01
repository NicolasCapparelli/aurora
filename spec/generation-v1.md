# Portable generation semantics v1

Algorithm: `aurora-tonal-v1-mcu-0.11.1`.
This remains the default tonal-spot algorithm. Additive brand strategies use
`aurora-<schemeName>-v1-mcu-0.11.1`: fidelity, vibrant, expressive, content,
monochrome, neutral, rainbow, fruitSalad. Scheme names are case-sensitive.
Select the corresponding pinned MCU scheme at contrast zero; retain the same
override/rule precedence and independent tonal-spot status schemes. Surface tint
uses resolved primary, as in Flutter. The new strategies are pinned in
`fixtures/generation-schemes-v1.json`; normal tests only read them.
No foundation version or existing expected fixture changes are needed.

The normative algorithm steps and precedence are recorded in `continuity/developer/generator.md`.
Use a Material Color Utilities implementation equivalent to Dart 0.11.1. Language
package versions are not interchangeable release identifiers. A new upstream
algorithm must not silently replace this generator version.

Portable inputs are opaque sRGB seed colors, requested appearance names, contract
definitions, explicit token values, and declarative alias or HCT tone rules.
The current Dart API uses typed declarations; future JSON/API adapters can encode
token references by their stable contract paths. No framework callback or device
appearance is needed to generate a theme.

`fixtures/generation-v1.json` pins every generated token for a single-seed example,
a three-seed example, and a dark-only example. It also pins the diagnostic pairs,
thresholds, statuses, and ratios. Ports should compare 8-bit output colors exactly;
contrast ratios allow a floating-point tolerance of 1e-6. These fixtures cover the
base palettes; Dart behavioral tests additionally cover extension rules, cycles,
overrides, transparency, invalid inputs, and deterministic output.

Output themes must satisfy the same contract as authored themes. Do not bypass
normal validation. App extensions are never guessed from field names. Explicit
values win over rules; per-appearance values win over shared values. Generation
failure returns no partial theme and changes no active runtime.

Foreground contrast is computed after alpha compositing over an opaque background
in sRGB channel space, then applying relative-luminance linearization (threshold
0.04045, exponent 2.4, coefficients 0.2126/0.7152/0.0722). Contrast is
`(max(luminance) + 0.05) / (min(luminance) + 0.05)`. Unknown backing colors produce
unknown diagnostics. No implicit threshold tolerance is used to mark a result as
passing. Declared thresholds are not a whole-app accessibility guarantee.

To deliberately refresh the fixture, run
`dart run tool/export_generation_fixture.dart` from `packages/aurora`. Tests consume
the checked-in expectations; they must not regenerate them during verification.

The generator has no random input and no runtime network or filesystem dependency.
Requests and results are immutable snapshots; future hosts may cache them using
their own canonical request encoding and this explicit algorithm version.
