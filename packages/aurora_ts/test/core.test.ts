import { describe, expect, it } from 'vitest';
import {
  AuroraAlias,
  AuroraArgumentError,
  AuroraBorder,
  AuroraBorderToken,
  AuroraColor,
  AuroraColorToken,
  AuroraContract,
  AuroraContrast,
  AuroraContrastPair,
  AuroraDimension,
  AuroraDimensionToken,
  AuroraDtcg,
  AuroraDuration,
  AuroraEnumToken,
  AuroraFormatError,
  AuroraFoundation,
  AuroraGenerationRequest,
  AuroraGenerator,
  AuroraAliasRule,
  AuroraToneRule,
  AuroraRuntime,
  AuroraSelection,
  type AuroraState,
  AuroraStarter,
  AuroraStateError,
  AuroraStrokeStyle,
  AuroraTexture,
  AuroraTextureContract,
  AuroraTextureDtcg,
  AuroraTextureFoundation,
  AuroraTextureStarter,
  AuroraTheme,
  AuroraThemeVariant,
  type AuroraToken,
  AuroraValidationError,
  resolveTextureColor,
} from '../src/index.js';

const flush = () => new Promise<void>((resolve) => setTimeout(resolve, 0));

function theme(contract: AuroraContract, id = 'wicked', dark = true): AuroraTheme {
  return new AuroraTheme({
    id,
    name: id,
    preferredAppearance: 'light',
    variants: [
      AuroraStarter.variant({ contract, appearance: 'light' }),
      ...(dark ? [AuroraStarter.variant({ contract, appearance: 'dark' })] : []),
    ],
  });
}

describe('colors and contracts', () => {
  it('parses CSS hex in RGBA order and round-trips ARGB', () => {
    const color = AuroraColor.hex('#11223344');
    expect(color.argb).toBe(0x44112233);
    expect(color.hex).toBe('#11223344');
    expect(new AuroraColor(color.argb).equals(color)).toBe(true);
    expect(() => AuroraColor.hex('#123')).toThrow(AuroraFormatError);
    expect(() => new AuroraColor(-1)).toThrow(AuroraArgumentError);
  });

  it('includes all 58 foundation roles', () => {
    expect(AuroraFoundation.tokens).toHaveLength(58);
    expect(new AuroraContract({ id: 'app' }).tokens.size).toBe(58);
  });

  it('cannot redefine the foundation, use its namespace or collide paths', () => {
    const cases = [
      [new AuroraColorToken('colors.primary', { description: 'Again.' })],
      [new AuroraColorToken('colors.brand', { description: 'Reserved.' })],
      [new AuroraColorToken('app.a', { description: 'A.' }), new AuroraColorToken('app.a.b', { description: 'B.' })],
      [new AuroraColorToken('app..bad', { description: 'Bad.' })],
      [new AuroraColorToken('app.ok', { description: ' ' })],
    ];
    for (const extensions of cases) {
      expect(() => new AuroraContract({ id: 'app', extensions })).toThrow(AuroraArgumentError);
    }
  });

  it('variants require every token, including app extensions, and report all issues', () => {
    const ticket = new AuroraColorToken('app.ticket', { description: 'Ticket.' });
    const contract = new AuroraContract({ id: 'app', extensions: [ticket] });
    const stranger = new AuroraColorToken('app.stranger', { description: 'Undeclared.' });
    try {
      new AuroraThemeVariant({
        contract,
        appearance: 'light',
        values: new Map<AuroraColorToken, unknown>([[stranger, AuroraColor.hex('#000000')]]),
      });
      expect.fail('expected validation');
    } catch (error) {
      expect(error).toBeInstanceOf(AuroraValidationError);
      const issues = (error as AuroraValidationError).issues;
      expect(issues).toContain('Missing required token app.ticket');
      expect(issues).toContain('Undeclared token app.stranger');
      expect(issues.length).toBe(60);
    }
    expect(() => AuroraStarter.variant({ contract, appearance: 'light' })).toThrow(AuroraValidationError);
  });

  it('round-trips DTCG including transparency', () => {
    const ticket = new AuroraColorToken('app.ticket', { description: 'Ticket.' });
    const contract = new AuroraContract({ id: 'app', extensions: [ticket] });
    const variant = AuroraStarter.variant({
      contract,
      appearance: 'dark',
      values: [[ticket, AuroraColor.hex('#12345678')]],
    });
    const decoded = AuroraDtcg.decode(JSON.parse(JSON.stringify(AuroraDtcg.encode(variant))), {
      contract,
      appearance: 'dark',
    });
    for (const token of contract.tokens.values()) expect(decoded.read(token).hex).toBe(variant.read(token).hex);
  });
});

