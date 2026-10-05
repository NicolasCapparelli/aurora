import { type AuroraColor, isAuroraColor } from './color.js';
import { type AuroraContract, TOKEN_PATH } from './contract.js';
import { AuroraArgumentError, AuroraValidationError } from './errors.js';
import { AuroraFoundation } from './foundation.js';
import { AuroraLiteral, type AuroraRef, isAlias, isLiteral } from './ref.js';
import { auroraMaterialTextureValues, AuroraTextureFoundation } from './textureFoundation.js';
import type { AuroraThemeVariant, AuroraValues } from './theme.js';
import type { AuroraAnyToken, AuroraEnumToken, AuroraToken, AuroraTokenType } from './token.js';
import {
  AuroraBorder,
  type AuroraCubicBezier,
  type AuroraDimension,
  type AuroraDimensionUnit,
  type AuroraFontFamily,
  type AuroraFontWeight,
  AuroraShadow,
  AuroraShadowLayer,
  AuroraStrokeStyle,
  AuroraTypography,
  isKind,
} from './values.js';

export interface AuroraTextureContractInit {
  id: string;
  version?: number;
  extensions?: Iterable<AuroraToken<unknown>>;
}

const foundationTokens = new Set<AuroraToken<unknown>>(AuroraTextureFoundation.tokens);
const foundationColorPaths = new Set(AuroraFoundation.tokens.map((token) => token.path));

/**
 * Texture foundation plus app-owned additions. Every declared token is required.
 *
 * Textures hold non-colour values (type, shape, motion, lines, density, chrome
 * and component defaults). Colours belong to theme contracts, so a texture
 * contract never declares colour tokens; borders and shadows refer to theme
 * colour tokens with `AuroraAlias` instead.
 */
export class AuroraTextureContract {
  readonly id: string;
  readonly version: number;
  readonly tokens: ReadonlyMap<string, AuroraToken<unknown>>;

  constructor(init: AuroraTextureContractInit) {
    const version = init.version ?? 1;
    if (init.id.trim() === '' || !Number.isInteger(version) || version < 1) {
      throw new AuroraArgumentError('Texture contract needs a nonempty id and a positive version');
    }
    const tokens = new Map<string, AuroraToken<unknown>>();
    for (const token of [...AuroraTextureFoundation.tokens, ...(init.extensions ?? [])]) {
      const foundation = foundationTokens.has(token);
      if (!TOKEN_PATH.test(token.path) || token.description.trim() === '') {
        throw new AuroraArgumentError(`Token ${token.path} needs a valid dotted path and description`);
      }
      if (token.type === 'color') {
        throw new AuroraArgumentError(
          `Colour tokens belong to theme contracts; alias theme colours from texture values instead: ${token.path}`,
        );
      }
      if (tokens.has(token.path)) {
        throw new AuroraArgumentError(`Duplicate or redefined token: ${token.path}`);
      }
      if (!foundation && AuroraTextureFoundation.namespaces.some((root) => token.path.startsWith(`${root}.`))) {
        throw new AuroraArgumentError(`The ${token.path.split('.')[0]} namespace belongs to Aurora: ${token.path}`);
      }
      for (const path of tokens.keys()) {
        if (path.startsWith(`${token.path}.`) || token.path.startsWith(`${path}.`)) {
          throw new AuroraArgumentError(`Token/group path collision: ${token.path}`);
        }
      }
      if (token.type === 'enum') {
        const values = (token as AuroraEnumToken).values;
        if (values.length === 0 || values.some((value) => value.trim() === '') || new Set(values).size !== values.length) {
          throw new AuroraArgumentError(`Enum token ${token.path} needs unique nonempty values`);
        }
      }
      tokens.set(token.path, token);
    }
    this.id = init.id;
    this.version = version;
    this.tokens = tokens;
    Object.freeze(this);
  }

  /** True when [token] is this contract's declaration (by identity). */
  contains(token: AuroraToken<unknown>): boolean {
    return this.tokens.get(token.path) === token;
  }
}

export interface AuroraTextureInit {
  contract: AuroraTextureContract;
  id: string;
  name: string;
  /**
   * Values are the token's value type, an `AuroraLiteral` of it, or an
   * `AuroraAlias` to another token of the same type in this contract.
   */
  values: AuroraValues<AuroraToken<unknown>, unknown>;
}

