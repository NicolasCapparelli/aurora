// Consumes spec/fixtures exactly as the Dart portable tests do
// (portable_test.dart, generation_portable_test.dart, scheme_portable_test.dart,
// texture_portable_test.dart). Never edit an expected fixture to make these pass.
import { describe, expect, it } from 'vitest';
import {
  type AuroraAppearance,
  AuroraColor,
  AuroraColorToken,
  AuroraContract,
  AuroraDtcg,
  AuroraFormatError,
  AuroraFoundation,
  AuroraGenerationRequest,
  AuroraGenerator,
  AuroraRecipe,
  AuroraTextureDtcg,
  AuroraTextureFoundation,
  AuroraTextureRecipe,
  AuroraTextureStarter,
  AuroraTokens,
  AuroraValidationError,
  type AuroraTexture,
} from '../src/index.js';
import { mutate, readSpec, readSpecText, type Scenario } from './fixtures.js';

function expectCategory(run: () => unknown, category: 'validation' | 'format'): void {
  let error: unknown;
  try {
    run();
  } catch (caught) {
    error = caught;
  }
  expect(error, 'expected an error').toBeDefined();
  expect(error).toBeInstanceOf(category === 'validation' ? AuroraValidationError : AuroraFormatError);
}

describe('foundation-v1.json', () => {
  it('matches the generated foundation', () => {
    const spec = readSpec<{ version: number; namespace: string; tokens: { path: string; type: string; description: string }[] }>(
      'foundation-v1.json',
    );
    expect(spec.version).toBe(AuroraFoundation.version);
    expect(spec.tokens).toEqual(
      AuroraFoundation.tokens.map((token) => ({ path: token.path, type: token.type, description: token.description })),
    );
  });
});

describe('portable conformance (variant-cases.json)', () => {
  const ticket = new AuroraColorToken('demo.ticket', { description: 'Ticket background.' });
  const contract = new AuroraContract({ id: 'portable-demo', extensions: [ticket] });
  for (const scenario of readSpec<Scenario[]>('fixtures/variant-cases.json')) {
    it(scenario.name, () => {
      const document = JSON.parse(readSpecText('fixtures/light.tokens.json')) as Record<string, unknown>;
      mutate(document, scenario.mutations);
      const decode = () => AuroraDtcg.decode(document, { contract, appearance: 'light' });
      switch (scenario.expected) {
        case 'valid': {
          const variant = decode();
          const tokens = variant.tokens;
          expect(tokens).toBeInstanceOf(AuroraTokens);
          for (const [path, hex] of Object.entries(scenario.values!)) {
            expect(tokens.read(contract.tokens.get(path)!).hex).toBe(hex);
          }
          expect(tokens.primary).toBe(variant.colors.primary);
          break;
        }
        default:
          expectCategory(decode, scenario.expected);
      }
    });
  }
});

interface GenerationCase {
  input: {
    name: string;
    primary: string;
    secondary?: string;
    tertiary?: string;
    appearances: AuroraAppearance[];
    preferredAppearance: AuroraAppearance;
  };
  values: Record<string, Record<string, string>>;
  contrast: { appearance: string; foreground: string; background: string; minimumRatio: number; ratio: number; status: string }[];
}

describe('portable generation (generation-v1.json)', () => {
  const fixture = readSpec<{ algorithm: string; cases: GenerationCase[] }>('fixtures/generation-v1.json');
  it('declares the supported algorithm', () => {
    expect(fixture.algorithm).toBe(AuroraGenerator.algorithm);
  });
  const contract = new AuroraContract({ id: 'generation-fixture' });
  for (const scenario of fixture.cases) {
    const input = scenario.input;
    it(input.name, () => {
      const result = AuroraGenerator.generate(
        new AuroraGenerationRequest({
          contract,
          id: input.name,
          name: input.name,
          primary: AuroraColor.hex(input.primary),
          secondary: input.secondary === undefined ? undefined : AuroraColor.hex(input.secondary),
          tertiary: input.tertiary === undefined ? undefined : AuroraColor.hex(input.tertiary),
          appearances: input.appearances,
          preferredAppearance: input.preferredAppearance,
        }),
      );
      expect([...result.theme.variants.keys()]).toEqual(Object.keys(scenario.values));
      for (const [appearance, expected] of Object.entries(scenario.values)) {
        const variant = result.theme.variants.get(appearance as AuroraAppearance)!;
        expect(variant.values.size).toBe(Object.keys(expected).length);
        const actual = Object.fromEntries([...contract.tokens.values()].map((token) => [token.path, variant.read(token).hex]));
        expect(actual).toEqual(expected);
      }
      expect(result.checks.length).toBe(scenario.contrast.length);
      scenario.contrast.forEach((expected, i) => {
        const actual = result.checks[i]!.toJson();
        for (const key of ['appearance', 'foreground', 'background', 'minimumRatio', 'status'] as const) {
          expect(actual[key]).toEqual(expected[key]);
        }
        expect(actual.ratio).toBeCloseTo(expected.ratio, 6);
      });
    });
  }
});