describe('runtime selection', () => {
  const contract = new AuroraContract({ id: 'app' });
  const runtime = () =>
    new AuroraRuntime({
      contract,
      themes: [theme(contract), theme(contract, 'lightOnly', false)],
      initialSelection: new AuroraSelection({ themeId: 'wicked' }),
      fallback: 'reject',
    });

  it('device appearance preserves identity and notifies once per effective change, asynchronously', async () => {
    const engine = runtime();
    const events: AuroraState[] = [];
    engine.listen((state) => events.push(state));
    engine.setSystemAppearance('dark');
    engine.setSystemAppearance('dark');
    expect(events).toHaveLength(0);
    await flush();
    expect(engine.state.selection.themeId).toBe('wicked');
    expect(engine.state.variant.appearance).toBe('dark');
    expect(events).toHaveLength(1);
  });

  it('rejected selections preserve the active state', () => {
    const engine = runtime();
    const previous = engine.state;
    expect(() => engine.select(new AuroraSelection({ themeId: 'lightOnly', appearance: 'dark' }))).toThrow(
      AuroraStateError,
    );
    expect(engine.state).toBe(previous);
    expect(() => engine.select(new AuroraSelection({ themeId: 'unknown' }))).toThrow(AuroraArgumentError);
    expect(engine.state).toBe(previous);
  });

  it('rejected system changes do not commit device appearance', () => {
    const engine = runtime();
    engine.select(new AuroraSelection({ themeId: 'lightOnly' }));
    expect(() => engine.setSystemAppearance('dark')).toThrow(AuroraStateError);
    engine.select(new AuroraSelection({ themeId: 'wicked' }));
    expect(engine.state.variant.appearance).toBe('light');
  });

  it('preferred fallback retains the requested preference', () => {
    const engine = new AuroraRuntime({
      contract,
      themes: [theme(contract, 'wicked', false)],
      initialSelection: new AuroraSelection({ themeId: 'wicked', appearance: 'dark' }),
      fallback: 'preferred',
    });
    expect(engine.state.variant.appearance).toBe('light');
    expect(engine.state.selection.appearance).toBe('dark');
  });

  it('fixed appearance ignores device changes', () => {
    const engine = runtime();
    engine.select(new AuroraSelection({ themeId: 'wicked', appearance: 'light' }));
    engine.setSystemAppearance('dark');
    expect(engine.state.variant.appearance).toBe('light');
  });

  it('listeners may trigger a subsequent selection safely, and changes() iterates', async () => {
    const engine = runtime();
    engine.listen((state) => {
      if (state.variant.appearance === 'dark') {
        engine.select(new AuroraSelection({ themeId: 'lightOnly', appearance: 'light' }));
      }
    });
    const seen: string[] = [];
    const iterate = (async () => {
      for await (const state of engine.changes()) {
        seen.push(state.selection.themeId);
        if (state.selection.themeId === 'lightOnly') break;
      }
    })();
    engine.setSystemAppearance('dark');
    await iterate;
    expect(seen).toEqual(['wicked', 'lightOnly']);
    expect(engine.state.selection.themeId).toBe('lightOnly');
  });

  it('disposed runtimes reject writes and end iteration', async () => {
    const engine = runtime();
    const iterate = (async () => {
      const states: AuroraState[] = [];
      for await (const state of engine.changes()) states.push(state);
      return states;
    })();
    engine.setSystemAppearance('dark');
    engine.dispose();
    expect(() => engine.select(new AuroraSelection({ themeId: 'wicked' }))).toThrow(AuroraStateError);
    expect(await iterate).toHaveLength(1);
  });

  it('registry rejects duplicate ids and foreign contracts', () => {
    const init = { initialSelection: new AuroraSelection({ themeId: 'wicked' }), fallback: 'reject' as const };
    expect(() => new AuroraRuntime({ ...init, contract, themes: [theme(contract), theme(contract)] })).toThrow(
      AuroraArgumentError,
    );
    expect(
      () => new AuroraRuntime({ ...init, contract, themes: [theme(new AuroraContract({ id: 'other' }))] }),
    ).toThrow(AuroraArgumentError);
  });

  it('selection JSON is strict on decode and forgiving on restore', () => {
    const selection = new AuroraSelection({ themeId: 'a', textureId: 'sharp' });
    expect(selection.toJson()).toEqual({ themeId: 'a', appearance: 'system', textureId: 'sharp' });
    expect(new AuroraSelection({ themeId: 'a' }).toJson()).not.toHaveProperty('textureId');
    expect(AuroraSelection.fromJson(selection.toJson()).textureId).toBe('sharp');
    for (const bad of [
      { themeId: 'a', appearance: 'system', textureId: 3 },
      { themeId: 'a', appearance: 'dim' },
      { themeId: '', appearance: 'light' },
      { themeId: 'a', appearance: 'light', extra: true },
      null,
    ]) {
      expect(() => AuroraSelection.fromJson(bad)).toThrow(AuroraFormatError);
    }
    const themes = [theme(contract, 'a')];
    const restored = AuroraSelection.restoreJson({ themeId: 'gone', appearance: 'dim', textureId: 7 }, {
      themes,
      fallbackId: 'a',
    });
    expect(restored.toJson()).toEqual({ themeId: 'a', appearance: 'system' });
    expect(() => AuroraSelection.restore({ themes, fallbackId: 'missing' })).toThrow(AuroraArgumentError);
  });
});

