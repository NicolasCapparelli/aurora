// Consumes spec/fixtures/bundle.json and bundle-cases.json exactly as
// packages/aurora/test/bundle_portable_test.dart does.
import { describe, expect, it } from 'vitest';
import {
  AuroraBundle,
  AuroraColorToken,
  AuroraContract,
  AuroraFormatError,
  AuroraRuntime,
  AuroraSelection,
  AuroraTextureRecipe,
  AuroraValidationError,
} from '../src/index.js';
import { type Mutation, mutate, readSpecText } from './fixtures.js';

interface BundleCase {
  name: string;
  mutations: Mutation[];
  appExtensions?: { path: string; description: string }[];
  expected: 'valid' | { category: string; file: string }[];
  values?: Record<'light' | 'dark' | 'texture', Record<string, unknown>>;
}

const fixture = readSpecText('fixtures/bundle.json');
const cases = JSON.parse(readSpecText('fixtures/bundle-cases.json')) as BundleCase[];

describe('portable bundles (bundle-cases.json)', () => {
  for (const scenario of cases) {
    it(scenario.name, () => {
      const bundle = JSON.parse(fixture) as Record<string, unknown>;
      mutate(bundle, scenario.mutations);
      const contract =
        scenario.appExtensions === undefined
          ? undefined
          : new AuroraContract({
              id: 'app',
              extensions: scenario.appExtensions.map(
                (token) => new AuroraColorToken(token.path, { description: token.description }),
              ),
            });
      const report = AuroraBundle.validate(bundle, contract === undefined ? {} : { contract });
      if (scenario.expected === 'valid') {
        expect(report.issues).toEqual([]);
        const contents = report.contents!;
        for (const [where, values] of Object.entries(scenario.values ?? {})) {
          for (const [path, expected] of Object.entries(values)) {
            if (where === 'texture') {
              const token = contents.texture!.contract.tokens.get(path)!;
              expect(AuroraTextureRecipe.encodeValue(contents.texture!.read(token))).toEqual(expected);
            } else {
              const variant = contents.theme.variants.get(where as 'light' | 'dark')!;
              expect(variant.read(variant.contract.tokens.get(path)!).hex).toBe(expected);
            }
          }
        }
      } else {
        expect(report.valid).toBe(false);
        const pairs = new Set(report.issues.map((issue) => `${issue.category}:${issue.file}`));
        expect(pairs).toEqual(new Set(scenario.expected.map((issue) => `${issue.category}:${issue.file}`)));
      }
    });
  }
});

describe('AuroraBundle', () => {
  it('loads into a runtime with the suggested pairing and round-trips through encode', () => {
    const contents = AuroraBundle.load(JSON.parse(fixture));
    expect(contents.pairing).toEqual({ themeId: 'ocean', textureId: 'ocean-soft' });
    const runtime = new AuroraRuntime({
      contract: AuroraBundle.foundationContract,
      themes: [contents.theme],
      textures: [contents.texture!],
      texturePairings: { [contents.pairing!.themeId]: contents.pairing!.textureId },
      initialSelection: new AuroraSelection({ themeId: 'ocean' }),
      fallback: 'reject',
    });
    expect(runtime.state.texture).toBe(contents.texture);
    const encoded = AuroraBundle.encode({
      theme: contents.theme,
      texture: contents.texture!,
      provenance: contents.manifest.provenance,
    });
    expect(JSON.parse(JSON.stringify(encoded))).toEqual(JSON.parse(fixture));
  });

  it('load throws by category', () => {
    const bundle = JSON.parse(fixture) as Record<string, unknown>;
    mutate(bundle, [{ path: ['manifest', 'bundleVersion'], operation: 'set', value: 2 }]);
    expect(() => AuroraBundle.load(bundle)).toThrow(AuroraFormatError);
    const missing = JSON.parse(fixture) as Record<string, unknown>;
    mutate(missing, [{ path: ['files', 'light.tokens.json', 'colors', 'primary'], operation: 'remove' }]);
    expect(() => AuroraBundle.load(missing)).toThrow(AuroraValidationError);
    expect(AuroraBundle.validate(null).issues[0]!.file).toBe('bundle');
  });
});
