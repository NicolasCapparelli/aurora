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
