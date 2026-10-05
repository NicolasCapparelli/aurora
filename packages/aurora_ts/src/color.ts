import { AuroraArgumentError, AuroraFormatError } from './errors.js';

const HEX = /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/;

/** An immutable sRGB color stored as an unsigned 32-bit ARGB value. */
export class AuroraColor {
  readonly kind = 'color' as const;
  readonly argb: number;

  constructor(argb: number) {
    if (!Number.isInteger(argb) || argb < 0 || argb > 0xffffffff) {
      throw new AuroraArgumentError(`Expected a 32-bit ARGB value, not ${argb}`);
    }
    this.argb = argb;
    Object.freeze(this);
  }

  /** Parses `#RRGGBB` or `#RRGGBBAA` (CSS order, not ARGB). */
  static hex(hex: string): AuroraColor {
    if (!HEX.test(hex)) throw new AuroraFormatError(`Expected #RRGGBB or #RRGGBBAA: ${hex}`);
    const rgb = parseInt(hex.substring(1, 7), 16);
    const alpha = hex.length === 9 ? parseInt(hex.substring(7), 16) : 255;
    return new AuroraColor(((alpha << 24) | rgb) >>> 0);
  }

  /** Builds a color from 8-bit channels. */
  static rgba(red: number, green: number, blue: number, alpha = 255): AuroraColor {
    for (const channel of [red, green, blue, alpha]) {
      if (!Number.isInteger(channel) || channel < 0 || channel > 255) {
        throw new AuroraArgumentError(`Expected 8-bit channels, not ${channel}`);
      }
    }
    return new AuroraColor(((alpha << 24) | (red << 16) | (green << 8) | blue) >>> 0);
  }

  get alpha(): number {
    return (this.argb >>> 24) & 255;
  }

  get red(): number {
    return (this.argb >>> 16) & 255;
  }

  get green(): number {
    return (this.argb >>> 8) & 255;
  }

  get blue(): number {
    return this.argb & 255;
  }

  /** Lowercase `#rrggbbaa`, as the portable fixtures compare colors. */
  get hex(): string {
    return `#${[this.red, this.green, this.blue, this.alpha].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
  }

  equals(other: unknown): boolean {
    return isAuroraColor(other) && other.argb === this.argb;
  }

  toString(): string {
    return this.hex;
  }
}

/** True for an {@link AuroraColor}, checked by its `kind` rather than `instanceof`. */
export function isAuroraColor(value: unknown): value is AuroraColor {
  return typeof value === 'object' && value !== null && (value as { kind?: unknown }).kind === 'color';
}
