import { AuroraContract } from './contract.js';
import { AuroraDtcg } from './dtcg.js';
import { AuroraError, AuroraFormatError, AuroraValidationError } from './errors.js';
import { hasOwn, isJsonObject, type JsonObject } from './json.js';
import { type AuroraTexture, AuroraTextureContract } from './texture.js';
import { AuroraTextureDtcg } from './textureDtcg.js';
import { type AuroraAppearance, AuroraTheme, type AuroraThemeVariant } from './theme.js';

/** One problem found in a bundle. See `spec/bundle-v1.md`. */
export interface AuroraBundleIssue {
  category: 'format' | 'validation';
  /** `manifest`, `bundle`, or the token file name. */
  file: string;
  message: string;
}

export interface AuroraBundleProvenance {
  /** The producer and its version, such as `tokenseed@0.2.0`. */
  generator: string;
  /** Identifies the source design, such as `sha256:<hex>`. */
  sourceHash: string;
  /** RFC 3339 date-time. */
  createdAt: string;
}

export interface AuroraBundleManifest {
  bundleVersion: 1;
  theme: { id: string; name: string; preferredAppearance: AuroraAppearance; variants: AuroraAppearance[] };
  texture?: { id: string; name: string };
  pairing?: { themeId: string; textureId: string };
  provenance: AuroraBundleProvenance;
}

/** The single-file form: a manifest plus token documents by file name. */
export interface AuroraBundleJson {
  manifest: AuroraBundleManifest;
  files: Record<string, JsonObject>;
}

export interface AuroraBundleContents {
  manifest: AuroraBundleManifest;
  theme: AuroraTheme;
  texture: AuroraTexture | undefined;
  /** The producer's suggested pairing; the app decides whether to register it. */
  pairing: { themeId: string; textureId: string } | undefined;
}

export interface AuroraBundleOptions {
  /** The app's theme contract. Defaults to the shared foundation-only contract. */
  contract?: AuroraContract;
  /** The app's texture contract. Defaults to the shared texture-foundation-only contract. */
  textureContract?: AuroraTextureContract;
}

export interface AuroraBundleReport {
  valid: boolean;
  issues: AuroraBundleIssue[];
  /** Present when the bundle is valid. */
  contents: AuroraBundleContents | undefined;
}

export interface AuroraBundleEncodeInit {
  theme: AuroraTheme;
  texture?: AuroraTexture;
  /** Suggest pairing the theme with the texture. Defaults to true when a texture is given. */
  pair?: boolean;
  provenance: AuroraBundleProvenance;
}

const ID = /^[a-z][a-z0-9_-]{0,79}$/;
const DATE_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
const APPEARANCES: readonly AuroraAppearance[] = ['light', 'dark'];
const TEXTURE_FILE = 'texture.tokens.json';

let foundationContract: AuroraContract | undefined;
let textureFoundationContract: AuroraTextureContract | undefined;

function variantFile(appearance: AuroraAppearance): string {
  return `${appearance}.tokens.json`;
}

function decodeIssues(error: unknown, file: string): AuroraBundleIssue[] {
  if (error instanceof AuroraValidationError || (error instanceof AuroraError && error.category === 'validation')) {
    return (error as AuroraValidationError).issues.map((message) => ({ category: 'validation' as const, file, message }));
  }
  if (error instanceof AuroraError) {
    return [{ category: error.category === 'validation' ? 'validation' : 'format', file, message: error.message }];
  }
  throw error;
}

