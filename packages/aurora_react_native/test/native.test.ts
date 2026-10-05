import {
  AuroraAlias,
  AuroraBorder,
  type AuroraBorderToken,
  AuroraColor,
  AuroraCubicBezier,
  AuroraDimension,
  AuroraDuration,
  AuroraFoundation,
  AuroraLiteral,
  AuroraFontFamily,
  AuroraFontWeight,
  AuroraShadow,
  AuroraShadowLayer,
  AuroraStrokeStyle,
  AuroraTypography,
  AuroraArgumentError,
  type AuroraCubicBezierToken,
  type AuroraDimensionToken,
  type AuroraDurationToken,
  type AuroraShadowToken,
  type AuroraStrokeStyleToken,
  type AuroraTexture,
  type AuroraTypographyToken,
} from '@aurora/core';
import type { ViewStyle } from 'react-native';
import { describe, expect, expectTypeOf, it } from 'vitest';
import {
  AuroraNativeUnsupportedError,
  type AuroraNativeBorderStyle,
  type AuroraNativeResult,
  nativeBorder,
  nativeBorderRadius,
  nativeColor,
  nativeColorWithAlpha,
  nativeCubicBezier,
  nativeDimension,
  nativeDuration,
  nativeShadow,
  nativeStrokeStyle,
  nativeTypography,
} from '../src/index.js';
import { fixtureTexture, wicked } from './helpers.js';

const light = wicked.variants.get('light')!;
const dark = wicked.variants.get('dark')!;

function token<T>(texture: AuroraTexture, path: string): T {
  return texture.contract.tokens.get(path) as T;
}

const typography = (init: { weight?: number; size?: AuroraDimension; spacing?: AuroraDimension; height?: number; families?: string[] } = {}) =>
  new AuroraTypography({
    fontFamily: new AuroraFontFamily(init.families ?? ['Inter', 'sans-serif']),
    fontSize: init.size ?? AuroraDimension.dp(14),
    fontWeight: new AuroraFontWeight(init.weight ?? 500),
    letterSpacing: init.spacing ?? AuroraDimension.dp(0.1),
    lineHeight: new AuroraLiteral(init.height ?? 1.5),
  });

describe('colour', () => {
  it('writes #rrggbb when opaque and #rrggbbaa otherwise, preserving alpha', () => {
    expect(nativeColor(AuroraColor.hex('#246b35'))).toBe('#246b35');
    expect(nativeColor(AuroraColor.rgba(0, 0, 0, 51))).toBe('#00000033');
    expect(nativeColor(AuroraColor.rgba(255, 128, 1, 0))).toBe('#ff800100');
  });

  it('replaces alpha with a 0..1 value and rejects out-of-range alpha', () => {
    const color = AuroraColor.rgba(18, 52, 86, 17);
    expect(nativeColorWithAlpha(color, 1)).toBe('#123456');
    expect(nativeColorWithAlpha(color, 0.5)).toBe('#12345680');
    expect(nativeColorWithAlpha(color, 0)).toBe('#12345600');
    expect(() => nativeColorWithAlpha(color, 1.1)).toThrow(AuroraArgumentError);
    expect(() => nativeColorWithAlpha(color, Number.NaN)).toThrow(AuroraArgumentError);
  });
});

describe('dimension', () => {
  it('maps dp and px 1:1 and multiplies rem by remBase (default 16)', () => {
    expect(nativeDimension(AuroraDimension.dp(8))).toBe(8);
    expect(nativeDimension(AuroraDimension.px(3))).toBe(3);
    expect(nativeDimension(AuroraDimension.rem(0.75))).toBe(12);
    expect(nativeDimension(AuroraDimension.rem(2), { remBase: 14 })).toBe(28);
    expect(nativeDimension(AuroraDimension.dp(8), { remBase: 14 })).toBe(8);
    expect(() => nativeDimension(AuroraDimension.rem(1), { remBase: 0 })).toThrow(AuroraArgumentError);
    expect(nativeBorderRadius(AuroraDimension.dp(6))).toEqual({ borderRadius: 6 });
  });
});

