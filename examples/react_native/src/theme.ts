import {
  AuroraAliasRule,
  AuroraAlias,
  AuroraBorder,
  AuroraBorderToken,
  AuroraColor,
  AuroraColorToken,
  AuroraContract,
  AuroraDimension,
  AuroraFoundation,
  AuroraGenerationRequest,
  AuroraGenerator,
  AuroraSelection,
  AuroraShadow,
  AuroraShadowLayer,
  AuroraShadowToken,
  AuroraStrokeStyle,
  AuroraTextureContract,
  AuroraTextureStarter,
  type AuroraTheme,
} from '@aurora/core';

/** An app extension: the canvas background, declared once and read by identity. */
export const canvas = new AuroraColorToken('example.canvas', { description: 'Background of the demo canvas.' });
export const cardBorder = new AuroraBorderToken('example.cardBorder', { description: 'Border of cards.' });
export const cardShadow = new AuroraShadowToken('example.cardShadow', { description: 'Shadow of cards.' });

export const contract = new AuroraContract({ id: 'example', extensions: [canvas] });
const textureContract = new AuroraTextureContract({ id: 'example-texture', extensions: [cardBorder, cardShadow] });

function theme(id: string, name: string, primary: string): AuroraTheme {
  return AuroraGenerator.generate(
    new AuroraGenerationRequest({
      contract,
      id,
      name,
      primary: AuroraColor.hex(primary),
      rules: [[canvas, new AuroraAliasRule(AuroraFoundation.surfaceContainerHigh)]],
    }),
  ).theme;
}

export const themes = [theme('forest', 'Forest', '#246b35'), theme('ember', 'Ember', '#b3261e')];

export const texture = AuroraTextureStarter.texture({
  contract: textureContract,
  id: 'soft',
  name: 'Soft',
  values: [
    [
      cardBorder,
      new AuroraBorder({
        color: new AuroraAlias(AuroraFoundation.outlineVariant),
        width: AuroraDimension.dp(1.5),
        style: AuroraStrokeStyle.dashed,
      }),
    ],
    [
      cardShadow,
      new AuroraShadow([
        new AuroraShadowLayer({
          color: AuroraColor.rgba(0, 0, 0, 64),
          offsetX: AuroraDimension.dp(0),
          offsetY: AuroraDimension.dp(2),
          blur: AuroraDimension.dp(8),
          spread: AuroraDimension.dp(0),
        }),
      ]),
    ],
  ],
});

export const initialSelection = new AuroraSelection({ themeId: 'forest', appearance: 'system', textureId: 'soft' });
