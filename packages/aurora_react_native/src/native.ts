// Native style conversions: pure functions from Aurora values to React Native
// style data. Nothing here imports `react-native`, so the functions run anywhere.
//
// Unsupported features are deliberate, never silent. Conversions that can meet a
// feature React Native cannot draw (some stroke styles, fractional font weights)
// throw `AuroraNativeUnsupportedError` by default (`mode: 'strict'`). Pass
// `mode: 'report'` to get `{ style, unsupported }` instead, with a described
// best-effort style, and decide what to do with the list.
import {
  type AuroraBorder,
  AuroraArgumentError,
  AuroraColor,
  type AuroraCubicBezier,
  type AuroraDimension,
  type AuroraDuration,
  type AuroraRef,
  type AuroraShadow,
  type AuroraStrokeStyle,
  type AuroraThemeVariant,
  type AuroraToken,
  type AuroraTypography,
  resolveTextureColor,
} from '@aurora/core';

// ---------------------------------------------------------------- unsupported

/** One Aurora feature React Native cannot render faithfully. */
export interface AuroraNativeUnsupported {
  /** The token path when known (for example `border.card.style`), else the converted field. */
  readonly path: string;
  /** A stable identifier such as `strokeStyle.double` or `strokeStyle.dashArray`. */
  readonly feature: string;
  /** What is unsupported and what `report` mode substituted. */
  readonly message: string;
}

/** Thrown in `strict` mode (the default) when a value uses a feature React Native cannot render. */
export class AuroraNativeUnsupportedError extends Error {
  readonly unsupported: readonly AuroraNativeUnsupported[];

  constructor(unsupported: readonly AuroraNativeUnsupported[]) {
    super(
      `Aurora value is not supported by React Native: ${unsupported
        .map((entry) => `${entry.path} (${entry.feature}): ${entry.message}`)
        .join('; ')}. Pass { mode: 'report' } to get a best-effort style plus the unsupported list.`,
    );
    this.name = 'AuroraNativeUnsupportedError';
    this.unsupported = Object.freeze([...unsupported]);
  }
}

/** The best-effort style plus what could not be represented. */
export interface AuroraNativeResult<T> {
  readonly style: T;
  readonly unsupported: readonly AuroraNativeUnsupported[];
}

export type AuroraNativeMode = 'strict' | 'report';

/** Options for conversions that can hit unsupported features. */
export interface AuroraNativeOptions {
  /** `strict` (default) throws {@link AuroraNativeUnsupportedError}; `report` returns {@link AuroraNativeResult}. */
  mode?: AuroraNativeMode;
  /** Names the converted token in unsupported reports, such as `border.card`. Defaults to the value type. */
  path?: string;
  /** The root font size in dp that `rem` lengths multiply by. Defaults to 16. */
  remBase?: number;
}

/** The return type for options `O`: plain style in strict mode, a result in report mode. */
export type AuroraNativeOutput<T, O> = O extends { readonly mode: 'report' }
  ? AuroraNativeResult<T>
  : O extends { readonly mode: 'strict' }
    ? T
    : 'mode' extends keyof O
      ? T | AuroraNativeResult<T>
      : T;

function finish<T, O extends AuroraNativeOptions>(
  style: T,
  unsupported: AuroraNativeUnsupported[],
  options: O,
): AuroraNativeOutput<T, O> {
  const mode: unknown = options.mode ?? 'strict';
  if (mode !== 'strict' && mode !== 'report') throw new AuroraArgumentError(`Unknown native mode ${String(mode)}`);
  if (mode === 'report') return { style, unsupported: Object.freeze(unsupported) } as AuroraNativeOutput<T, O>;
  if (unsupported.length > 0) throw new AuroraNativeUnsupportedError(unsupported);
  return style as AuroraNativeOutput<T, O>;
}

// ---------------------------------------------------------------- colour

function hex2(value: number): string {
  return value.toString(16).padStart(2, '0');
}

/**
 * A React Native colour string: `#rrggbb` when opaque, otherwise `#rrggbbaa`.
 * Alpha is preserved. (React Native reads `#rrggbbaa` with alpha last, like CSS.)
 */
export function nativeColor(color: AuroraColor): string {
  const rgb = `#${hex2(color.red)}${hex2(color.green)}${hex2(color.blue)}`;
  return color.alpha === 255 ? rgb : `${rgb}${hex2(color.alpha)}`;
}