describe('typography', () => {
  it('converts size, absolute line height, letter spacing and string weight', () => {
    const style = nativeTypography(typography({ weight: 600, size: AuroraDimension.dp(20), spacing: AuroraDimension.dp(-0.25), height: 1.3 }));
    expect(style).toEqual({ fontFamily: 'Inter', fontSize: 20, fontWeight: '600', lineHeight: 26, letterSpacing: -0.25 });
  });

  it('multiplies the line height by the font size in dp, after rem conversion', () => {
    const style = nativeTypography(typography({ size: AuroraDimension.rem(1.5), height: 1.5, spacing: AuroraDimension.rem(0.1) }), {
      remBase: 10,
    });
    expect(style.fontSize).toBe(15);
    expect(style.lineHeight).toBe(22.5);
    expect(style.letterSpacing).toBe(1);
  });

  it('uses the first family by default and lets a resolver choose by weight', () => {
    const calls: [readonly string[], number][] = [];
    const style = nativeTypography(typography({ weight: 700, families: ['Inter', 'Helvetica', 'sans-serif'] }), {
      fontFamilyResolver: (families, weight) => {
        calls.push([families, weight]);
        return weight >= 700 ? 'Inter-Bold' : undefined;
      },
    });
    expect(style.fontFamily).toBe('Inter-Bold');
    expect(calls).toEqual([[['Inter', 'Helvetica', 'sans-serif'], 700]]);
    expect(nativeTypography(typography({ weight: 400 }), { fontFamilyResolver: () => undefined }).fontFamily).toBe('Inter');
  });

  it('treats weights outside 100..900 steps of 100 as unsupported', () => {
    for (const weight of [450, 50, 950, 1000]) {
      const strict = () => nativeTypography(typography({ weight }), { path: 'type.body' });
      expect(strict).toThrow(AuroraNativeUnsupportedError);
      expect(strict).toThrow(/type\.body\.fontWeight/);
    }
    const report = nativeTypography(typography({ weight: 450 }), { mode: 'report' });
    expect(report.style.fontWeight).toBe('500');
    expect(report.unsupported.map((entry) => entry.feature)).toEqual(['fontWeight.step']);
    expect(nativeTypography(typography({ weight: 50 }), { mode: 'report' }).style.fontWeight).toBe('100');
    expect(nativeTypography(typography({ weight: 1000 }), { mode: 'report' }).style.fontWeight).toBe('900');
    expect(nativeTypography(typography({ weight: 900 }), { mode: 'report' }).unsupported).toEqual([]);
  });
});

describe('stroke styles', () => {
  it('maps solid, dashed, dotted and none', () => {
    for (const keyword of ['solid', 'dashed', 'dotted', 'none'] as const) {
      expect(nativeStrokeStyle(AuroraStrokeStyle.keyword(keyword))).toBe(keyword);
    }
  });

  it('throws in strict mode, naming the path and feature, for every unsupported keyword', () => {
    for (const keyword of ['double', 'groove', 'ridge', 'outset', 'inset'] as const) {
      const call = () => nativeStrokeStyle(AuroraStrokeStyle.keyword(keyword), { path: 'lines.rule' });
      expect(call).toThrow(AuroraNativeUnsupportedError);
      try {
        call();
      } catch (error) {
        const unsupported = (error as AuroraNativeUnsupportedError).unsupported;
        expect(unsupported).toHaveLength(1);
        expect(unsupported[0]).toMatchObject({ path: 'lines.rule', feature: `strokeStyle.${keyword}` });
        expect((error as Error).message).toContain('lines.rule');
        expect((error as Error).message).toContain(`strokeStyle.${keyword}`);
      }
    }
  });

  it('reports custom dash patterns and line caps, with solid as the best effort', () => {
    const dashes = AuroraStrokeStyle.dashes([AuroraDimension.dp(4), AuroraDimension.dp(2)], 'round');
    expect(() => nativeStrokeStyle(dashes)).toThrow(AuroraNativeUnsupportedError);
    const result = nativeStrokeStyle(dashes, { mode: 'report', path: 'lines.divider' });
    expect(result.style).toBe('solid');
    expect(result.unsupported.map((entry) => [entry.path, entry.feature])).toEqual([
      ['lines.divider', 'strokeStyle.dashArray'],
      ['lines.divider', 'strokeStyle.lineCap'],
    ]);
  });

  it('report mode returns the same style with no entries when everything is supported', () => {
    expect(nativeStrokeStyle(AuroraStrokeStyle.dashed, { mode: 'report' })).toEqual({ style: 'dashed', unsupported: [] });
  });

  it('rejects an unknown mode', () => {
    expect(() => nativeStrokeStyle(AuroraStrokeStyle.solid, { mode: 'lenient' as 'strict' })).toThrow(AuroraArgumentError);
  });
});

