import 'package:aurora_flutter/aurora_flutter.dart';

/// Texture extension tokens, shaped like Trace's texture packs. Declare them once,
/// as part of the app's single texture contract.
abstract final class FeelTokens {
  // Font families per role.
  static const displayFamily = AuroraFontFamilyToken('feel.type.family.display',
      description: 'Family for route codes and hero values.');
  static const bodyFamily = AuroraFontFamilyToken('feel.type.family.body',
      description: 'Family for body text and labels.');

  // Type roles; each aliases a family token.
  static const routeCode = AuroraTypographyToken('feel.type.routeCode',
      description: 'Airport codes on flight cards.');
  static const pageTitle = AuroraTypographyToken('feel.type.pageTitle',
      description: 'Screen titles.');
  static const kicker = AuroraTypographyToken('feel.type.kicker',
      description: 'Small uppercase labels above values.');
  static const body =
      AuroraTypographyToken('feel.type.body', description: 'Body text.');

  // Radii.
  static const cardRadius =
      AuroraDimensionToken('feel.shape.card', description: 'Card corners.');
  static const chipRadius = AuroraDimensionToken('feel.shape.chip',
      description: 'Chip corners; large values make a pill.');

  // Lines.
  static const cardBorder = AuroraBooleanToken('feel.lines.cardBorder',
      description: 'Whether cards draw a border.');
  static const card =
      AuroraBorderToken('feel.lines.card', description: 'Card border.');
  static const divider = AuroraStrokeStyleToken('feel.lines.divider',
      description: 'Stroke texture of dividers inside cards.');

  // Depth and density.
  static const cardShadow =
      AuroraShadowToken('feel.depth.card', description: 'Card shadow.');
  static const screenMargin = AuroraDimensionToken('feel.density.screenMargin',
      description: 'Horizontal screen margin.');
  static const cardPadding = AuroraDimensionToken('feel.density.cardPadding',
      description: 'Padding inside cards.');

  // Chrome and default component variants.
  static const emblemShape = AuroraEnumToken('feel.chrome.emblemShape',
      description: 'Shape of the airline emblem.',
      values: ['roundedSquare', 'circle']);
  static const flightCard = AuroraEnumToken('feel.variants.flightCard',
      description: 'Default flight card layout.',
      values: ['rich', 'compact', 'walletPass']);

  static const all = <AuroraToken<Object>>[
    displayFamily,
    bodyFamily,
    routeCode,
    pageTitle,
    kicker,
    body,
    cardRadius,
    chipRadius,
    cardBorder,
    card,
    divider,
    cardShadow,
    screenMargin,
    cardPadding,
    emblemShape,
    flightCard,
  ];
}

enum EmblemShape { roundedSquare, circle }

enum FlightCardLayout { rich, compact, walletPass }

final feelTextureContract =
    AuroraTextureContract(id: 'feel', extensions: FeelTokens.all);

final feelThemeContract = AuroraContract(id: 'feel');

AuroraTypography _type(AuroraFontFamilyToken family, double size, int weight,
        {double tracking = 0, double height = 1.3}) =>
    AuroraTypography(
        fontFamily: AuroraAlias(family),
        fontSize: AuroraDimension.dp(size),
        fontWeight: AuroraFontWeight(weight),
        letterSpacing: AuroraDimension.dp(tracking),
        lineHeight: AuroraLiteral(height));