/** The colour with its alpha replaced by [alpha] in [0, 1] (not multiplied), as a native colour string. */
export function nativeColorWithAlpha(color: AuroraColor, alpha: number): string {
  if (!Number.isFinite(alpha) || alpha < 0 || alpha > 1) {
    throw new AuroraArgumentError(`Alpha must be between 0 and 1, got ${alpha}`);
  }
  return nativeColor(AuroraColor.rgba(color.red, color.green, color.blue, Math.round(alpha * 255)));
}

// ---------------------------------------------------------------- dimension

/** Options for length conversion. */
export interface AuroraNativeLengthOptions {
  /** The root font size in dp that `rem` lengths multiply by. Defaults to 16. */
  remBase?: number;
}

const DEFAULT_REM_BASE = 16;

/**
 * A length in React Native density-independent units. `dp` and `px` both map 1:1
 * (a CSS px is a dp in React Native, which has no separate device pixels in
 * style); `rem` multiplies by `remBase` (default 16).
 */
export function nativeDimension(dimension: AuroraDimension, options: AuroraNativeLengthOptions = {}): number {
  if (dimension.unit !== 'rem') return dimension.value;
  const base = options.remBase ?? DEFAULT_REM_BASE;
  if (!Number.isFinite(base) || base <= 0) throw new AuroraArgumentError(`remBase must be positive, got ${base}`);
  return dimension.value * base;
}

/** `{ borderRadius }` for a radius dimension. */
export function nativeBorderRadius(radius: AuroraDimension, options: AuroraNativeLengthOptions = {}): { borderRadius: number } {
  return { borderRadius: nativeDimension(radius, options) };
}

// ---------------------------------------------------------------- motion

/** Milliseconds (may be fractional, since durations keep microsecond precision). */
export function nativeDuration(duration: AuroraDuration): number {
  return duration.milliseconds;
}

/** Plain cubic-bezier control points, for `Easing.bezier(x1, y1, x2, y2)` in Reanimated or `Animated`. */
export interface AuroraNativeCubicBezier {
  readonly x1: number;
  readonly y1: number;
  readonly x2: number;
  readonly y2: number;
}

export function nativeCubicBezier(curve: AuroraCubicBezier): AuroraNativeCubicBezier {
  return Object.freeze({ x1: curve.x1, y1: curve.y1, x2: curve.x2, y2: curve.y2 });
}

// ---------------------------------------------------------------- stroke and border

/** What React Native can draw as a line: `solid`, `dashed`, `dotted`, or nothing. */
export type AuroraNativeStrokeStyle = 'solid' | 'dashed' | 'dotted' | 'none';

const UNSUPPORTED_KEYWORDS: ReadonlySet<string> = new Set(['double', 'groove', 'ridge', 'outset', 'inset']);

function strokeStyle(style: AuroraStrokeStyle, path: string, unsupported: AuroraNativeUnsupported[]): AuroraNativeStrokeStyle {
  const keyword = style.keyword;
  if (keyword === undefined) {
    unsupported.push({
      path,
      feature: 'strokeStyle.dashArray',
      message: 'custom dash patterns cannot be set on a React Native border; best-effort uses solid',
    });
    unsupported.push({
      path,
      feature: 'strokeStyle.lineCap',
      message: `line cap '${style.lineCap}' cannot be set on a React Native border`,
    });
    return 'solid';
  }
  if (UNSUPPORTED_KEYWORDS.has(keyword)) {
    unsupported.push({
      path,
      feature: `strokeStyle.${keyword}`,
      message: `'${keyword}' borders are not available in React Native; best-effort uses solid`,
    });
    return 'solid';
  }
  return keyword as AuroraNativeStrokeStyle;
}

/**
 * The React Native line style for a stroke. `solid`, `dashed` and `dotted` map
 * directly and `none` stays `none`. Unsupported: `double`, `groove`, `ridge`,
 * `outset`, `inset`, custom dash patterns and line caps; best-effort is `solid`.
 */
export function nativeStrokeStyle<O extends AuroraNativeOptions = {}>(
  style: AuroraStrokeStyle,
  options: O = {} as O,
): AuroraNativeOutput<AuroraNativeStrokeStyle, O> {
  const unsupported: AuroraNativeUnsupported[] = [];
  const result = strokeStyle(style, options.path ?? 'strokeStyle', unsupported);
  return finish(result, unsupported, options);
}

/** The border style fields of a React Native `ViewStyle`. */
export interface AuroraNativeBorderStyle {
  borderWidth: number;
  borderColor?: string;
  borderStyle?: 'solid' | 'dashed' | 'dotted';
}

