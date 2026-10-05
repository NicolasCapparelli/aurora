import { AuroraFoundation, AuroraTextureFoundation } from '@aurora/core';
import { describe, expect, it, vi } from 'vitest';
import { applyAuroraCssVariables, auroraCssName, auroraCssText, auroraCssVariables } from '../src/index.js';
import { fixtureTexture, ticket, wicked } from './helpers.js';

const light = wicked.variants.get('light')!;
const dark = wicked.variants.get('dark')!;
const texture = fixtureTexture();

describe('CSS custom-property emitter', () => {
  it('names variables from token paths with a prefix option', () => {
    expect(auroraCssName('colors.onPrimaryContainer')).toBe('--aurora-colors-onPrimaryContainer');
    expect(auroraCssName('theater.ticket', { prefix: 'ts' })).toBe('--ts-theater-ticket');
    expect(() => auroraCssName('a', { prefix: 'bad prefix' })).toThrow();
  });

  it('emits every colour token for both appearances', () => {
    for (const variant of [light, dark]) {
      const css = auroraCssVariables(variant);
      expect(Object.keys(css)).toHaveLength(59);
      expect(css['--aurora-colors-primary']).toBe(variant.read(AuroraFoundation.primary).hex.substring(0, 7));
      expect(css['--aurora-theater-ticket']).toBe(variant.read(ticket).hex.substring(0, 7));
    }
    expect(auroraCssVariables(light)['--aurora-colors-surface']).not.toBe(auroraCssVariables(dark)['--aurora-colors-surface']);
    expect(auroraCssVariables(light)).toBe(auroraCssVariables(light));
  });

  it('maps every texture value type to CSS, binding theme colours to the variant', () => {
    const css = auroraCssVariables(light, texture);
    const outlineVariant = light.read(AuroraFoundation.outlineVariant).hex.substring(0, 7);
    expect(css).toMatchObject({
      // dimension (dp, px, rem) and aliases
      '--aurora-shape-medium': '6px',
      '--aurora-demo-shape-card': '6px',
      '--aurora-demo-shape-web': '3px',
      '--aurora-demo-density-gap': '0.75rem',
      // number, fontFamily, fontWeight
      '--aurora-demo-depth-card': '1',
      '--aurora-type-family-brand': '"Fraunces", "Georgia", serif',
      '--aurora-demo-type-weight': '600',
      // typography
      '--aurora-demo-type-heading': '600 20px/1.3 "Fraunces", "Georgia", serif',
      '--aurora-demo-type-heading-fontSize': '20px',
      '--aurora-demo-type-heading-letterSpacing': '-0.25px',
      '--aurora-demo-type-heading-lineHeight': '1.3',
      // strokeStyle: keyword, none and dash pattern
      '--aurora-demo-lines-rule': 'dashed',
      '--aurora-demo-lines-hidden': 'none',
      '--aurora-demo-lines-divider': 'dashed',
      '--aurora-demo-lines-divider-dashArray': '4px 4px',
      '--aurora-demo-lines-divider-lineCap': 'round',
      // border with a theme colour reference
      '--aurora-demo-lines-cardBorder': `1.5px dashed ${outlineVariant}`,
      '--aurora-demo-lines-cardBorder-color': outlineVariant,
      // shadow layers, translucent literal and inset alias
      '--aurora-demo-depth-cardShadow': `0px 2px 6px 0px #00000033, inset 0px 4px 1px -1px ${light.read(AuroraFoundation.shadow).hex.substring(0, 7)}`,
      // boolean, enum, duration, cubicBezier
      '--aurora-demo-lines-bordered': '1',
      '--aurora-demo-variants-card': 'walletPass',
      '--aurora-demo-motion-fade': '200ms',
      '--aurora-motion-short': '100ms',
      '--aurora-demo-motion-ease': 'cubic-bezier(0.2, 0, 0, 1)',
    });
    expect(css['--aurora-type-bodyMedium-fontFamily']).toBe('"Roboto"');
    const darkCss = auroraCssVariables(dark, texture);
    expect(darkCss['--aurora-demo-lines-cardBorder-color']).toBe(
      dark.read(AuroraFoundation.outlineVariant).hex.substring(0, 7),
    );
    expect(darkCss['--aurora-shape-medium']).toBe('6px');
    expect(AuroraTextureFoundation.tokens.every((token) => auroraCssName(token.path) in css)).toBe(true);
  });

  it('renders a rule and writes only changed variables to an element', () => {
    expect(auroraCssText(':root', { '--a': '1px' })).toBe(':root {\n  --a: 1px;\n}');
    const element = document.createElement('div');
    applyAuroraCssVariables(element, auroraCssVariables(light));
    expect(element.style.getPropertyValue('--aurora-colors-primary')).toBe(auroraCssVariables(light)['--aurora-colors-primary']);
    const setProperty = vi.spyOn(element.style, 'setProperty');
    const removeProperty = vi.spyOn(element.style, 'removeProperty');
    applyAuroraCssVariables(element, { ...auroraCssVariables(light), '--aurora-colors-primary': '#000000' }, auroraCssVariables(light));
    expect(setProperty).toHaveBeenCalledTimes(1);
    applyAuroraCssVariables(element, {}, auroraCssVariables(light));
    expect(removeProperty).toHaveBeenCalledTimes(59);
  });
});
