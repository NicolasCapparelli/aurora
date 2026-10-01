# Aurora generation recipe v1

A language-independent JSON object describing generator inputs. Decode in Dart
with `AuroraRecipe.decode`, then call `AuroraGenerator.generate`. Decoding has no
IO, browser, Flutter, or filesystem dependency. The CLI is one consumer.

Required fields: `schemaVersion: 1`, nonempty string `id`, nonempty string `name`,
and opaque CSS hex `primary`. Optional seed strings: `secondary`, `tertiary`,
`success`, `warning`, `info`. Absent/null/empty optional seeds use core defaults.

`appearance` is `both` (default), `light`, or `dark`. `preferredAppearance` is
`light` or `dark`, defaults to the first requested appearance, and must be present
in the generated variants. Concrete appearance keys never accept `system`.

`contract` defaults to `{ "id": "aurora-foundation", "version": 1 }`. An explicit
contract requires an `id`, with optional positive integer `version` (default 1)
and `extensions` (default empty array). Every extension is an object with required
`path` and `description` strings. Foundation tokens are added automatically and
cannot be removed or redefined. The same collision/namespace rules as Dart apply.

Optional maps:

- `values`: token path → CSS hex color; shared explicit overrides/extensions.
- `variantValues`: `light`/`dark` → values map; only requested variants allowed.
- `rules`: app extension path → `{ "alias": "token.path" }` or
  `{ "palette": "primary", "lightTone": 92.5, "darkTone": 20 }`.

Tone palettes and precedence follow `generation-v1.md`. All tokens and alias
targets must be declared in the contract. Tones must be finite numbers in [0,100].
Rules fill unresolved app fields; foundation overrides use values. All required
app tokens must resolve for every variant. Cycles and incomplete results fail.

`contrastPairs` is an optional array of objects with required `foreground` and
`background` token paths and optional `minimumRatio` (default 4.5, range [1,21]).
All foreground/background paths must belong to the contract.

Unknown fields at every object boundary are rejected, as are incorrect types.
This is an authoring recipe, not DTCG. Theme output still uses separate DTCG
variant documents. A recipe schema version does not select a color algorithm;
the generator output records its actual pinned algorithm identifier.

See `examples/recipes/theater.json` for a complete extension example. Future ports
should reproduce these input semantics and the existing generator output fixtures.