/**
 * A named, complete, validated set of texture values. A texture has one value
 * set shared by every appearance; its colours alias theme colour tokens and
 * therefore follow the active theme variant.
 */
export class AuroraTexture {
  readonly contract: AuroraTextureContract;
  readonly id: string;
  readonly name: string;
  /** Paths of every theme colour token this texture's values refer to. */
  readonly colorReferences: ReadonlySet<string>;
  private readonly authoredValues: ReadonlyMap<string, unknown>;
  private readonly resolvedValues: ReadonlyMap<string, unknown>;

  /**
   * Validates every value against its token type, resolves aliases, and
   * reports all problems in one `AuroraValidationError`.
   */
  constructor(init: AuroraTextureInit) {
    if (init.id.trim() === '' || init.name.trim() === '') {
      throw new AuroraArgumentError('Texture id and name cannot be empty');
    }
    const resolver = new TextureResolver(init.contract, new Map(init.values));
    const resolved = resolver.run();
    if (resolver.issues.length > 0) throw new AuroraValidationError(resolver.issues);
    this.contract = init.contract;
    this.id = init.id;
    this.name = init.name;
    this.authoredValues = resolver.authored;
    this.resolvedValues = resolved;
    this.colorReferences = resolver.colorReferences;
    Object.freeze(this);
  }

  /**
   * The resolved value of [token]. Composite colours may still be aliases to
   * theme colour tokens; resolve those with `resolveTextureColor`.
   */
  read<T>(token: AuroraToken<T>): T {
    if (!this.contract.contains(token)) {
      throw new AuroraArgumentError(`Token ${token.path} is not in this texture contract`);
    }
    return this.resolvedValues.get(token.path) as T;
  }

  /** The value as authored, keeping aliases, for export. */
  authored(token: AuroraToken<unknown>): unknown {
    if (!this.contract.contains(token)) {
      throw new AuroraArgumentError(`Token ${token.path} is not in this texture contract`);
    }
    return this.authoredValues.get(token.path);
  }

  /**
   * Fails unless every colour this texture refers to is a colour token of
   * [themeContract]. Runtimes and adapters call this when pairing textures
   * with themes.
   */
  validateColors(themeContract: AuroraContract): void {
    const missing = [...this.colorReferences]
      .filter((path) => !themeContract.tokens.has(path))
      .map((path) => `Texture ${this.id} refers to ${path}, which theme contract ${themeContract.id} does not declare`);
    if (missing.length > 0) throw new AuroraValidationError(missing);
  }
}

/** Resolve a texture colour (a literal or a theme colour alias) against a theme variant. */
export function resolveTextureColor(variant: AuroraThemeVariant, color: AuroraRef<AuroraColor>): AuroraColor {
  if (isAuroraColor(color)) return color;
  if (isLiteral(color)) return color.value;
  if (isAlias(color)) {
    const token = variant.contract.tokens.get(color.target.path);
    if (token === undefined) {
      throw new AuroraArgumentError(`Theme contract ${variant.contract.id} has no colour ${color.target.path}`);
    }
    return variant.read(token);
  }
  throw new AuroraArgumentError(`Unsupported colour reference ${String(color)}`);
}

export interface AuroraTextureStarterInit {
  contract: AuroraTextureContract;
  id: string;
  name: string;
  /** Overrides of foundation tokens, plus every app extension. */
  values?: AuroraValues<AuroraToken<unknown>, unknown>;
}

/** Explicit starter texture values. App extensions are still required. */
export const AuroraTextureStarter = Object.freeze({
  /** Material 3 baseline values for every texture foundation token. */
  material: auroraMaterialTextureValues,

  /** A complete texture: the Material starter values plus [values]. */
  texture(init: AuroraTextureStarterInit): AuroraTexture {
    return new AuroraTexture({
      contract: init.contract,
      id: init.id,
      name: init.name,
      values: new Map<AuroraToken<unknown>, unknown>([...auroraMaterialTextureValues, ...new Map(init.values ?? [])]),
    });
  },
});