/**
 * `borderWidth`, `borderColor` and `borderStyle` for a border. The colour (a
 * literal or a theme colour alias) is resolved against [variant]. A `none`
 * stroke becomes `{ borderWidth: 0 }` with no colour or style. Stroke styles
 * React Native cannot draw are unsupported (see {@link nativeStrokeStyle}).
 */
export function nativeBorder<O extends AuroraNativeOptions = {}>(
  border: AuroraBorder,
  variant: AuroraThemeVariant,
  options: O = {} as O,
): AuroraNativeOutput<AuroraNativeBorderStyle, O> {
  const path = options.path ?? 'border';
  const unsupported: AuroraNativeUnsupported[] = [];
  const stroke = strokeStyle(border.style, `${path}.style`, unsupported);
  const style: AuroraNativeBorderStyle =
    stroke === 'none'
      ? { borderWidth: 0 }
      : {
          borderWidth: nativeDimension(border.width, options),
          borderColor: nativeColor(resolveTextureColor(variant, border.color)),
          borderStyle: stroke,
        };
  return finish(style, unsupported, options);
}

// ---------------------------------------------------------------- shadow

/** One entry of a React Native `boxShadow` (New Architecture, RN 0.76 and later). */
export interface AuroraNativeBoxShadow {
  offsetX: number;
  offsetY: number;
  blurRadius: number;
  spreadDistance: number;
  color: string;
  /** Present (true) only for inset shadows. */
  inset?: boolean;
}

/** The `boxShadow` field of a React Native `ViewStyle`; empty for `AuroraShadow.none`. */
export interface AuroraNativeShadowStyle {
  boxShadow: readonly AuroraNativeBoxShadow[];
}

/**
 * Maps each shadow layer to a `boxShadow` entry, in order: offsets, blur as
 * `blurRadius`, spread as `spreadDistance`, `inset`, and the colour resolved
 * against [variant]. Every Aurora shadow is representable.
 */
export function nativeShadow(
  shadow: AuroraShadow,
  variant: AuroraThemeVariant,
  options: AuroraNativeLengthOptions = {},
): AuroraNativeShadowStyle {
  const boxShadow = shadow.layers.map((layer): AuroraNativeBoxShadow => {
    const entry: AuroraNativeBoxShadow = {
      offsetX: nativeDimension(layer.offsetX, options),
      offsetY: nativeDimension(layer.offsetY, options),
      blurRadius: nativeDimension(layer.blur, options),
      spreadDistance: nativeDimension(layer.spread, options),
      color: nativeColor(resolveTextureColor(variant, layer.color)),
    };
    if (layer.inset) entry.inset = true;
    return entry;
  });
  return { boxShadow: Object.freeze(boxShadow) };
}

// ---------------------------------------------------------------- typography

/** React Native's string font weights. */
export type AuroraNativeFontWeight = '100' | '200' | '300' | '400' | '500' | '600' | '700' | '800' | '900';

/** Picks the font family name for a weight; return undefined to use the first family. */
export type AuroraNativeFontFamilyResolver = (families: readonly string[], weight: number) => string | undefined;

export interface AuroraNativeTypographyOptions extends AuroraNativeOptions {
  /**
   * Chooses the registered family for a weight. Android selects custom-font
   * weights by family name, so apps that load one family per weight map
   * `(['Inter'], 700)` to `'Inter-Bold'` here. Default: the first family.
   */
  fontFamilyResolver?: AuroraNativeFontFamilyResolver;
}

/** The text fields of a React Native `TextStyle`. */
export interface AuroraNativeTypographyStyle {
  fontFamily: string;
  /** dp. */
  fontSize: number;
  fontWeight: AuroraNativeFontWeight;
  /** Absolute dp (React Native has no multiplier): Aurora's multiplier times `fontSize`. */
  lineHeight: number;
  /** dp. */
  letterSpacing: number;
}

function nativeFontWeight(value: number, path: string, unsupported: AuroraNativeUnsupported[]): AuroraNativeFontWeight {
  if (!Number.isInteger(value) || value % 100 !== 0 || value < 100 || value > 900) {
    const clamped = Math.min(900, Math.max(100, Math.round(value / 100) * 100));
    unsupported.push({
      path,
      feature: 'fontWeight.step',
      message: `weight ${value} is not one of 100..900 in steps of 100; best-effort uses ${clamped}`,
    });
    return String(clamped) as AuroraNativeFontWeight;
  }
  return String(value) as AuroraNativeFontWeight;
}

