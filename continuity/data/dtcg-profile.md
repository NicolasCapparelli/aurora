# Aurora DTCG color profile v1

Aurora uses the published [DTCG Format 2025.10](https://www.designtokens.org/tr/2025.10/format/)
for portable color values. This is a supported subset, not a full implementation
of every DTCG token type or its Resolver module.

## Representation

One document contains the complete app-contract values for one concrete variant.
Theme identity, appearance, and contract identity/version belong to the caller's
packaging. The v1 codec does not embed or authenticate that metadata. Importers
must select the intended contract before decoding.

```json
{
  "colors": {
    "$type": "color",
    "primary": {
      "$description": "Accent for prominent actions.",
      "$value": {
        "colorSpace": "srgb",
        "components": [0.1, 0.4, 0.2],
        "alpha": 1
      }
    },
    "surfaceTint": { "$value": "{colors.primary}" }
  }
}
```

The snippet illustrates syntax only; a real document must provide all foundation
and app tokens. Groups flatten to dotted contract paths. All token paths must
exist in the contract. Additional palette primitives therefore need to be part
of the declared contract in this strict profile.

## Supported

- Nested groups, explicit or inherited `color` type, and string descriptions.
- Structured sRGB colors with three finite numeric components in `[0, 1]`.
- Optional alpha in `[0, 1]`, defaulting to 1 when absent.
- Whole-token aliases using `{group.token}`, including chains and inferred type.
- Optional six-digit hex fallback, validated syntactically; components remain
  authoritative.
- `$extensions` objects and `$deprecated` booleans/strings are accepted metadata.
  They do not change Aurora semantics and are not preserved on export.

Values are quantized to Aurora's 8-bit sRGB representation. Export emits resolved
colors and contract descriptions, not original aliases or authoring metadata.

## Explicitly unsupported

Other token types/color spaces, `none` components, legacy hex-string values,
JSON Pointer references, composite references, `$extends`, `$root`, and Resolver
documents. Invalid/unsupported input throws `FormatException`. Missing/undeclared
contract fields throw `AuroraValidationException`. No fallback palette silently
repairs imported themes.

Interoperability must be tested against the particular external tool and its
format version; a claim of DTCG support does not imply support for every feature.

# Aurora DTCG texture profile v1

`AuroraTextureDtcg.encode(texture)` / `decode(document, contract:, id:, name:)`.
One document holds one complete texture (foundation plus extensions). Texture
identity lives outside the document, as for theme variants. Implementation:
`texture_dtcg.dart` with the shared value codec in `texture_codec.dart`.

## Types

Written with their DTCG 2025.10 `$type` and `$value` forms: `dimension`
(`px`/`rem`), `number`, `fontFamily` (string or array), `fontWeight` (number;
keywords accepted on import), `duration` (exported as `ms`; `s` accepted),
`cubicBezier`, `strokeStyle` (keywords or `{dashArray, lineCap}`), `border`,
`shadow` (exported as an array; one object accepted) and `typography`.

Aurora extensions under `$extensions["dev.aurora"]`:

- Booleans and enums have no `$type`; they carry `{"type": "boolean"}` or
  `{"type": "enum", "values": [...]}`. The recorded set must equal the
  contract's. Strict third-party tools may reject these tokens.
- `{"unit": "dp"}` marks a token whose `px` dimensions are Aurora dp. Other tools
  read them as CSS px (logical pixels). A token may not mix dp and px.
- `none` strokes are written as a single zero-length dash (`butt` cap), which
  other tools also draw as nothing; Aurora decodes an all-zero dash pattern as
  `none`. A literal `"none"` keyword is rejected in DTCG.

## References

Whole-token and composite-field aliases are kept on export and must target a
declared texture token of the same type. Colour fields may reference theme colour
tokens (`{colors.outline}`, `{app.ticket}`); these are cross-document references
resolved against the active theme variant, not within the texture document. Export
is exact: decode(encode(texture)) re-encodes identically.

Missing or undeclared tokens, range errors, cycles and enum values outside the
set throw `AuroraValidationException`; other malformed input throws
`FormatException`. Unknown `dev.aurora` fields are rejected.