/** DTCG writes dp as px with a token-level marker, so one token cannot hold both units. */
function mixesPixelUnits(value: unknown): boolean {
  const units = new Set<AuroraDimensionUnit>();
  const add = (ref: unknown): void => {
    if (isKind(ref, 'dimension')) units.add(ref.unit);
    if (isKind(ref, 'strokeStyle')) ref.dashArrayRefs?.forEach(add);
  };
  if (isKind(value, 'strokeStyle')) {
    add(value);
  } else if (isKind(value, 'border')) {
    add(value.widthRef);
    add(value.styleRef);
  } else if (isKind(value, 'shadow')) {
    for (const layer of value.layers) {
      add(layer.offsetXRef);
      add(layer.offsetYRef);
      add(layer.blurRef);
      add(layer.spreadRef);
    }
  } else if (isKind(value, 'typography')) {
    add(value.fontSizeRef);
    add(value.letterSpacingRef);
  }
  return units.has('dp') && units.has('px');
}

/** Field kinds for composite aliases: a token of the field's type. */
const FIELD_TYPES = {
  dimension: 'dimension',
  strokeStyle: 'strokeStyle',
  fontFamily: 'fontFamily',
  fontWeight: 'fontWeight',
  number: 'number',
} as const satisfies Record<string, AuroraTokenType>;

class TextureResolver {
  readonly authored = new Map<string, unknown>();
  readonly issues: string[] = [];
  readonly colorReferences = new Set<string>();
  private readonly resolved = new Map<string, unknown>();
  private readonly visiting = new Set<string>();

  constructor(
    private readonly contract: AuroraTextureContract,
    values: Map<AuroraToken<unknown>, unknown>,
  ) {
    for (const [token, entry] of values) {
      if (!contract.contains(token)) {
        this.issues.push(`Undeclared token ${token.path}`);
        continue;
      }
      const value = isLiteral(entry) ? entry.value : entry;
      this.authored.set(token.path, value);
    }
    for (const token of contract.tokens.values()) {
      if (!this.authored.has(token.path)) this.issues.push(`Missing required token ${token.path}`);
    }
  }

  run(): Map<string, unknown> {
    for (const token of this.contract.tokens.values()) {
      if (this.authored.has(token.path)) this.resolve(token as AuroraAnyToken);
    }
    const result = new Map<string, unknown>();
    for (const [path, value] of this.resolved) {
      if (value !== undefined) result.set(path, value);
    }
    return result;
  }

  private resolve(token: AuroraAnyToken): unknown {
    if (this.resolved.has(token.path)) return this.resolved.get(token.path);
    if (this.visiting.has(token.path)) {
      this.issues.push(`Cyclic token alias at ${token.path}`);
      return undefined;
    }
    this.visiting.add(token.path);
    const value = this.authored.get(token.path);
    let result: unknown;
    if (value === undefined || value === null) {
      result = undefined;
    } else if (isAlias(value)) {
      result = this.aliasTarget(token.type, value.target, token.path);
    } else {
      result = this.literal(token, value);
      if (result !== undefined && mixesPixelUnits(value)) {
        this.issues.push(`${token.path} mixes dp and px; use one pixel unit per token`);
        result = undefined;
      }
    }
    if (result !== undefined && token.type === 'enum' && !token.values.includes(result as string)) {
      this.issues.push(`${token.path} must be one of ${token.values.join(', ')}`);
      result = undefined;
    }
    this.visiting.delete(token.path);
    this.resolved.set(token.path, result);
    return result;
  }

  private aliasTarget(expected: AuroraTokenType, target: AuroraToken<unknown>, at: string): unknown {
    if (!this.contract.contains(target)) {
      this.issues.push(`${at} aliases undeclared token ${target.path}`);
      return undefined;
    }
    if (target.type !== expected) {
      this.issues.push(`${at} must alias a ${expected} token, not ${target.type} ${target.path}`);
      return undefined;
    }
    return this.resolve(target as AuroraAnyToken);
  }