describe('portable additional schemes (generation-schemes-v1.json)', () => {
  const fixture = readSpec<{ cases: { input: Record<string, unknown>; algorithm: string; values: unknown }[] }>(
    'fixtures/generation-schemes-v1.json',
  );
  for (const scenario of fixture.cases) {
    it(String(scenario.input['scheme']), () => {
      const result = AuroraGenerator.generate(AuroraRecipe.decode(scenario.input));
      expect(result.algorithm).toBe(scenario.algorithm);
      const actual = Object.fromEntries(
        [...result.theme.variants].map(([appearance, variant]) => [
          appearance,
          Object.fromEntries([...variant.values].map(([token, color]) => [token.path, color.hex])),
        ]),
      );
      expect(actual).toEqual(scenario.values);
    });
  }
});

describe('portable textures', () => {
  const recipe = readSpec<Record<string, unknown>>('fixtures/texture-recipe.json');
  const contract = AuroraTextureRecipe.decodeContract(recipe['contract']);
  const fixture = readSpecText('fixtures/texture.tokens.json');
  const decode = (document: unknown): AuroraTexture =>
    AuroraTextureDtcg.decode(document, { contract, id: 'portable-soft', name: 'Portable Soft' });

  it('texture-foundation-v1.json matches the generated foundation and starter', () => {
    const spec = readSpec<{
      version: number;
      namespaces: string[];
      tokens: { path: string; type: string; description: string; starter: unknown }[];
    }>('texture-foundation-v1.json');
    expect(spec.version).toBe(AuroraTextureFoundation.version);
    expect(spec.namespaces).toEqual(AuroraTextureFoundation.namespaces);
    expect(spec.tokens.map((t) => t.path)).toEqual(AuroraTextureFoundation.tokens.map((t) => t.path));
    AuroraTextureFoundation.tokens.forEach((token, i) => {
      expect(spec.tokens[i]!.type).toBe(token.type);
      expect(spec.tokens[i]!.description).toBe(token.description);
      expect(AuroraTextureRecipe.encodeValue(AuroraTextureStarter.material.get(token))).toEqual(spec.tokens[i]!.starter);
    });
  });

  it('the recipe fixture builds the token fixture exactly', () => {
    const fromRecipe = AuroraTextureRecipe.decode(recipe, contract);
    const document = JSON.parse(fixture) as unknown;
    expect(JSON.parse(JSON.stringify(AuroraTextureDtcg.encode(fromRecipe)))).toEqual(document);
    expect(AuroraTextureDtcg.encode(decode(document))).toEqual(AuroraTextureDtcg.encode(fromRecipe));
  });

  for (const scenario of readSpec<Scenario[]>('fixtures/texture-cases.json')) {
    it(`conformance: ${scenario.name}`, () => {
      const document = JSON.parse(fixture) as Record<string, unknown>;
      mutate(document, scenario.mutations);
      switch (scenario.expected) {
        case 'valid': {
          const texture = decode(document);
          for (const [path, expected] of Object.entries(scenario.values!)) {
            const token = contract.tokens.get(path)!;
            expect(AuroraTextureRecipe.encodeValue(texture.read(token)), path).toEqual(expected);
          }
          if (scenario.colorReferences !== undefined) {
            expect(new Set(texture.colorReferences)).toEqual(new Set(scenario.colorReferences));
          }
          break;
        }
        default:
          expectCategory(() => decode(document), scenario.expected);
      }
    });
  }
});
