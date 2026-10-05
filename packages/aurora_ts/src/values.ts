import type { AuroraColor } from './color.js';
import { dartRound } from './mcu/utils.js';
import { type AuroraRef, refEquals, resolvedRef } from './ref.js';

/** `dp` and `px` are logical pixels; `rem` is relative to the root font size. */
export type AuroraDimensionUnit = 'dp' | 'px' | 'rem';

/** An immutable length with an explicit unit. */
export class AuroraDimension {
  readonly kind = 'dimension' as const;
  constructor(
    readonly value: number,
    readonly unit: AuroraDimensionUnit,
  ) {
    Object.freeze(this);
  }

  static dp(value: number): AuroraDimension {
    return new AuroraDimension(value, 'dp');
  }

  static px(value: number): AuroraDimension {
    return new AuroraDimension(value, 'px');
  }

  static rem(value: number): AuroraDimension {
    return new AuroraDimension(value, 'rem');
  }

  equals(other: unknown): boolean {
    return isKind(other, 'dimension') && other.value === this.value && other.unit === this.unit;
  }

  toString(): string {
    return `${this.value}${this.unit}`;
  }
}

/** An ordered, nonempty list of font family names, most preferred first. */
export class AuroraFontFamily {
  readonly kind = 'fontFamily' as const;
  readonly names: readonly string[];

  constructor(names: Iterable<string>) {
    this.names = Object.freeze([...names]);
    Object.freeze(this);
  }

  static single(name: string): AuroraFontFamily {
    return new AuroraFontFamily([name]);
  }

  /** The most preferred family; the remaining names are fallbacks. */
  get primary(): string {
    return this.names[0]!;
  }

  get fallbacks(): readonly string[] {
    return this.names.slice(1);
  }

  equals(other: unknown): boolean {
    return isKind(other, 'fontFamily') && listEquals(other.names, this.names);
  }

  toString(): string {
    return this.names.join(', ');
  }
}

/** A numeric font weight in [1, 1000]. */
export class AuroraFontWeight {
  readonly kind = 'fontWeight' as const;
  constructor(readonly value: number) {
    Object.freeze(this);
  }

  static readonly thin = new AuroraFontWeight(100);
  static readonly extraLight = new AuroraFontWeight(200);
  static readonly light = new AuroraFontWeight(300);
  static readonly regular = new AuroraFontWeight(400);
  static readonly medium = new AuroraFontWeight(500);
  static readonly semiBold = new AuroraFontWeight(600);
  static readonly bold = new AuroraFontWeight(700);
  static readonly extraBold = new AuroraFontWeight(800);
  static readonly black = new AuroraFontWeight(900);

  equals(other: unknown): boolean {
    return isKind(other, 'fontWeight') && other.value === this.value;
  }

  toString(): string {
    return `${this.value}`;
  }
}

/**
 * A length of time with microsecond precision, matching Dart's `Duration`.
 * Fractional microseconds round half away from zero.
 */
export class AuroraDuration {
  readonly kind = 'duration' as const;
  readonly microseconds: number;

  constructor(microseconds: number) {
    this.microseconds = dartRound(microseconds) + 0;
    Object.freeze(this);
  }

  static ms(milliseconds: number): AuroraDuration {
    return new AuroraDuration(milliseconds * 1000);
  }

  static seconds(seconds: number): AuroraDuration {
    return new AuroraDuration(seconds * 1000000);
  }

  get milliseconds(): number {
    return this.microseconds / 1000;
  }

  get isNegative(): boolean {
    return this.microseconds < 0;
  }

  equals(other: unknown): boolean {
    return isKind(other, 'duration') && other.microseconds === this.microseconds;
  }

  toString(): string {
    return `${this.milliseconds}ms`;
  }
}

/**
 * An easing curve from (0, 0) to (1, 1) with control points (x1, y1) and
 * (x2, y2). The x coordinates must be in [0, 1].
 */
export class AuroraCubicBezier {
  readonly kind = 'cubicBezier' as const;
  constructor(
    readonly x1: number,
    readonly y1: number,
    readonly x2: number,
    readonly y2: number,
  ) {
    Object.freeze(this);
  }

  equals(other: unknown): boolean {
    return (
      isKind(other, 'cubicBezier') &&
      other.x1 === this.x1 &&
      other.y1 === this.y1 &&
      other.x2 === this.x2 &&
      other.y2 === this.y2
    );
  }

  toString(): string {
    return `cubic-bezier(${this.x1}, ${this.y1}, ${this.x2}, ${this.y2})`;
  }
}

/** DTCG stroke style keywords, plus Aurora's `none`. */
export type AuroraStrokeKeyword = 'solid' | 'dashed' | 'dotted' | 'double' | 'groove' | 'ridge' | 'outset' | 'inset' | 'none';

export const AURORA_STROKE_KEYWORDS: readonly AuroraStrokeKeyword[] = Object.freeze([
  'solid',
  'dashed',
  'dotted',
  'double',
  'groove',
  'ridge',
  'outset',
  'inset',
  'none',
]);