/// Rounded, airy, sans-serif, solid borders and soft shadows.
final softTexture = AuroraTextureStarter.texture(
  contract: feelTextureContract,
  id: 'soft',
  name: 'Soft',
  values: {
    AuroraTextureFoundation.mediumShape: const AuroraDimension.dp(20),
    AuroraTextureFoundation.smallShape: const AuroraDimension.dp(12),
    FeelTokens.displayFamily:
        AuroraFontFamily(['Nunito', 'Segoe UI', 'Roboto', 'sans-serif']),
    FeelTokens.bodyFamily:
        AuroraFontFamily(['Nunito', 'Segoe UI', 'Roboto', 'sans-serif']),
    FeelTokens.routeCode: _type(FeelTokens.displayFamily, 34, 800),
    FeelTokens.pageTitle: _type(FeelTokens.displayFamily, 26, 700),
    FeelTokens.kicker:
        _type(FeelTokens.bodyFamily, 11, 700, tracking: 1.2, height: 1.4),
    FeelTokens.body: _type(FeelTokens.bodyFamily, 15, 400, height: 1.45),
    FeelTokens.cardRadius:
        const AuroraAlias(AuroraTextureFoundation.mediumShape),
    FeelTokens.chipRadius: const AuroraDimension.dp(999),
    FeelTokens.cardBorder: true,
    FeelTokens.card: const AuroraBorder(
        color: AuroraAlias(AuroraFoundation.outlineVariant),
        width: AuroraDimension.dp(1),
        style: AuroraStrokeStyle.solid),
    FeelTokens.divider: AuroraStrokeStyle.solid,
    FeelTokens.cardShadow: AuroraShadow([
      const AuroraShadowLayer(
          color: AuroraAlias(AuroraFoundation.shadow),
          offsetX: AuroraDimension.dp(0),
          offsetY: AuroraDimension.dp(6),
          blur: AuroraDimension.dp(18),
          spread: AuroraDimension.dp(-8)),
    ]),
    FeelTokens.screenMargin: const AuroraDimension.dp(20),
    FeelTokens.cardPadding: const AuroraDimension.dp(20),
    FeelTokens.emblemShape: 'circle',
    FeelTokens.flightCard: 'rich',
  },
);

/// Sharp corners, serif display type, dashed rules and no shadows.
final editorialTexture = AuroraTextureStarter.texture(
  contract: feelTextureContract,
  id: 'editorial',
  name: 'Editorial',
  values: {
    AuroraTextureFoundation.brandFamily:
        AuroraFontFamily(['Georgia', 'Times New Roman', 'serif']),
    AuroraTextureFoundation.mediumShape: const AuroraDimension.dp(0),
    AuroraTextureFoundation.smallShape: const AuroraDimension.dp(2),
    FeelTokens.displayFamily:
        const AuroraAlias(AuroraTextureFoundation.brandFamily),
    FeelTokens.bodyFamily:
        AuroraFontFamily(['Georgia', 'Times New Roman', 'serif']),
    FeelTokens.routeCode:
        _type(FeelTokens.displayFamily, 30, 400, tracking: -0.5, height: 1.1),
    FeelTokens.pageTitle: _type(FeelTokens.displayFamily, 28, 400),
    FeelTokens.kicker:
        _type(FeelTokens.bodyFamily, 10, 600, tracking: 2.4, height: 1.4),
    FeelTokens.body: _type(FeelTokens.bodyFamily, 15, 400, height: 1.5),
    FeelTokens.cardRadius:
        const AuroraAlias(AuroraTextureFoundation.mediumShape),
    FeelTokens.chipRadius:
        const AuroraAlias(AuroraTextureFoundation.smallShape),
    FeelTokens.cardBorder: true,
    FeelTokens.card: const AuroraBorder(
        color: AuroraAlias(AuroraFoundation.onSurface),
        width: AuroraDimension.dp(1.5),
        style: AuroraStrokeStyle.dashed),
    FeelTokens.divider: AuroraStrokeStyle.dotted,
    FeelTokens.cardShadow: AuroraShadow.none,
    FeelTokens.screenMargin: const AuroraDimension.dp(28),
    FeelTokens.cardPadding: const AuroraDimension.dp(16),
    FeelTokens.emblemShape: 'roundedSquare',
    FeelTokens.flightCard: 'compact',
  },
);

final feelTextures = [softTexture, editorialTexture];

AuroraTheme _theme(String id, String name, String light, String dark) =>
    AuroraTheme(
      id: id,
      name: name,
      preferredAppearance: AuroraAppearance.light,
      variants: [
        for (final appearance in AuroraAppearance.values)
          AuroraStarter.variant(
            contract: feelThemeContract,
            appearance: appearance,
            values: {
              AuroraFoundation.primary: AuroraColor.hex(
                  appearance == AuroraAppearance.light ? light : dark),
              AuroraFoundation.surfaceTint: AuroraColor.hex(
                  appearance == AuroraAppearance.light ? light : dark),
            },
          ),
      ],
    );

final feelThemes = [
  _theme('harbor', 'Harbor', '#0b5fa5', '#9ecaff'),
  _theme('ember', 'Ember', '#9a3412', '#ffb59c'),
];