describe('border', () => {
  const border = (style: AuroraStrokeStyle, width = AuroraDimension.dp(1.5)) =>
    new AuroraBorder({ color: new AuroraAlias(AuroraFoundation.outlineVariant), width, style });

  it('resolves the colour alias against the variant it is shown with', () => {
    expect(nativeBorder(border(AuroraStrokeStyle.dashed), light)).toEqual({
      borderWidth: 1.5,
      borderColor: light.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
      borderStyle: 'dashed',
    });
    expect(nativeBorder(border(AuroraStrokeStyle.solid), dark).borderColor).toBe(
      dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
    );
  });

  it('converts rem widths and literal colours with alpha', () => {
    const literal = new AuroraBorder({
      color: AuroraColor.rgba(0, 0, 0, 128),
      width: AuroraDimension.rem(0.25),
      style: AuroraStrokeStyle.dotted,
    });
    expect(nativeBorder(literal, light, { remBase: 20 })).toEqual({ borderWidth: 5, borderColor: '#00000080', borderStyle: 'dotted' });
  });

  it('turns a none stroke into width 0 with no colour or style', () => {
    expect(nativeBorder(border(AuroraStrokeStyle.none), light)).toEqual({ borderWidth: 0 });
  });

  it('is strict by default and reports unsupported styles on request', () => {
    const double = border(AuroraStrokeStyle.keyword('double'));
    expect(() => nativeBorder(double, light, { path: 'border.card' })).toThrow(/border\.card\.style/);
    const result = nativeBorder(double, light, { mode: 'report', path: 'border.card' });
    expect(result.style).toMatchObject({ borderWidth: 1.5, borderStyle: 'solid' });
    expect(result.unsupported).toEqual([expect.objectContaining({ path: 'border.card.style', feature: 'strokeStyle.double' })]);
  });

  it('assigns to a React Native ViewStyle', () => {
    const style: ViewStyle = nativeBorder(border(AuroraStrokeStyle.solid), light);
    expect(style.borderWidth).toBe(1.5);
    expectTypeOf(nativeBorder(border(AuroraStrokeStyle.solid), light)).toEqualTypeOf<AuroraNativeBorderStyle>();
    expectTypeOf(nativeBorder(border(AuroraStrokeStyle.solid), light, { mode: 'report' })).toEqualTypeOf<
      AuroraNativeResult<AuroraNativeBorderStyle>
    >();
  });
});

describe('shadow', () => {
  it('maps layers in order to boxShadow entries, resolving colours against the variant', () => {
    const shadow = new AuroraShadow([
      new AuroraShadowLayer({
        color: AuroraColor.rgba(0, 0, 0, 51),
        offsetX: AuroraDimension.dp(0),
        offsetY: AuroraDimension.dp(2),
        blur: AuroraDimension.dp(6),
        spread: AuroraDimension.dp(1),
      }),
      new AuroraShadowLayer({
        color: new AuroraAlias(AuroraFoundation.shadow),
        offsetX: AuroraDimension.rem(0.25),
        offsetY: AuroraDimension.px(1),
        blur: AuroraDimension.dp(1),
        spread: AuroraDimension.dp(-1),
        inset: true,
      }),
    ]);
    const style = nativeShadow(shadow, dark);
    expect(style).toEqual({
      boxShadow: [
        { offsetX: 0, offsetY: 2, blurRadius: 6, spreadDistance: 1, color: '#00000033' },
        {
          offsetX: 4,
          offsetY: 1,
          blurRadius: 1,
          spreadDistance: -1,
          color: dark.read(AuroraFoundation.shadow).hex.substring(0, 7),
          inset: true,
        },
      ],
    });
    expect(nativeShadow(shadow, light, { remBase: 8 }).boxShadow[1]!.offsetX).toBe(2);
    const viewStyle: ViewStyle = style;
    expect(viewStyle.boxShadow).toHaveLength(2);
  });

  it('maps no shadow to an empty list', () => {
    expect(nativeShadow(AuroraShadow.none, light)).toEqual({ boxShadow: [] });
  });
});