/** Line ends for a dash pattern. */
export type AuroraLineCap = 'round' | 'butt' | 'square';

/** How a line is drawn: a keyword such as `solid`, or a dash pattern. */
export class AuroraStrokeStyle {
  readonly kind = 'strokeStyle' as const;
  /** Set for keyword styles; undefined for dash patterns. */
  readonly keyword: AuroraStrokeKeyword | undefined;
  /** Set for dash patterns; undefined for keyword styles. */
  readonly lineCap: AuroraLineCap | undefined;
  /** Authored dash entries, which may be aliases. Undefined for keyword styles. */
  readonly dashArrayRefs: readonly AuroraRef<AuroraDimension>[] | undefined;

  private constructor(
    keyword: AuroraStrokeKeyword | undefined,
    dashArray: readonly AuroraRef<AuroraDimension>[] | undefined,
    lineCap: AuroraLineCap | undefined,
  ) {
    this.keyword = keyword;
    this.dashArrayRefs = dashArray === undefined ? undefined : Object.freeze([...dashArray]);
    this.lineCap = lineCap;
    Object.freeze(this);
  }

  static keyword(keyword: AuroraStrokeKeyword): AuroraStrokeStyle {
    return new AuroraStrokeStyle(keyword, undefined, undefined);
  }

  /** A custom dash pattern: alternating dash and gap lengths. */
  static dashes(dashArray: Iterable<AuroraRef<AuroraDimension>>, lineCap: AuroraLineCap): AuroraStrokeStyle {
    return new AuroraStrokeStyle(undefined, [...dashArray], lineCap);
  }

  static readonly solid = AuroraStrokeStyle.keyword('solid');
  static readonly dashed = AuroraStrokeStyle.keyword('dashed');
  static readonly dotted = AuroraStrokeStyle.keyword('dotted');
  static readonly none = AuroraStrokeStyle.keyword('none');

  /** Resolved dash lengths. Undefined for keyword styles. */
  get dashArray(): AuroraDimension[] | undefined {
    return this.dashArrayRefs?.map((ref) => resolvedRef(ref, 'dashArray'));
  }

  get isNone(): boolean {
    return this.keyword === 'none';
  }

  equals(other: unknown): boolean {
    return (
      isKind(other, 'strokeStyle') &&
      other.keyword === this.keyword &&
      other.lineCap === this.lineCap &&
      refListEquals(other.dashArrayRefs, this.dashArrayRefs)
    );
  }

  toString(): string {
    return this.keyword ?? `dashes(${this.dashArrayRefs?.join(', ')}, ${this.lineCap})`;
  }
}

export interface AuroraBorderInit {
  /** A literal colour or an alias to a theme colour token. */
  color: AuroraRef<AuroraColor>;
  width: AuroraRef<AuroraDimension>;
  style: AuroraRef<AuroraStrokeStyle>;
}

/**
 * A border. Its color is usually an alias to a theme colour token, such as
 * `new AuroraAlias(AuroraFoundation.outline)`, so it follows light and dark.
 */
export class AuroraBorder {
  readonly kind = 'border' as const;
  readonly color: AuroraRef<AuroraColor>;
  readonly widthRef: AuroraRef<AuroraDimension>;
  readonly styleRef: AuroraRef<AuroraStrokeStyle>;

  constructor(init: AuroraBorderInit) {
    this.color = init.color;
    this.widthRef = init.width;
    this.styleRef = init.style;
    Object.freeze(this);
  }

  get width(): AuroraDimension {
    return resolvedRef(this.widthRef, 'width');
  }

  get style(): AuroraStrokeStyle {
    return resolvedRef(this.styleRef, 'style');
  }

  equals(other: unknown): boolean {
    return (
      isKind(other, 'border') &&
      refEquals(other.color, this.color) &&
      refEquals(other.widthRef, this.widthRef) &&
      refEquals(other.styleRef, this.styleRef)
    );
  }
}

export interface AuroraShadowLayerInit {
  color: AuroraRef<AuroraColor>;
  offsetX: AuroraRef<AuroraDimension>;
  offsetY: AuroraRef<AuroraDimension>;
  blur: AuroraRef<AuroraDimension>;
  spread: AuroraRef<AuroraDimension>;
  inset?: boolean;
}

/** One shadow layer. Its color may alias a theme colour token. */
export class AuroraShadowLayer {
  readonly kind = 'shadowLayer' as const;
  readonly color: AuroraRef<AuroraColor>;
  readonly offsetXRef: AuroraRef<AuroraDimension>;
  readonly offsetYRef: AuroraRef<AuroraDimension>;
  readonly blurRef: AuroraRef<AuroraDimension>;
  readonly spreadRef: AuroraRef<AuroraDimension>;
  readonly inset: boolean;

  constructor(init: AuroraShadowLayerInit) {
    this.color = init.color;
    this.offsetXRef = init.offsetX;
    this.offsetYRef = init.offsetY;
    this.blurRef = init.blur;
    this.spreadRef = init.spread;
    this.inset = init.inset ?? false;
    Object.freeze(this);
  }