describe('textures', () => {
  const cardRadius = new AuroraDimensionToken('feel.cardRadius', { description: 'Card corners.' });
  const cardBorder = new AuroraBorderToken('feel.cardBorder', { description: 'Card border.' });
  const layout = new AuroraEnumToken('feel.layout', { description: 'Layout.', values: ['rich', 'compact'] });
  const textureContract = new AuroraTextureContract({ id: 'feel', extensions: [cardRadius, cardBorder, layout] });
  const contract = new AuroraContract({ id: 'app' });
  const make = (id: string, values: [unknown, unknown][] = []) =>
    AuroraTextureStarter.texture({
      contract: textureContract,
      id,
      name: id,
      values: new Map<AuroraToken<unknown>, unknown>([
        [cardRadius, new AuroraAlias(AuroraTextureFoundation.mediumShape)],
        [
          cardBorder,
          new AuroraBorder({
            color: new AuroraAlias(AuroraFoundation.outline),
            width: AuroraDimension.dp(1),
            style: AuroraStrokeStyle.solid,
          }),
        ],
        [layout, 'rich'],
        ...(values as [never, unknown][]),
      ]),
    });
  const soft = make('soft');
  const sharp = make('sharp', [[AuroraTextureFoundation.mediumShape, AuroraDimension.dp(2)]]);

  it('reads typed, resolved values and binds colours to a variant', () => {
    expect(soft.read(cardRadius).equals(AuroraDimension.dp(12))).toBe(true);
    expect(sharp.read(cardRadius).equals(AuroraDimension.dp(2))).toBe(true);
    expect(soft.read(AuroraTextureFoundation.shortDuration).equals(AuroraDuration.ms(100))).toBe(true);
    expect(soft.read(layout)).toBe('rich');
    const variant = AuroraStarter.variant({ contract, appearance: 'dark' });
    expect(resolveTextureColor(variant, soft.read(cardBorder).color).hex).toBe(
      variant.read(AuroraFoundation.outline).hex,
    );
    expect([...soft.colorReferences]).toEqual(['colors.outline']);
  });

  it('rejects colour tokens, reserved namespaces and invalid enums in contracts', () => {
    for (const extension of [
      new AuroraColorToken('feel.color', { description: 'Colour.' }),
      new AuroraDimensionToken('shape.custom', { description: 'Reserved.' }),
      new AuroraEnumToken('feel.empty', { description: 'Empty.', values: [] }),
    ]) {
      expect(() => new AuroraTextureContract({ id: 'x', extensions: [extension] })).toThrow(AuroraArgumentError);
    }
  });

  it('reports every problem at once, including cycles and enum values', () => {
    const a = new AuroraDimensionToken('feel.a', { description: 'A.' });
    const b = new AuroraDimensionToken('feel.b', { description: 'B.' });
    const contractWithCycle = new AuroraTextureContract({ id: 'cycle', extensions: [a, b, layout] });
    try {
      new AuroraTexture({
        contract: contractWithCycle,
        id: 'bad',
        name: 'Bad',
        values: new Map<unknown, unknown>([
          ...AuroraTextureStarter.material,
          [a, new AuroraAlias(b)],
          [b, new AuroraAlias(a)],
          [layout, 'grid'],
          [AuroraTextureFoundation.shortDuration, AuroraDuration.ms(-1)],
        ]) as never,
      });
      expect.fail('expected validation');
    } catch (error) {
      expect(error).toBeInstanceOf(AuroraValidationError);
      const issues = (error as AuroraValidationError).issues.join('\n');
      expect(issues).toContain('Cyclic token alias');
      expect(issues).toContain('feel.layout must be one of rich, compact');
      expect(issues).toContain('motion.short must not be negative');
    }
  });

  it('round-trips DTCG exactly, keeping aliases', () => {
    const document = AuroraTextureDtcg.encode(soft);
    const decoded = AuroraTextureDtcg.decode(JSON.parse(JSON.stringify(document)), {
      contract: textureContract,
      id: 'soft',
      name: 'Soft',
    });
    expect(AuroraTextureDtcg.encode(decoded)).toEqual(document);
  });

  const runtime = (pairings: Record<string, string> = {}, textureId?: string) =>
    new AuroraRuntime({
      contract,
      themes: [theme(contract, 'a'), theme(contract, 'b')],
      textures: [soft, sharp],
      texturePairings: pairings,
      initialSelection: new AuroraSelection({ themeId: 'a', textureId }),
      fallback: 'preferred',
    });

  it('apps without textures reject a texture id', () => {
    const r = new AuroraRuntime({
      contract,
      themes: [theme(contract, 'a')],
      initialSelection: new AuroraSelection({ themeId: 'a' }),
      fallback: 'reject',
    });
    expect(r.state.texture).toBeUndefined();
    expect(r.textureContract).toBeUndefined();
    expect(() => r.select(new AuroraSelection({ themeId: 'a', textureId: 'x' }))).toThrow(AuroraArgumentError);
  });

  it('pairings give themes a texture and an explicit selection wins', async () => {
    const r = runtime({ a: 'soft' });
    expect(r.state.texture).toBe(soft);
    r.select(new AuroraSelection({ themeId: 'b' }));
    expect(r.state.texture).toBeUndefined();
    r.select(new AuroraSelection({ themeId: 'a', textureId: 'sharp' }));
    expect(r.state.texture).toBe(sharp);
    const before = r.state;
    expect(() => r.select(new AuroraSelection({ themeId: 'b', textureId: 'nope' }))).toThrow(AuroraArgumentError);
    expect(r.state).toBe(before);
  });

  it('pairings change at runtime and notify only when the active texture changes', async () => {
    const r = runtime({ a: 'soft' });
    const changes: AuroraState[] = [];
    r.listen((state) => changes.push(state));
    r.pairTexture('a', 'sharp');
    expect(r.state.texture).toBe(sharp);
    r.pairTexture('b', 'soft');
    r.pairTexture('a', undefined);
    expect(r.state.texture).toBeUndefined();
    expect(Object.fromEntries(r.texturePairings)).toEqual({ b: 'soft' });
    expect(() => r.pairTexture('nope', 'soft')).toThrow(AuroraArgumentError);
    await flush();
    expect(changes).toHaveLength(2);
    const explicit = runtime({ a: 'soft' }, 'sharp');
    explicit.pairTexture('a', undefined);
    expect(explicit.state.texture).toBe(sharp);
  });

  it('registration validates texture contracts, ids and colours', () => {
    const base = { contract, themes: [theme(contract, 'a')], initialSelection: new AuroraSelection({ themeId: 'a' }), fallback: 'reject' as const };
    expect(() => new AuroraRuntime({ ...base, textures: [soft, soft] })).toThrow(AuroraArgumentError);
    const other = AuroraTextureStarter.texture({ contract: new AuroraTextureContract({ id: 'other' }), id: 'o', name: 'O' });
    expect(() => new AuroraRuntime({ ...base, textures: [soft, other] })).toThrow(AuroraArgumentError);
    const ticket = new AuroraColorToken('app.ticket', { description: 'Ticket.' });
    const needsTicket = make('ticket', [
      [cardBorder, new AuroraBorder({ color: new AuroraAlias(ticket), width: AuroraDimension.dp(1), style: AuroraStrokeStyle.solid })],
    ]);
    expect(() => new AuroraRuntime({ ...base, textures: [needsTicket] })).toThrow(AuroraValidationError);
    expect(() => new AuroraRuntime({ ...base, textures: [soft], texturePairings: { zzz: 'soft' } })).toThrow(
      AuroraArgumentError,
    );
  });
});