describe('motion', () => {
  it('converts durations to milliseconds and curves to plain control points', () => {
    expect(nativeDuration(AuroraDuration.ms(200))).toBe(200);
    expect(nativeDuration(AuroraDuration.seconds(1.5))).toBe(1500);
    expect(nativeDuration(new AuroraDuration(1500))).toBe(1.5);
    const curve = nativeCubicBezier(new AuroraCubicBezier(0.2, 0, 0, 1));
    expect(curve).toEqual({ x1: 0.2, y1: 0, x2: 0, y2: 1 });
    expect(Object.keys(curve)).toEqual(['x1', 'y1', 'x2', 'y2']);
  });
});

describe('texture reader (view.native shape)', () => {
  // The reader is exercised through the texture view in scope.test.tsx; this checks it against the portable fixture.
  it('converts the portable fixture tokens against a variant', async () => {
    const { createNativeTextureReader } = await import('../src/native.js');
    const texture = fixtureTexture();
    const native = createNativeTextureReader((t) => texture.read(t), dark);

    const heading = native.typography(token<AuroraTypographyToken>(texture, 'demo.type.heading'));
    expect(heading).toEqual({ fontFamily: 'Fraunces', fontSize: 20, fontWeight: '600', lineHeight: 26, letterSpacing: -0.25 });

    expect(native.dimension(token<AuroraDimensionToken>(texture, 'demo.density.gap'))).toBe(12);
    expect(native.dimension(token<AuroraDimensionToken>(texture, 'demo.density.gap'), { remBase: 8 })).toBe(6);
    expect(native.dimension(token<AuroraDimensionToken>(texture, 'demo.shape.web'))).toBe(3);
    expect(native.borderRadius(token<AuroraDimensionToken>(texture, 'demo.shape.chip'))).toEqual({ borderRadius: 999 });
    expect(native.duration(token<AuroraDurationToken>(texture, 'demo.motion.fade'))).toBe(200);
    const ease = texture.read(token<AuroraCubicBezierToken>(texture, 'demo.motion.ease'));
    expect(native.cubicBezier(token<AuroraCubicBezierToken>(texture, 'demo.motion.ease'))).toEqual({
      x1: ease.x1,
      y1: ease.y1,
      x2: ease.x2,
      y2: ease.y2,
    });

    expect(native.strokeStyle(token<AuroraStrokeStyleToken>(texture, 'demo.lines.rule'))).toBe('dashed');
    expect(native.strokeStyle(token<AuroraStrokeStyleToken>(texture, 'demo.lines.hidden'))).toBe('none');
    const divider = token<AuroraStrokeStyleToken>(texture, 'demo.lines.divider');
    expect(() => native.strokeStyle(divider)).toThrow(/demo\.lines\.divider/);
    expect(native.strokeStyle(divider, { mode: 'report' }).unsupported).toHaveLength(2);

    expect(native.border(token<AuroraBorderToken>(texture, 'demo.lines.cardBorder'))).toEqual({
      borderWidth: 1.5,
      borderColor: dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
      borderStyle: 'dashed',
    });

    const shadow = native.shadow(token<AuroraShadowToken>(texture, 'demo.depth.cardShadow'));
    expect(shadow.boxShadow).toHaveLength(2);
    expect(shadow.boxShadow[0]).toEqual({ offsetX: 0, offsetY: 2, blurRadius: 6, spreadDistance: 0, color: '#00000033' });
    expect(shadow.boxShadow[1]).toMatchObject({ offsetY: 4, blurRadius: 1, spreadDistance: -1, inset: true });
    expect(native.color(texture.read(token<AuroraBorderToken>(texture, 'demo.lines.cardBorder')).color)).toBe(
      dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
    );
  });
});
