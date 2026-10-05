# Aurora portable bundle v1

A bundle carries one theme (one or two variants) and optionally one texture from
an outside producer, such as TokenSeed, to an Aurora app. It reuses the existing
profiles: theme variants are [DTCG colour profile](../continuity/data/dtcg-profile.md)
documents and the texture is a [DTCG texture profile](../continuity/data/dtcg-profile.md#aurora-dtcg-texture-profile-v1)
document. All metadata lives in the manifest; nothing is added to the token
documents. Decoding and validation need no IO and are implemented in both cores
(`AuroraBundle` in Dart and TypeScript); they must agree on what is valid.

## Forms

The two forms hold the same content.

- **Single file** (`*.aurora.json` by convention): one JSON object with exactly
  `manifest` (the manifest object) and `files` (an object mapping file names to
  token documents).
- **Folder**: `manifest.json` plus one JSON file per entry of `files`, under the
  same names. Readers load the folder into the single-file object before
  validating; other files in the folder are ignored.

## Manifest

```json
{
  "bundleVersion": 1,
  "theme": {
    "id": "ocean",
    "name": "Ocean",
    "preferredAppearance": "light",
    "variants": ["light", "dark"]
  },
  "texture": { "id": "ocean-soft", "name": "Ocean Soft" },
  "pairing": { "themeId": "ocean", "textureId": "ocean-soft" },
  "provenance": {
    "generator": "tokenseed@0.2.0",
    "sourceHash": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
    "createdAt": "2026-10-05T12:00:00Z"
  }
}
```

| Field | Rule |
| --- | --- |
| `bundleVersion` | Required, the number `1`. |
| `theme.id` | Required. 1 to 80 characters: a lowercase letter, then lowercase letters, digits, `_` or `-` (the installer's directory rule). |
| `theme.name` | Required nonempty string. |
| `theme.variants` | Required nonempty array of unique `light` / `dark`. |
| `theme.preferredAppearance` | Required; one of `theme.variants`. |
| `texture` | Optional. `id` (same rule as `theme.id`) and nonempty `name`. |
| `pairing` | Optional, and only with `texture`. The suggested theme-to-texture pairing: `themeId` must equal `theme.id` and `textureId` must equal `texture.id`. The receiving app decides whether to register it. |
| `provenance` | Required. `generator` (nonempty string naming the producer and its version, such as `tokenseed@0.2.0`), `sourceHash` (nonempty string identifying the source design, such as `sha256:<hex>`), `createdAt` (RFC 3339 date-time with `Z` or an offset). |

Unknown fields anywhere in the manifest are format errors.

## Files

| File | Present when | Profile |
| --- | --- | --- |
| `light.tokens.json` | `theme.variants` contains `light` | DTCG colour profile, one complete variant |
| `dark.tokens.json` | `theme.variants` contains `dark` | DTCG colour profile, one complete variant |
| `texture.tokens.json` | `texture` is present | DTCG texture profile, one complete texture |

A listed file that is missing, or a file that is not listed, is a format error.

## Contracts and validation

By default a bundle is **foundation-only**: variants are validated against the
58-token colour foundation (contract id `aurora-foundation`) and the texture
against the 29-token texture foundation (contract id `aurora-texture-foundation`).
A receiving app may validate against its own contracts instead. Its app extensions
are then required exactly as for any variant or texture, so a foundation-only
bundle fails validation in an app whose contract has required extensions; the app
supplies those values when it registers the theme (see the installer).

Validation reports every issue it can find instead of stopping at the first. Each
issue has:

- `category`: `format` (malformed or unsupported input) or `validation` (contract
  completeness or value rules), matching the error categories of both cores;
- `file`: `manifest`, `bundle` (the outer object or file set), or the token file
  name it concerns;
- `message`: human-readable; messages may differ between languages.

Manifest and file-set problems are all reported. Each token document is decoded
with its profile's decoder, which reports all missing and undeclared tokens and
all value-rule problems together, but stops at the first malformed value in that
document. Texture colour references must name colour tokens of the theme contract
(a `validation` issue on `texture.tokens.json` otherwise). A bundle is valid when
there are no issues. Loading a valid bundle yields the theme, the optional texture
and the optional pairing.

## What a producer cannot put in a bundle

Aurora's foundation and profiles do not change for a producer. A producer maps its
own model onto them when exporting; the
[producer mapping guide](../continuity/user/bundle-producers.md) describes each role.

- **Wide-gamut colours** (display-p3, OKLCH outside sRGB): convert to sRGB, clip
  to the gamut, and write components that quantize to the intended 8-bit value.
  Aurora stores 8-bit sRGB only.
- **Extra modes** (high contrast, dimmed and so on): drop them. A bundle carries
  `light` and/or `dark` only.
- **Extra tokens** (palette steps, component tokens, anything outside the
  contract): leave them out. The strict profiles reject undeclared tokens, so a
  bundle that includes them is invalid.
- **Aliases** between colour tokens are allowed (DTCG whole-token aliases); export
  resolves them. Texture aliases must target texture tokens of the same type, and
  texture colours must be sRGB literals or references to theme colour tokens.

## Fixtures

- `fixtures/bundle.json`: a valid single-file bundle with both variants, a texture
  and a pairing. Refresh only deliberately, with
  `dart run tool/export_bundle_fixture.dart` from `packages/aurora`.
- `fixtures/bundle-cases.json`: mutations of that bundle in the `variant-cases.json`
  format. `expected` is `valid` or a list of the distinct `{category, file}` pairs
  the issues must have (order-independent). A case may set `appExtensions` (theme
  contract extensions as `{path, description}`) to validate against an app
  contract instead of the foundation. `valid` cases may list `values`: token paths
  in `light`, `dark` or `texture`, with expected CSS `#rrggbbaa` colours or
  texture recipe values.

Dart consumes them in `packages/aurora/test/bundle_portable_test.dart` and
TypeScript in `packages/aurora_ts/test/bundle.test.ts`.
