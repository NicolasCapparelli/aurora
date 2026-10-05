import type { AuroraColor } from './color.js';
import type {
  AuroraBorder,
  AuroraCubicBezier,
  AuroraDimension,
  AuroraDuration,
  AuroraFontFamily,
  AuroraFontWeight,
  AuroraShadow,
  AuroraStrokeStyle,
  AuroraTypography,
} from './values.js';

/** The DTCG `$type`, or Aurora's extension type for `boolean` and `enum`. */
export type AuroraTokenType =
  | 'color'
  | 'dimension'
  | 'number'
  | 'fontFamily'
  | 'fontWeight'
  | 'duration'
  | 'cubicBezier'
  | 'strokeStyle'
  | 'border'
  | 'shadow'
  | 'typography'
  | 'boolean'
  | 'enum';

export interface AuroraTokenOptions {
  description: string;
}

/**
 * A typed, documented field in an Aurora contract. Declare tokens once as
 * module constants, then reuse those declarations for values and reads.
 * Membership in a contract is by identity, so a token must be the same object
 * everywhere it is used.
 *
 * Colour tokens belong to theme contracts. Every other type belongs to texture
 * contracts.
 */
export abstract class AuroraToken<T> {
  readonly kind = 'token' as const;
  abstract readonly type: AuroraTokenType;
  readonly path: string;
  readonly description: string;
  /** Carries the value type for typed reads; never set at runtime. */
  declare readonly __value?: T;

  constructor(path: string, options: AuroraTokenOptions) {
    this.path = path;
    this.description = options.description;
  }

  toString(): string {
    return this.path;
  }
}

/** The value type a token holds. */
export type AuroraTokenValue<K> = K extends AuroraToken<infer T> ? T : never;

/** A typed color field. */
export class AuroraColorToken extends AuroraToken<AuroraColor> {
  readonly type = 'color' as const;
}

/** A length, such as a corner radius, border width or padding. */
export class AuroraDimensionToken extends AuroraToken<AuroraDimension> {
  readonly type = 'dimension' as const;
}

/** A unitless finite number, such as an elevation level or opacity. */
export class AuroraNumberToken extends AuroraToken<number> {
  readonly type = 'number' as const;
}

/** An ordered list of font family names, most preferred first. */
export class AuroraFontFamilyToken extends AuroraToken<AuroraFontFamily> {
  readonly type = 'fontFamily' as const;
}

/** A numeric font weight in [1, 1000]. */
export class AuroraFontWeightToken extends AuroraToken<AuroraFontWeight> {
  readonly type = 'fontWeight' as const;
}

/** A nonnegative length of time, such as an animation duration. */
export class AuroraDurationToken extends AuroraToken<AuroraDuration> {
  readonly type = 'duration' as const;
}

/** An easing curve, defined by two cubic Bézier control points. */
export class AuroraCubicBezierToken extends AuroraToken<AuroraCubicBezier> {
  readonly type = 'cubicBezier' as const;
}

/** How a line is drawn: solid, dashed, dotted, none, or a dash pattern. */
export class AuroraStrokeStyleToken extends AuroraToken<AuroraStrokeStyle> {
  readonly type = 'strokeStyle' as const;
}

/** A border: colour, width and stroke style. */
export class AuroraBorderToken extends AuroraToken<AuroraBorder> {
  readonly type = 'border' as const;
}

/** One or more shadow layers. */
export class AuroraShadowToken extends AuroraToken<AuroraShadow> {
  readonly type = 'shadow' as const;
}

/** A text style: family, size, weight, letter spacing and line height. */
export class AuroraTypographyToken extends AuroraToken<AuroraTypography> {
  readonly type = 'typography' as const;
}

/** An on/off switch. Encoded as an Aurora DTCG extension. */
export class AuroraBooleanToken extends AuroraToken<boolean> {
  readonly type = 'boolean' as const;
}

export interface AuroraEnumTokenOptions<V extends string> extends AuroraTokenOptions {
  values: readonly V[];
}

/**
 * One of a fixed set of string values, such as a default component layout. A
 * value outside the set is a validation error.
 */
export class AuroraEnumToken<V extends string = string> extends AuroraToken<V> {
  readonly type = 'enum' as const;
  readonly values: readonly V[];

  constructor(path: string, options: AuroraEnumTokenOptions<V>) {
    super(path, options);
    this.values = Object.freeze([...options.values]);
  }
}

/** Every concrete texture token class (all token types except colour). */
export type AuroraTextureTokenAny =
  | AuroraDimensionToken
  | AuroraNumberToken
  | AuroraFontFamilyToken
  | AuroraFontWeightToken
  | AuroraDurationToken
  | AuroraCubicBezierToken
  | AuroraStrokeStyleToken
  | AuroraBorderToken
  | AuroraShadowToken
  | AuroraTypographyToken
  | AuroraBooleanToken
  | AuroraEnumToken;

/** Every concrete token class. */
export type AuroraAnyToken = AuroraColorToken | AuroraTextureTokenAny;

/** A token of [type] with no contract meaning, used to name field kinds. */
export function tokenOfType(type: AuroraTokenType, path: string, description: string): AuroraAnyToken {
  const options = { description };
  switch (type) {
    case 'color':
      return new AuroraColorToken(path, options);
    case 'dimension':
      return new AuroraDimensionToken(path, options);
    case 'number':
      return new AuroraNumberToken(path, options);
    case 'fontFamily':
      return new AuroraFontFamilyToken(path, options);
    case 'fontWeight':
      return new AuroraFontWeightToken(path, options);
    case 'duration':
      return new AuroraDurationToken(path, options);
    case 'cubicBezier':
      return new AuroraCubicBezierToken(path, options);
    case 'strokeStyle':
      return new AuroraStrokeStyleToken(path, options);
    case 'border':
      return new AuroraBorderToken(path, options);
    case 'shadow':
      return new AuroraShadowToken(path, options);
    case 'typography':
      return new AuroraTypographyToken(path, options);
    case 'boolean':
      return new AuroraBooleanToken(path, options);
    case 'enum':
      return new AuroraEnumToken(path, { description, values: [] });
  }
}