describe('generator', () => {
  const ticket = new AuroraColorToken('app.ticket', { description: 'Ticket.' });
  const stub = new AuroraColorToken('app.stub', { description: 'Stub.' });
  const contract = new AuroraContract({ id: 'app', extensions: [ticket, stub] });

  it('requires every extension and resolves alias and tone rules per appearance', () => {
    expect(() =>
      AuroraGenerator.generate(
        new AuroraGenerationRequest({ contract, id: 'x', name: 'X', primary: AuroraColor.hex('#246b35') }),
      ),
    ).toThrow(AuroraValidationError);
    const result = AuroraGenerator.generate(
      new AuroraGenerationRequest({
        contract,
        id: 'x',
        name: 'X',
        primary: AuroraColor.hex('#246b35'),
        values: [[AuroraFoundation.primaryContainer, AuroraColor.hex('#ff0000')]],
        rules: [
          [ticket, new AuroraAliasRule(AuroraFoundation.primaryContainer)],
          [stub, new AuroraToneRule({ palette: 'tertiary', lightTone: 90, darkTone: 20 })],
        ],
        contrastPairs: [new AuroraContrastPair({ foreground: AuroraFoundation.onSurface, background: ticket })],
      }),
    );
    const light = result.theme.variants.get('light')!;
    expect(light.read(ticket).hex).toBe('#ff0000ff');
    expect(light.read(stub).hex).not.toBe(result.theme.variants.get('dark')!.read(stub).hex);
    expect(result.checks.length).toBe((AuroraContrast.foundationPairs.length + 1) * 2);
    expect(result.toJson().variants.light).toEqual(AuroraDtcg.encode(light));
  });

  it('rejects rules for foundation tokens and cycles between rules', () => {
    expect(
      () =>
        new AuroraGenerationRequest({
          contract,
          id: 'x',
          name: 'X',
          primary: AuroraColor.hex('#246b35'),
          rules: [[AuroraFoundation.primary, new AuroraAliasRule(ticket)]],
        }),
    ).toThrow(AuroraArgumentError);
    expect(() =>
      AuroraGenerator.generate(
        new AuroraGenerationRequest({
          contract,
          id: 'x',
          name: 'X',
          primary: AuroraColor.hex('#246b35'),
          rules: [
            [ticket, new AuroraAliasRule(stub)],
            [stub, new AuroraAliasRule(ticket)],
          ],
        }),
      ),
    ).toThrow(AuroraValidationError);
  });

  it('per-entity variants are foundation-only and contrast helpers handle alpha', () => {
    const variants = AuroraGenerator.variants(AuroraColor.hex('#e60023'), 'vibrant');
    expect([...variants.keys()]).toEqual(['light', 'dark']);
    const white = AuroraColor.hex('#ffffff');
    const black = AuroraColor.hex('#000000');
    expect(AuroraContrast.bestOn(white, [white, black])).toBe(black);
    expect(AuroraContrast.ratio(black, AuroraColor.hex('#ffffff80'))).toBeNull();
    expect(() => AuroraContrast.bestOn(AuroraColor.hex('#ffffff80'), [black])).toThrow(AuroraArgumentError);
  });
});