  private literal(token: AuroraAnyToken, value: unknown): unknown {
    const at = token.path;
    switch (token.type) {
      case 'dimension':
        return isKind(value, 'dimension') ? this.dimension(value, at) : this.wrongType(at, 'an AuroraDimension');
      case 'number':
        if (typeof value !== 'number') return this.wrongType(at, 'a number');
        return this.finite(value, at);
      case 'fontFamily':
        return isKind(value, 'fontFamily') ? this.family(value, at) : this.wrongType(at, 'an AuroraFontFamily');
      case 'fontWeight':
        return isKind(value, 'fontWeight') ? this.weight(value, at) : this.wrongType(at, 'an AuroraFontWeight');
      case 'duration':
        if (!isKind(value, 'duration')) return this.wrongType(at, 'an AuroraDuration');
        if (value.isNegative) {
          this.issues.push(`${at} must not be negative`);
          return undefined;
        }
        return value;
      case 'cubicBezier':
        return isKind(value, 'cubicBezier') ? this.bezier(value, at) : this.wrongType(at, 'an AuroraCubicBezier');
      case 'strokeStyle':
        return isKind(value, 'strokeStyle') ? this.stroke(value, at) : this.wrongType(at, 'an AuroraStrokeStyle');
      case 'border':
        return isKind(value, 'border') ? this.border(value, at) : this.wrongType(at, 'an AuroraBorder');
      case 'shadow':
        return isKind(value, 'shadow') ? this.shadow(value, at) : this.wrongType(at, 'an AuroraShadow');
      case 'typography':
        return isKind(value, 'typography') ? this.typography(value, at) : this.wrongType(at, 'an AuroraTypography');
      case 'boolean':
        return typeof value === 'boolean' ? value : this.wrongType(at, 'a boolean');
      case 'enum':
        return typeof value === 'string' ? value : this.wrongType(at, 'a string');
      case 'color':
        this.issues.push(`${at}: colour tokens belong to theme contracts`);
        return undefined;
    }
  }

  private wrongType(at: string, expected: string): undefined {
    this.issues.push(`${at} must be ${expected}`);
    return undefined;
  }

  private finite(value: number, at: string): number | undefined {
    if (Number.isFinite(value)) return value;
    this.issues.push(`${at} must be finite`);
    return undefined;
  }

  /** Resolves a composite field: a literal, or an alias to a contract token. */
  private field<X>(ref: unknown, at: string, kind: AuroraTokenType, check: (value: X, at: string) => X | undefined): X | undefined {
    if (isAlias(ref)) return this.aliasTarget(kind, ref.target, at) as X | undefined;
    const value = (isLiteral(ref) ? ref.value : ref) as X;
    return check(value, at);
  }

  private dimensionField(ref: unknown, at: string, nonNegative = false): AuroraDimension | undefined {
    return this.field<AuroraDimension>(ref, at, FIELD_TYPES.dimension, (value, where) => {
      if (!isKind(value, 'dimension')) return this.wrongType(where, 'an AuroraDimension');
      const dimension = this.dimension(value, where);
      if (dimension !== undefined && nonNegative && dimension.value < 0) {
        this.issues.push(`${where} must not be negative`);
        return undefined;
      }
      return dimension;
    });
  }

  private dimension(value: AuroraDimension, at: string): AuroraDimension | undefined {
    if (Number.isFinite(value.value)) return value;
    this.issues.push(`${at} must be finite`);
    return undefined;
  }

  private family(value: AuroraFontFamily, at: string): AuroraFontFamily | undefined {
    if (value.names.length === 0 || value.names.some((name) => name.trim() === '')) {
      this.issues.push(`${at} needs at least one nonempty font family name`);
      return undefined;
    }
    return value;
  }

  private weight(value: AuroraFontWeight, at: string): AuroraFontWeight | undefined {
    if (!Number.isInteger(value.value) || value.value < 1 || value.value > 1000) {
      this.issues.push(`${at} must be a font weight in [1, 1000]`);
      return undefined;
    }
    return value;
  }

  private bezier(value: AuroraCubicBezier, at: string): AuroraCubicBezier | undefined {
    const points = [value.x1, value.y1, value.x2, value.y2];
    if (points.some((p) => !Number.isFinite(p)) || value.x1 < 0 || value.x1 > 1 || value.x2 < 0 || value.x2 > 1) {
      this.issues.push(`${at} needs finite control points with x in [0, 1]`);
      return undefined;
    }
    return value;
  }

  private stroke(value: AuroraStrokeStyle, at: string): AuroraStrokeStyle | undefined {
    const dashes = value.dashArrayRefs;
    if (dashes === undefined) return value;
    if (dashes.length === 0) {
      this.issues.push(`${at} needs at least one dash length`);
      return undefined;
    }
    if (dashes.every((dash) => isKind(dash, 'dimension') && dash.value === 0)) {
      this.issues.push(`${at} draws nothing; use AuroraStrokeStyle.none`);
      return undefined;
    }
    const resolved = dashes.map((dash, i) => this.dimensionField(dash, `${at}.dashArray[${i}]`, true));
    if (resolved.includes(undefined)) return undefined;
    return AuroraStrokeStyle.dashes(resolved as AuroraDimension[], value.lineCap!);
  }