  get offsetX(): AuroraDimension {
    return resolvedRef(this.offsetXRef, 'offsetX');
  }

  get offsetY(): AuroraDimension {
    return resolvedRef(this.offsetYRef, 'offsetY');
  }

  get blur(): AuroraDimension {
    return resolvedRef(this.blurRef, 'blur');
  }

  get spread(): AuroraDimension {
    return resolvedRef(this.spreadRef, 'spread');
  }

  equals(other: unknown): boolean {
    return (
      isKind(other, 'shadowLayer') &&
      refEquals(other.color, this.color) &&
      refEquals(other.offsetXRef, this.offsetXRef) &&
      refEquals(other.offsetYRef, this.offsetYRef) &&
      refEquals(other.blurRef, this.blurRef) &&
      refEquals(other.spreadRef, this.spreadRef) &&
      other.inset === this.inset
    );
  }
}

/** One or more shadow layers, drawn in order. An empty list means no shadow. */
export class AuroraShadow {
  readonly kind = 'shadow' as const;
  readonly layers: readonly AuroraShadowLayer[];

  constructor(layers: Iterable<AuroraShadowLayer>) {
    this.layers = Object.freeze([...layers]);
    Object.freeze(this);
  }

  static readonly none = new AuroraShadow([]);

  equals(other: unknown): boolean {
    return isKind(other, 'shadow') && refListEquals(other.layers, this.layers);
  }
}

export interface AuroraTypographyInit {
  fontFamily: AuroraRef<AuroraFontFamily>;
  fontSize: AuroraRef<AuroraDimension>;
  fontWeight: AuroraRef<AuroraFontWeight>;
  letterSpacing: AuroraRef<AuroraDimension>;
  /** A multiplier of the font size. */
  lineHeight: AuroraRef<number>;
}

/** A text style. Any field may alias a token of that field's type. */
export class AuroraTypography {
  readonly kind = 'typography' as const;
  readonly fontFamilyRef: AuroraRef<AuroraFontFamily>;
  readonly fontSizeRef: AuroraRef<AuroraDimension>;
  readonly fontWeightRef: AuroraRef<AuroraFontWeight>;
  readonly letterSpacingRef: AuroraRef<AuroraDimension>;
  readonly lineHeightRef: AuroraRef<number>;

  constructor(init: AuroraTypographyInit) {
    this.fontFamilyRef = init.fontFamily;
    this.fontSizeRef = init.fontSize;
    this.fontWeightRef = init.fontWeight;
    this.letterSpacingRef = init.letterSpacing;
    this.lineHeightRef = init.lineHeight;
    Object.freeze(this);
  }

  get fontFamily(): AuroraFontFamily {
    return resolvedRef(this.fontFamilyRef, 'fontFamily');
  }

  get fontSize(): AuroraDimension {
    return resolvedRef(this.fontSizeRef, 'fontSize');
  }

  get fontWeight(): AuroraFontWeight {
    return resolvedRef(this.fontWeightRef, 'fontWeight');
  }

  get letterSpacing(): AuroraDimension {
    return resolvedRef(this.letterSpacingRef, 'letterSpacing');
  }

  get lineHeight(): number {
    return resolvedRef(this.lineHeightRef, 'lineHeight');
  }

  equals(other: unknown): boolean {
    return (
      isKind(other, 'typography') &&
      refEquals(other.fontFamilyRef, this.fontFamilyRef) &&
      refEquals(other.fontSizeRef, this.fontSizeRef) &&
      refEquals(other.fontWeightRef, this.fontWeightRef) &&
      refEquals(other.letterSpacingRef, this.letterSpacingRef) &&
      refEquals(other.lineHeightRef, this.lineHeightRef)
    );
  }
}

interface Kinds {
  dimension: AuroraDimension;
  fontFamily: AuroraFontFamily;
  fontWeight: AuroraFontWeight;
  duration: AuroraDuration;
  cubicBezier: AuroraCubicBezier;
  strokeStyle: AuroraStrokeStyle;
  border: AuroraBorder;
  shadowLayer: AuroraShadowLayer;
  shadow: AuroraShadow;
  typography: AuroraTypography;
  color: AuroraColor;
}

/** True when [value] is an Aurora value of [kind], checked without `instanceof`. */
export function isKind<K extends keyof Kinds>(value: unknown, kind: K): value is Kinds[K] {
  return typeof value === 'object' && value !== null && (value as { kind?: unknown }).kind === kind;
}

function listEquals(a: readonly unknown[], b: readonly unknown[]): boolean {
  return a.length === b.length && a.every((value, i) => value === b[i]);
}

function refListEquals(a: readonly unknown[] | undefined, b: readonly unknown[] | undefined): boolean {
  if (a === undefined || b === undefined) return a === b;
  return a.length === b.length && a.every((value, i) => refEquals(value, b[i]));
}
