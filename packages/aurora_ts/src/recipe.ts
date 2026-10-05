import { AuroraColor } from './color.js';
import { AuroraContract } from './contract.js';
import { AuroraContrastPair } from './contrast.js';
import { AuroraFormatError } from './errors.js';
import {
  AURORA_GENERATION_SCHEMES,
  AURORA_PALETTES,
  AuroraAliasRule,
  type AuroraGenerationScheme,
  AuroraGenerationRequest,
  type AuroraPalette,
  type AuroraTokenRule,
  AuroraToneRule,
} from './generator.js';
import { hasOwn, isFiniteNumber, isJsonObject } from './json.js';
import { type AuroraAppearance, AURORA_APPEARANCES } from './theme.js';
import { AuroraColorToken } from './token.js';

export function recipeMap(value: unknown, field: string): Record<string, unknown> {
  if (!isJsonObject(value)) throw new AuroraFormatError(`${field} must be an object`);
  return value;
}

export function recipeList(value: unknown, field: string): unknown[] {
  if (!Array.isArray(value)) throw new AuroraFormatError(`${field} must be an array`);
  return value;
}

export function recipeText(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new AuroraFormatError(`${field} must be a nonempty string`);
  }
  return value.trim();
}

export function recipeFields(value: Record<string, unknown>, allowed: readonly string[], field: string): void {
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) throw new AuroraFormatError(`Unknown ${field} fields: ${unknown.join(', ')}`);
}

/** Dart `int`: JSON numbers without a fractional part. */
export function isJsonInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

function recipeNumber(value: unknown, field: string): number {
  if (!isFiniteNumber(value)) throw new AuroraFormatError(`${field} must be a finite number`);
  return value;
}

const RECIPE_FIELDS = [
  'schemaVersion',
  'id',
  'name',
  'primary',
  'scheme',
  'secondary',
  'tertiary',
  'success',
  'warning',
  'info',
  'appearance',
  'preferredAppearance',
  'contract',
  'values',
  'variantValues',
  'rules',
  'contrastPairs',
];

/** Portable authoring recipe v1 shared by agents and other generator interfaces. */
export const AuroraRecipe = Object.freeze({
  decode(input: unknown): AuroraGenerationRequest {
    const recipe = recipeMap(input, 'recipe');
    recipeFields(recipe, RECIPE_FIELDS, 'recipe');
    if (recipe['schemaVersion'] !== 1) throw new AuroraFormatError('Expected recipe schemaVersion 1');
    const definition = recipeMap(recipe['contract'] ?? { id: 'aurora-foundation' }, 'contract');
    recipeFields(definition, ['id', 'version', 'extensions'], 'contract');
    const version = definition['version'] ?? 1;
    if (!isJsonInteger(version)) throw new AuroraFormatError('Contract version must be an integer');
    const extensions: AuroraColorToken[] = [];
    for (const item of recipeList(definition['extensions'] ?? [], 'extensions')) {
      const token = recipeMap(item, 'extension');
      recipeFields(token, ['path', 'description'], 'extension');
      extensions.push(
        new AuroraColorToken(recipeText(token['path'], 'path'), {
          description: recipeText(token['description'], 'description'),
        }),
      );
    }
    const contract = new AuroraContract({ id: recipeText(definition['id'], 'contract.id'), version, extensions });
    const token = (path: string): AuroraColorToken => {
      const found = contract.tokens.get(path);
      if (found === undefined) throw new AuroraFormatError(`Undeclared token ${path}`);
      return found;
    };
    const values = (source: unknown): Map<AuroraColorToken, AuroraColor> =>
      new Map(
        Object.entries(recipeMap(source ?? {}, 'values')).map(([path, value]) => [
          token(path),
          AuroraColor.hex(recipeText(value, path)),
        ]),
      );
    const appearance = (value: unknown): AuroraAppearance => {
      const name = recipeText(value, 'appearance');
      if (name !== 'light' && name !== 'dark') throw new AuroraFormatError('Expected light or dark');
      return name;
    };
    const mode = recipe['appearance'] ?? 'both';
    const modes = mode === 'both' ? [...AURORA_APPEARANCES] : [appearance(mode)];
    const rules = new Map<AuroraColorToken, AuroraTokenRule>();
    for (const [path, raw] of Object.entries(recipeMap(recipe['rules'] ?? {}, 'rules'))) {
      const rule = recipeMap(raw, 'rule');
      if (hasOwn(rule, 'alias')) {
        recipeFields(rule, ['alias'], 'alias rule');
        rules.set(token(path), new AuroraAliasRule(token(recipeText(rule['alias'], 'alias'))));
      } else {
        recipeFields(rule, ['palette', 'lightTone', 'darkTone'], 'tone rule');
        const palette = recipeText(rule['palette'], 'palette');
        if (!(AURORA_PALETTES as readonly string[]).includes(palette)) {
          throw new AuroraFormatError(`Unknown palette ${palette}`);
        }
        rules.set(
          token(path),
          new AuroraToneRule({
            palette: palette as AuroraPalette,
            lightTone: recipeNumber(rule['lightTone'], 'lightTone'),
            darkTone: recipeNumber(rule['darkTone'], 'darkTone'),
          }),
        );
      }
    }
    const pairs: AuroraContrastPair[] = [];
    for (const item of recipeList(recipe['contrastPairs'] ?? [], 'contrastPairs')) {
      const pair = recipeMap(item, 'contrast pair');
      recipeFields(pair, ['foreground', 'background', 'minimumRatio'], 'contrast pair');
      pairs.push(
        new AuroraContrastPair({
          foreground: token(recipeText(pair['foreground'], 'foreground')),
          background: token(recipeText(pair['background'], 'background')),
          minimumRatio: recipeNumber(pair['minimumRatio'] ?? 4.5, 'minimumRatio'),
        }),
      );
    }
    const seed = (key: string): AuroraColor | undefined =>
      recipe[key] === undefined || recipe[key] === null || recipe[key] === ''
        ? undefined
        : AuroraColor.hex(recipeText(recipe[key], key));
    const schemeName = hasOwn(recipe, 'scheme') ? recipeText(recipe['scheme'], 'scheme') : 'tonalSpot';
    if (!(AURORA_GENERATION_SCHEMES as readonly string[]).includes(schemeName)) {
      throw new AuroraFormatError(`Unknown scheme ${schemeName}`);
    }
    const variantValues: Partial<Record<AuroraAppearance, Map<AuroraColorToken, AuroraColor>>> = {};
    for (const [name, source] of Object.entries(recipeMap(recipe['variantValues'] ?? {}, 'variantValues'))) {
      variantValues[appearance(name)] = values(source);
    }
    return new AuroraGenerationRequest({
      contract,
      id: recipeText(recipe['id'], 'id'),
      name: recipeText(recipe['name'], 'name'),
      primary: AuroraColor.hex(recipeText(recipe['primary'], 'primary')),
      scheme: schemeName as AuroraGenerationScheme,
      secondary: seed('secondary'),
      tertiary: seed('tertiary'),
      success: seed('success'),
      warning: seed('warning'),
      info: seed('info'),
      appearances: modes,
      preferredAppearance: hasOwn(recipe, 'preferredAppearance') ? appearance(recipe['preferredAppearance']) : modes[0]!,
      values: values(recipe['values']),
      variantValues,
      rules,
      contrastPairs: pairs,
    });
  },
});
