import { type AuroraColor, isAuroraColor } from './color.js';
import type { AuroraContract } from './contract.js';
import { AuroraArgumentError, AuroraValidationError } from './errors.js';
import { AuroraStarterValues } from './starters.js';
import { AuroraTokens } from './foundation.js';
import type { AuroraColorToken } from './token.js';

/** A concrete appearance. */
export type AuroraAppearance = 'light' | 'dark';

/** A selection preference: a concrete appearance, or follow the system. */
export type AuroraAppearancePreference = 'light' | 'dark' | 'system';

export const AURORA_APPEARANCES: readonly AuroraAppearance[] = Object.freeze(['light', 'dark']);

/** Exact portable names; unknown values return undefined for caller-owned fallback. */
export function parseAppearancePreference(name: unknown): AuroraAppearancePreference | undefined {
  return name === 'light' || name === 'dark' || name === 'system' ? name : undefined;
}

/** Token-keyed values: a `Map`, or any iterable of `[token, value]` pairs. */
export type AuroraValues<K, V> = ReadonlyMap<K, V> | Iterable<readonly [K, V]>;

export interface AuroraThemeVariantInit {
  contract: AuroraContract;
  appearance: AuroraAppearance;
  values: AuroraValues<AuroraColorToken, unknown>;
}

/** Complete, validated values for a single concrete appearance. */
export class AuroraThemeVariant {
  readonly contract: AuroraContract;
  readonly appearance: AuroraAppearance;
  readonly values: ReadonlyMap<AuroraColorToken, AuroraColor>;
  private _tokens: AuroraTokens | undefined;

  constructor(init: AuroraThemeVariantInit) {
    const { contract } = init;
    const values = new Map(init.values);
    const issues: string[] = [];
    for (const token of contract.tokens.values()) {
      if (!values.has(token)) {
        issues.push(`Missing required token ${token.path}`);
      } else if (!isAuroraColor(values.get(token))) {
        issues.push(`${token.path} must be an AuroraColor`);
      }
    }
    for (const token of values.keys()) {
      if (!contract.contains(token)) issues.push(`Undeclared token ${token.path}`);
    }
    if (issues.length > 0) throw new AuroraValidationError(issues);
    this.contract = contract;
    this.appearance = init.appearance;
    // Contract order, so iteration and export are deterministic.
    this.values = new Map([...contract.tokens.values()].map((token) => [token, values.get(token) as AuroraColor]));
  }

  read(token: AuroraColorToken): AuroraColor {
    if (!this.contract.contains(token)) {
      throw new AuroraArgumentError(`Token ${token.path} is not in this contract`);
    }
    return this.values.get(token)!;
  }

  /** Direct immutable token values, usable without any framework integration. */
  get tokens(): AuroraTokens {
    this._tokens ??= new AuroraTokens(this);
    return this._tokens;
  }

  /** Convenience alias for color-focused consumers. */
  get colors(): AuroraTokens {
    return this.tokens;
  }
}

export interface AuroraThemeInit {
  id: string;
  name: string;
  variants: Iterable<AuroraThemeVariant>;
  preferredAppearance: AuroraAppearance;
}

/** Identity plus available complete variants, all using the same app contract. */
export class AuroraTheme {
  readonly id: string;
  readonly name: string;
  readonly contract: AuroraContract;
  readonly variants: ReadonlyMap<AuroraAppearance, AuroraThemeVariant>;
  readonly preferredAppearance: AuroraAppearance;

  constructor(init: AuroraThemeInit) {
    if (init.id.trim() === '' || init.name.trim() === '') {
      throw new AuroraArgumentError('Theme id and name cannot be empty');
    }
    const byAppearance = new Map<AuroraAppearance, AuroraThemeVariant>();
    let contract: AuroraContract | undefined;
    for (const variant of init.variants) {
      contract ??= variant.contract;
      if (contract !== variant.contract) {
        throw new AuroraArgumentError('Variants must use the same contract instance');
      }
      if (byAppearance.has(variant.appearance)) {
        throw new AuroraArgumentError(`Duplicate ${variant.appearance} variant`);
      }
      byAppearance.set(variant.appearance, variant);
    }
    if (!byAppearance.has(init.preferredAppearance)) {
      throw new AuroraArgumentError('Preferred appearance must have a variant');
    }
    this.id = init.id;
    this.name = init.name;
    this.contract = contract!;
    this.variants = byAppearance;
    this.preferredAppearance = init.preferredAppearance;
    Object.freeze(this);
  }

  /** The variant for [appearance], if the theme has one. */
  variant(appearance: AuroraAppearance): AuroraThemeVariant | undefined {
    return this.variants.get(appearance);
  }
}

export interface AuroraStarterVariantInit {
  contract: AuroraContract;
  appearance: AuroraAppearance;
  /** App extensions and deliberate foundation overrides. */
  values?: AuroraValues<AuroraColorToken, AuroraColor>;
}

/** Complete explicit foundation presets; app extensions are still required. */
export const AuroraStarter = Object.freeze({
  light: AuroraStarterValues.light,
  dark: AuroraStarterValues.dark,
  variant(init: AuroraStarterVariantInit): AuroraThemeVariant {
    const base = init.appearance === 'light' ? AuroraStarterValues.light : AuroraStarterValues.dark;
    return new AuroraThemeVariant({
      contract: init.contract,
      appearance: init.appearance,
      values: new Map<AuroraColorToken, unknown>([...base, ...new Map(init.values ?? [])]),
    });
  },
});