/**
 * Typography as React Native text style fields. Font size and letter spacing are
 * dp (rem uses `remBase`). Aurora's line height is a multiplier of the font size
 * and is converted to absolute dp. Weights must be 100..900 in steps of 100;
 * others are unsupported (best-effort rounds to the nearest step). Only the
 * first font family is used unless `fontFamilyResolver` picks one; React Native
 * has no font fallback list. Loading fonts is the app's job.
 */
export function nativeTypography<O extends AuroraNativeTypographyOptions = {}>(
  typography: AuroraTypography,
  options: O & AuroraNativeTypographyOptions = {} as O,
): AuroraNativeOutput<AuroraNativeTypographyStyle, O> {
  const path = options.path ?? 'typography';
  const unsupported: AuroraNativeUnsupported[] = [];
  const weight = typography.fontWeight.value;
  const fontSize = nativeDimension(typography.fontSize, options);
  const style: AuroraNativeTypographyStyle = {
    fontFamily: options.fontFamilyResolver?.(typography.fontFamily.names, weight) ?? typography.fontFamily.primary,
    fontSize,
    fontWeight: nativeFontWeight(weight, `${path}.fontWeight`, unsupported),
    lineHeight: Math.round(typography.lineHeight * fontSize * 1e4) / 1e4,
    letterSpacing: nativeDimension(typography.letterSpacing, options),
  };
  return finish(style, unsupported, options);
}

// ---------------------------------------------------------------- texture reader

/** Native conversions of texture tokens, with colours resolved against the active variant. */
export interface AuroraNativeTextureReader {
  /** A texture or theme colour reference as a native colour string. */
  color(ref: AuroraRef<AuroraColor>): string;
  dimension(token: AuroraToken<AuroraDimension>, options?: AuroraNativeLengthOptions): number;
  borderRadius(token: AuroraToken<AuroraDimension>, options?: AuroraNativeLengthOptions): { borderRadius: number };
  duration(token: AuroraToken<AuroraDuration>): number;
  cubicBezier(token: AuroraToken<AuroraCubicBezier>): AuroraNativeCubicBezier;
  strokeStyle<O extends AuroraNativeOptions = {}>(
    token: AuroraToken<AuroraStrokeStyle>,
    options?: O,
  ): AuroraNativeOutput<AuroraNativeStrokeStyle, O>;
  border<O extends AuroraNativeOptions = {}>(
    token: AuroraToken<AuroraBorder>,
    options?: O,
  ): AuroraNativeOutput<AuroraNativeBorderStyle, O>;
  shadow(token: AuroraToken<AuroraShadow>, options?: AuroraNativeLengthOptions): AuroraNativeShadowStyle;
  typography<O extends AuroraNativeTypographyOptions = {}>(
    token: AuroraToken<AuroraTypography>,
    options?: O,
  ): AuroraNativeOutput<AuroraNativeTypographyStyle, O>;
}

/** @internal Used by the texture view; unsupported reports default their path to the token path. */
export function createNativeTextureReader(
  read: <T>(token: AuroraToken<T>) => T,
  variant: AuroraThemeVariant,
): AuroraNativeTextureReader {
  return Object.freeze({
    color: (ref: AuroraRef<AuroraColor>) => nativeColor(resolveTextureColor(variant, ref)),
    dimension: (token: AuroraToken<AuroraDimension>, options?: AuroraNativeLengthOptions) =>
      nativeDimension(read(token), options),
    borderRadius: (token: AuroraToken<AuroraDimension>, options?: AuroraNativeLengthOptions) =>
      nativeBorderRadius(read(token), options),
    duration: (token: AuroraToken<AuroraDuration>) => nativeDuration(read(token)),
    cubicBezier: (token: AuroraToken<AuroraCubicBezier>) => nativeCubicBezier(read(token)),
    strokeStyle: (token: AuroraToken<AuroraStrokeStyle>, options?: AuroraNativeOptions) =>
      nativeStrokeStyle(read(token), { path: token.path, ...options }),
    border: (token: AuroraToken<AuroraBorder>, options?: AuroraNativeOptions) =>
      nativeBorder(read(token), variant, { path: token.path, ...options }),
    shadow: (token: AuroraToken<AuroraShadow>, options?: AuroraNativeLengthOptions) =>
      nativeShadow(read(token), variant, options),
    typography: (token: AuroraToken<AuroraTypography>, options?: AuroraNativeTypographyOptions) =>
      nativeTypography(read(token), { path: token.path, ...options }),
  }) as AuroraNativeTextureReader;
}