/** Checks the manifest, collecting issues; returns it when its shape is usable. */
function checkManifest(raw: unknown, issues: AuroraBundleIssue[]): AuroraBundleManifest | undefined {
  const issue = (message: string): void => {
    issues.push({ category: 'format', file: 'manifest', message });
  };
  if (!isJsonObject(raw)) {
    issue('manifest must be an object');
    return undefined;
  }
  const fields = (value: Record<string, unknown>, allowed: string[], at: string): void => {
    const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
    if (unknown.length > 0) issue(`${at} has unsupported fields ${unknown.join(', ')}`);
  };
  const text = (value: unknown, at: string): string | undefined => {
    if (typeof value === 'string' && value.trim() !== '') return value;
    issue(`${at} must be a nonempty string`);
    return undefined;
  };
  const id = (value: unknown, at: string): string | undefined => {
    if (typeof value === 'string' && ID.test(value)) return value;
    issue(`${at} must be 1-80 lowercase letters, digits, _ or -, starting with a letter`);
    return undefined;
  };
  fields(raw, ['bundleVersion', 'theme', 'texture', 'pairing', 'provenance'], 'manifest');
  if (raw['bundleVersion'] !== 1) issue('bundleVersion must be 1');
  let usable = true;

  let theme: AuroraBundleManifest['theme'] | undefined;
  if (!isJsonObject(raw['theme'])) {
    issue('theme must be an object');
    usable = false;
  } else {
    const t = raw['theme'];
    fields(t, ['id', 'name', 'preferredAppearance', 'variants'], 'theme');
    const themeId = id(t['id'], 'theme.id');
    const name = text(t['name'], 'theme.name');
    const variants = t['variants'];
    let list: AuroraAppearance[] | undefined;
    if (
      !Array.isArray(variants) ||
      variants.length === 0 ||
      variants.some((v) => !APPEARANCES.includes(v as AuroraAppearance)) ||
      new Set(variants).size !== variants.length
    ) {
      issue('theme.variants must be a nonempty array of unique light/dark');
    } else {
      list = variants as AuroraAppearance[];
    }
    const preferred = t['preferredAppearance'];
    if (list !== undefined && !list.includes(preferred as AuroraAppearance)) {
      issue('theme.preferredAppearance must be one of theme.variants');
    }
    if (themeId !== undefined && name !== undefined && list !== undefined && list.includes(preferred as AuroraAppearance)) {
      theme = { id: themeId, name, preferredAppearance: preferred as AuroraAppearance, variants: list };
    } else {
      usable = false;
    }
  }

  let texture: AuroraBundleManifest['texture'];
  if (hasOwn(raw, 'texture')) {
    if (!isJsonObject(raw['texture'])) {
      issue('texture must be an object');
      usable = false;
    } else {
      fields(raw['texture'], ['id', 'name'], 'texture');
      const textureId = id(raw['texture']['id'], 'texture.id');
      const name = text(raw['texture']['name'], 'texture.name');
      if (textureId !== undefined && name !== undefined) texture = { id: textureId, name };
      else usable = false;
    }
  }

  let pairing: AuroraBundleManifest['pairing'];
  if (hasOwn(raw, 'pairing')) {
    const p = raw['pairing'];
    if (!isJsonObject(p)) {
      issue('pairing must be an object');
    } else {
      fields(p, ['themeId', 'textureId'], 'pairing');
      if (!hasOwn(raw, 'texture')) issue('pairing needs a texture');
      if (theme !== undefined && p['themeId'] !== theme.id) issue('pairing.themeId must equal theme.id');
      if (texture !== undefined && p['textureId'] !== texture.id) issue('pairing.textureId must equal texture.id');
      if (typeof p['themeId'] === 'string' && typeof p['textureId'] === 'string') {
        pairing = { themeId: p['themeId'], textureId: p['textureId'] };
      }
    }
  }

  let provenance: AuroraBundleProvenance | undefined;
  if (!isJsonObject(raw['provenance'])) {
    issue('provenance must be an object');
  } else {
    const p = raw['provenance'];
    fields(p, ['generator', 'sourceHash', 'createdAt'], 'provenance');
    const generator = text(p['generator'], 'provenance.generator');
    const sourceHash = text(p['sourceHash'], 'provenance.sourceHash');
    const createdAt = p['createdAt'];
    if (typeof createdAt !== 'string' || !DATE_TIME.test(createdAt)) {
      issue('provenance.createdAt must be an RFC 3339 date-time');
    } else if (generator !== undefined && sourceHash !== undefined) {
      provenance = { generator, sourceHash, createdAt };
    }
  }
  if (!usable || theme === undefined || provenance === undefined) return undefined;
  return {
    bundleVersion: 1,
    theme,
    ...(texture === undefined ? {} : { texture }),
    ...(pairing === undefined ? {} : { pairing }),
    provenance,
  };
}

