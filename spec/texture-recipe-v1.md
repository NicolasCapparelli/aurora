# Aurora texture recipe v1

A language-independent JSON object describing one texture. Decode in Dart with
`AuroraTextureRecipe.decode(recipe, contract: appTextureContract)`. Decoding has no
IO, Flutter or filesystem dependency. Theme recipe v1 (`recipe-v1.md`) is
unchanged; the two are distinguished by `kind`.

Required fields: `schemaVersion: 1`, `kind: "texture"`, nonempty string `id` and
nonempty string `name`.

`base` is `"material"` (default) or `"none"`. `material` starts from Aurora's
Material 3 starter values for every texture foundation token, so a recipe only
lists app extensions and deliberate overrides. `none` requires every token.

`contract` defaults to `{ "id": "aurora-texture-foundation", "version": 1 }`. It
has a required `id`, optional positive integer `version` (default 1) and
optional `extensions`. Each extension has required `path`, `description` and
`type`: one of `dimension`, `number`, `fontFamily`, `fontWeight`, `duration`,
`cubicBezier`, `strokeStyle`, `border`, `shadow`, `typography`, `boolean` or
`enum`. An `enum` also requires `values`, a nonempty array of unique strings.
Texture foundation tokens are added automatically; the `type`, `shape` and
`motion` namespaces are reserved and colour tokens are not allowed. When the
caller passes its own contract, the recipe's contract must describe exactly that
contract (id, version, paths, types and enum values); descriptions are not
compared.

`values` maps token paths to values in DTCG 2025.10 `$value` syntax, with two
Aurora additions: dimensions may use the unit `dp`, and strokes may use the
keyword `none`.

| Type | Value |
| --- | --- |
| dimension | `{ "value": 12, "unit": "dp" | "px" | "rem" }` |
| number | finite number |
| fontFamily | string, or array of strings (most preferred first) |
| fontWeight | integer 1-1000, or a DTCG keyword such as `"semi-bold"` |
| duration | `{ "value": 200, "unit": "ms" | "s" }`, nonnegative |
| cubicBezier | `[x1, y1, x2, y2]`, x in [0, 1] |
| strokeStyle | keyword (`solid`, `dashed`, `dotted`, `double`, `groove`, `ridge`, `outset`, `inset`, `none`) or `{ "dashArray": [dimension...], "lineCap": "round" | "butt" | "square" }` |
| border | `{ "color", "width", "style" }` |
| shadow | one layer or an array of layers `{ "color", "offsetX", "offsetY", "blur", "spread", "inset"? }` |
| typography | `{ "fontFamily", "fontSize", "fontWeight", "letterSpacing", "lineHeight" }` (lineHeight is a multiplier) |
| boolean | `true` / `false` |
| enum | one of the declared `values` |

Any value, and any composite field, may be an alias `"{path}"` to a declared
texture token of the same type. Colour fields (border and shadow colours) are a
DTCG structured sRGB colour or an alias to a theme colour token such as
`"{colors.outline}"`; those resolve against the active theme variant and must
exist in the app's theme contract when textures are registered. Aliases resolve
when the texture is built; cycles fail. One token may not mix `dp` and `px`, and a
dash pattern of only zero lengths must be written as `none`.

Unknown fields at every object boundary, incorrect types and undeclared tokens
throw `FormatException`; missing tokens, range errors, alias cycles and enum
values outside the allowed set throw `AuroraValidationException`.

See `examples/recipes/texture-soft.json`, `examples/recipes/texture-editorial.json`
and the conformance recipe `fixtures/texture-recipe.json`.
