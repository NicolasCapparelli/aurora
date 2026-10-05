import type { AuroraColor } from './color.js';
import { AuroraArgumentError } from './errors.js';
import { AuroraFoundation } from './foundation.js';
import type { AuroraAppearance, AuroraThemeVariant } from './theme.js';
import type { AuroraColorToken } from './token.js';

export interface AuroraContrastPairInit {
  foreground: AuroraColorToken;
  background: AuroraColorToken;
  /** WCAG ratio in [1, 21]; defaults to 4.5. */
  minimumRatio?: number;
}

/** Explicit foreground/background usage to evaluate, not a whole-app audit. */
export class AuroraContrastPair {
  readonly foreground: AuroraColorToken;
  readonly background: AuroraColorToken;
  readonly minimumRatio: number;

  constructor(init: AuroraContrastPairInit) {
    const minimumRatio = init.minimumRatio ?? 4.5;
    if (!Number.isFinite(minimumRatio) || minimumRatio < 1 || minimumRatio > 21) {
      throw new AuroraArgumentError(`minimumRatio must be in [1, 21], not ${minimumRatio}`);
    }
    this.foreground = init.foreground;
    this.background = init.background;
    this.minimumRatio = minimumRatio;
    Object.freeze(this);
  }
}

export type AuroraContrastStatus = 'pass' | 'fail' | 'unknown';

export interface AuroraContrastCheckJson {
  appearance: AuroraAppearance;
  foreground: string;
  background: string;
  minimumRatio: number;
  ratio: number | null;
  status: AuroraContrastStatus;
  reason?: 'transparentBackground';
}

export class AuroraContrastCheck {
  constructor(
    readonly appearance: AuroraAppearance,
    readonly pair: AuroraContrastPair,
    /** Null means the background is translucent and its backing color is unknown. */
    readonly ratio: number | null,
  ) {
    Object.freeze(this);
  }

  get status(): AuroraContrastStatus {
    if (this.ratio === null) return 'unknown';
    return this.ratio >= this.pair.minimumRatio ? 'pass' : 'fail';
  }

  toJson(): AuroraContrastCheckJson {
    return {
      appearance: this.appearance,
      foreground: this.pair.foreground.path,
      background: this.pair.background.path,
      minimumRatio: this.pair.minimumRatio,
      ratio: this.ratio,
      status: this.status,
      ...(this.ratio === null ? { reason: 'transparentBackground' as const } : {}),
    };
  }
}

function linear(channel: number): number {
  return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

function luminance(red: number, green: number, blue: number): number {
  return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue);
}

const capital = (name: string): string => name[0]!.toUpperCase() + name.substring(1);

function pair(foreground: string, background: string, minimumRatio = 4.5): AuroraContrastPair {
  const byPath = new Map(AuroraFoundation.tokens.map((token) => [token.path, token]));
  return new AuroraContrastPair({
    foreground: byPath.get(`colors.${foreground}`)!,
    background: byPath.get(`colors.${background}`)!,
    minimumRatio,
  });
}

const foundationPairs: readonly AuroraContrastPair[] = Object.freeze([
  ...['primary', 'secondary', 'tertiary', 'error', 'success', 'warning', 'info'].flatMap((family) => [
    pair(`on${capital(family)}`, family),
    pair(`on${capital(family)}Container`, `${family}Container`),
  ]),
  ...['primary', 'secondary', 'tertiary'].flatMap((family) =>
    [`${family}Fixed`, `${family}FixedDim`].flatMap((background) => [
      pair(`on${capital(family)}Fixed`, background),
      pair(`on${capital(family)}FixedVariant`, background),
    ]),
  ),
  ...[
    'surface',
    'surfaceDim',
    'surfaceBright',
    'surfaceContainerLowest',
    'surfaceContainerLow',
    'surfaceContainer',
    'surfaceContainerHigh',
    'surfaceContainerHighest',
  ].flatMap((surface) => [pair('onSurface', surface), pair('onSurfaceVariant', surface)]),
  pair('onInverseSurface', 'inverseSurface'),
  pair('inversePrimary', 'inverseSurface'),
  pair('outline', 'surface', 3),
]);

/**
 * sRGB relative-luminance contrast. Foreground alpha is composited over an
 * opaque background; translucent backgrounds require a backing color and are
 * reported as unknown. No colors are changed by diagnostics.
 */
export const AuroraContrast = Object.freeze({
  /** The documented foundation pairs, checked for every generated variant. */
  foundationPairs,

  /** WCAG ratio, or null when the background is translucent. */
  ratio(foreground: AuroraColor, background: AuroraColor): number | null {
    if (background.alpha !== 255) return null;
    const alpha = foreground.alpha / 255;
    const backgroundLuminance = luminance(background.red / 255, background.green / 255, background.blue / 255);
    const composite = (front: number, back: number): number => (front * alpha + back * (1 - alpha)) / 255;
    const foregroundLuminance = luminance(
      composite(foreground.red, background.red),
      composite(foreground.green, background.green),
      composite(foreground.blue, background.blue),
    );
    return (
      (Math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
      (Math.min(foregroundLuminance, backgroundLuminance) + 0.05)
    );
  },

  /**
   * Highest measured contrast, retaining the first candidate on ties. Rejects
   * unknown backing colors and empty candidate sets.
   */
  bestOn(background: AuroraColor, candidates: Iterable<AuroraColor>): AuroraColor {
    if (background.alpha !== 255) {
      throw new AuroraArgumentError('Readable foreground needs an opaque background');
    }
    let best: AuroraColor | undefined;
    let highest = -1.0;
    for (const candidate of candidates) {
      const measured = AuroraContrast.ratio(candidate, background)!;
      if (measured > highest) {
        best = candidate;
        highest = measured;
      }
    }
    if (best === undefined) throw new AuroraArgumentError('Provide at least one candidate');
    return best;
  },

  /** Checks the foundation pairs plus [additionalPairs] for one variant. */
  check(variant: AuroraThemeVariant, additionalPairs: Iterable<AuroraContrastPair> = []): AuroraContrastCheck[] {
    return [...foundationPairs, ...additionalPairs].map(
      (p) =>
        new AuroraContrastCheck(
          variant.appearance,
          p,
          AuroraContrast.ratio(variant.read(p.foreground), variant.read(p.background)),
        ),
    );
  },
});