/** Portable bundle v1: decode, validate and produce. See `spec/bundle-v1.md`. */
export const AuroraBundle = Object.freeze({
  /** The shared foundation-only theme contract used when no app contract is given. */
  get foundationContract(): AuroraContract {
    foundationContract ??= new AuroraContract({ id: 'aurora-foundation' });
    return foundationContract;
  },

  /** The shared texture-foundation-only contract used when no app texture contract is given. */
  get textureFoundationContract(): AuroraTextureContract {
    textureFoundationContract ??= new AuroraTextureContract({ id: 'aurora-texture-foundation' });
    return textureFoundationContract;
  },

  /**
   * Validates a single-file bundle object (or a folder loaded into one) and
   * reports every issue. Never throws for invalid input.
   */
  validate(input: unknown, options: AuroraBundleOptions = {}): AuroraBundleReport {
    const contract = options.contract ?? AuroraBundle.foundationContract;
    const textureContract = options.textureContract ?? AuroraBundle.textureFoundationContract;
    const issues: AuroraBundleIssue[] = [];
    const fail = (): AuroraBundleReport => ({ valid: false, issues, contents: undefined });
    if (!isJsonObject(input)) {
      issues.push({ category: 'format', file: 'bundle', message: 'A bundle must be an object with manifest and files' });
      return fail();
    }
    for (const key of Object.keys(input)) {
      if (key !== 'manifest' && key !== 'files') {
        issues.push({ category: 'format', file: 'bundle', message: `Unsupported bundle field ${key}` });
      }
    }
    const manifest = checkManifest(input['manifest'], issues);
    const files = input['files'];
    if (!isJsonObject(files)) {
      issues.push({ category: 'format', file: 'bundle', message: 'files must be an object of token documents' });
      return fail();
    }
    const expected = new Set<string>();
    if (manifest !== undefined) {
      for (const appearance of manifest.theme.variants) expected.add(variantFile(appearance));
      if (manifest.texture !== undefined) expected.add(TEXTURE_FILE);
      for (const name of expected) {
        if (!hasOwn(files, name)) {
          issues.push({ category: 'format', file: name, message: `${name} is listed by the manifest but missing` });
        }
      }
      for (const name of Object.keys(files)) {
        if (!expected.has(name)) {
          issues.push({ category: 'format', file: name, message: `${name} is not listed by the manifest` });
        }
      }
    }
    const variants: AuroraThemeVariant[] = [];
    for (const appearance of APPEARANCES) {
      const name = variantFile(appearance);
      if (!hasOwn(files, name) || (manifest !== undefined && !expected.has(name))) continue;
      try {
        variants.push(AuroraDtcg.decode(files[name], { contract, appearance }));
      } catch (error) {
        issues.push(...decodeIssues(error, name));
      }
    }
    let texture: AuroraTexture | undefined;
    if (hasOwn(files, TEXTURE_FILE) && (manifest === undefined || expected.has(TEXTURE_FILE))) {
      try {
        texture = AuroraTextureDtcg.decode(files[TEXTURE_FILE], {
          contract: textureContract,
          id: manifest?.texture?.id ?? 'texture',
          name: manifest?.texture?.name ?? 'Texture',
        });
        texture.validateColors(contract);
      } catch (error) {
        texture = undefined;
        issues.push(...decodeIssues(error, TEXTURE_FILE));
      }
    }
    if (issues.length > 0 || manifest === undefined) return fail();
    const theme = new AuroraTheme({
      id: manifest.theme.id,
      name: manifest.theme.name,
      preferredAppearance: manifest.theme.preferredAppearance,
      variants,
    });
    return { valid: true, issues, contents: { manifest, theme, texture, pairing: manifest.pairing } };
  },

  /**
   * Validates and returns the bundle's theme, texture and pairing. Throws an
   * `AuroraFormatError` when any issue is a format issue, otherwise an
   * `AuroraValidationError` listing every issue as `file: message`.
   */
  load(input: unknown, options: AuroraBundleOptions = {}): AuroraBundleContents {
    const report = AuroraBundle.validate(input, options);
    if (report.contents !== undefined) return report.contents;
    const lines = report.issues.map((issue) => `${issue.file}: ${issue.message}`);
    if (report.issues.some((issue) => issue.category === 'format')) throw new AuroraFormatError(lines.join('\n'));
    throw new AuroraValidationError(lines);
  },

  /** Assembles the single-file form from a folder's `manifest.json` and token files. */
  fromFolder(manifest: unknown, files: Record<string, unknown>): unknown {
    return { manifest, files };
  },

  /** Produces a single-file bundle from a theme and an optional texture. */
  encode(init: AuroraBundleEncodeInit): AuroraBundleJson {
    const { theme, texture } = init;
    const variants = APPEARANCES.filter((appearance) => theme.variants.has(appearance));
    const files: Record<string, JsonObject> = {};
    for (const appearance of variants) files[variantFile(appearance)] = AuroraDtcg.encode(theme.variants.get(appearance)!);
    if (texture !== undefined) files[TEXTURE_FILE] = AuroraTextureDtcg.encode(texture);
    const pair = texture !== undefined && (init.pair ?? true);
    return {
      manifest: {
        bundleVersion: 1,
        theme: { id: theme.id, name: theme.name, preferredAppearance: theme.preferredAppearance, variants },
        ...(texture === undefined ? {} : { texture: { id: texture.id, name: texture.name } }),
        ...(pair ? { pairing: { themeId: theme.id, textureId: texture!.id } } : {}),
        provenance: { ...init.provenance },
      },
      files,
    };
  },
});