  private color(ref: AuroraRef<AuroraColor>, at: string): AuroraRef<AuroraColor> | undefined {
    if (isAuroraColor(ref)) return ref;
    if (isLiteral(ref)) {
      if (isAuroraColor(ref.value)) return ref.value;
      this.issues.push(`${at} must be a colour or a theme colour alias`);
      return undefined;
    }
    if (isAlias(ref)) {
      const target = ref.target as AuroraToken<unknown>;
      if (target.type !== 'color') {
        this.issues.push(`${at} must alias a theme colour token`);
        return undefined;
      }
      if (target.path.startsWith('colors.') && !foundationColorPaths.has(target.path)) {
        this.issues.push(`${at} refers to unknown foundation colour ${target.path}`);
        return undefined;
      }
      this.colorReferences.add(target.path);
      return ref;
    }
    this.issues.push(`${at} must be a colour or a theme colour alias`);
    return undefined;
  }

  private border(value: AuroraBorder, at: string): AuroraBorder | undefined {
    const color = this.color(value.color, `${at}.color`);
    const width = this.dimensionField(value.widthRef, `${at}.width`, true);
    const style = this.field<AuroraStrokeStyle>(value.styleRef, `${at}.style`, FIELD_TYPES.strokeStyle, (v, where) =>
      isKind(v, 'strokeStyle') ? this.stroke(v, where) : this.wrongType(where, 'an AuroraStrokeStyle'),
    );
    if (color === undefined || width === undefined || style === undefined) return undefined;
    return new AuroraBorder({ color, width, style });
  }

  private shadow(value: AuroraShadow, at: string): AuroraShadow | undefined {
    const layers: AuroraShadowLayer[] = [];
    let valid = true;
    value.layers.forEach((layer, i) => {
      const where = `${at}[${i}]`;
      const color = this.color(layer.color, `${where}.color`);
      const x = this.dimensionField(layer.offsetXRef, `${where}.offsetX`);
      const y = this.dimensionField(layer.offsetYRef, `${where}.offsetY`);
      const blur = this.dimensionField(layer.blurRef, `${where}.blur`, true);
      const spread = this.dimensionField(layer.spreadRef, `${where}.spread`);
      if (color === undefined || x === undefined || y === undefined || blur === undefined || spread === undefined) {
        valid = false;
        return;
      }
      layers.push(new AuroraShadowLayer({ color, offsetX: x, offsetY: y, blur, spread, inset: layer.inset }));
    });
    return valid ? new AuroraShadow(layers) : undefined;
  }

  private typography(value: AuroraTypography, at: string): AuroraTypography | undefined {
    const family = this.field<AuroraFontFamily>(value.fontFamilyRef, `${at}.fontFamily`, FIELD_TYPES.fontFamily, (v, where) =>
      isKind(v, 'fontFamily') ? this.family(v, where) : this.wrongType(where, 'an AuroraFontFamily'),
    );
    const size = this.field<AuroraDimension>(value.fontSizeRef, `${at}.fontSize`, FIELD_TYPES.dimension, (v, where) => {
      if (!isKind(v, 'dimension')) return this.wrongType(where, 'an AuroraDimension');
      const dimension = this.dimension(v, where);
      if (dimension !== undefined && dimension.value <= 0) {
        this.issues.push(`${where} must be positive`);
        return undefined;
      }
      return dimension;
    });
    const weight = this.field<AuroraFontWeight>(value.fontWeightRef, `${at}.fontWeight`, FIELD_TYPES.fontWeight, (v, where) =>
      isKind(v, 'fontWeight') ? this.weight(v, where) : this.wrongType(where, 'an AuroraFontWeight'),
    );
    const spacing = this.dimensionField(value.letterSpacingRef, `${at}.letterSpacing`);
    const height = this.field<number>(value.lineHeightRef, `${at}.lineHeight`, FIELD_TYPES.number, (v, where) => {
      if (typeof v !== 'number' || !Number.isFinite(v) || v <= 0) {
        this.issues.push(`${where} must be a positive finite number`);
        return undefined;
      }
      return v;
    });
    if (family === undefined || size === undefined || weight === undefined || spacing === undefined || height === undefined) {
      return undefined;
    }
    return new AuroraTypography({
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      lineHeight: new AuroraLiteral(height),
    });
  }
}
