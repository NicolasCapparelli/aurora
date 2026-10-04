import 'ref.dart';
import 'texture.dart';
import 'token.dart';
import 'values.dart';

/// Aurora texture foundation v1: the Material 3 baseline type scale, corner
/// shapes and motion. Every texture supplies these; apps add their own tokens as
/// texture contract extensions. The `type`, `shape` and `motion` namespaces are
/// reserved.
abstract final class AuroraTextureFoundation {
  static const version = 1;
  static const namespaces = ['type', 'shape', 'motion'];

  static const brandFamily = AuroraFontFamilyToken('type.family.brand',
      description: 'Expressive typeface for display and headline text.');
  static const plainFamily = AuroraFontFamilyToken('type.family.plain',
      description: 'Readable typeface for titles, body and labels.');
  static const displayLarge = AuroraTypographyToken('type.displayLarge',
      description: 'Largest display text, for short hero numbers or words.');
  static const displayMedium = AuroraTypographyToken('type.displayMedium',
      description: 'Medium display text.');
  static const displaySmall = AuroraTypographyToken('type.displaySmall',
      description: 'Small display text.');
  static const headlineLarge = AuroraTypographyToken('type.headlineLarge',
      description: 'Large headlines on prominent screens.');
  static const headlineMedium = AuroraTypographyToken('type.headlineMedium',
      description: 'Medium headlines.');
  static const headlineSmall = AuroraTypographyToken('type.headlineSmall',
      description: 'Small headlines.');
  static const titleLarge = AuroraTypographyToken('type.titleLarge',
      description: 'Large titles, such as app bar titles.');
  static const titleMedium = AuroraTypographyToken('type.titleMedium',
      description: 'Medium titles, such as list headers.');
  static const titleSmall =
      AuroraTypographyToken('type.titleSmall', description: 'Small titles.');
  static const bodyLarge =
      AuroraTypographyToken('type.bodyLarge', description: 'Large body text.');
  static const bodyMedium = AuroraTypographyToken('type.bodyMedium',
      description: 'Default body text.');
  static const bodySmall = AuroraTypographyToken('type.bodySmall',
      description: 'Small body text, such as captions.');
  static const labelLarge = AuroraTypographyToken('type.labelLarge',
      description: 'Large labels, such as button text.');
  static const labelMedium =
      AuroraTypographyToken('type.labelMedium', description: 'Medium labels.');
  static const labelSmall = AuroraTypographyToken('type.labelSmall',
      description: 'Small labels, such as badges.');
  static const extraSmallShape = AuroraDimensionToken('shape.extraSmall',
      description:
          'Corner radius for small elements such as text fields and menus.');
  static const smallShape = AuroraDimensionToken('shape.small',
      description: 'Corner radius for chips and small cards.');
  static const mediumShape = AuroraDimensionToken('shape.medium',
      description: 'Corner radius for cards.');
  static const largeShape = AuroraDimensionToken('shape.large',
      description:
          'Corner radius for large surfaces such as navigation drawers.');
  static const extraLargeShape = AuroraDimensionToken('shape.extraLarge',
      description: 'Corner radius for dialogs and sheets.');
  static const shortDuration = AuroraDurationToken('motion.short',
      description:
          'Duration of small, quick transitions such as selection changes.');
  static const mediumDuration = AuroraDurationToken('motion.medium',
      description: 'Duration of standard transitions.');
  static const longDuration = AuroraDurationToken('motion.long',
      description:
          'Duration of large transitions such as full-screen changes.');
  static const extraLongDuration = AuroraDurationToken('motion.extraLong',
      description: 'Duration of slow, emphasized transitions.');
  static const easingStandard = AuroraCubicBezierToken('motion.easing.standard',
      description: 'Easing for transitions that begin and end on screen.');
  static const easingEmphasizedDecelerate = AuroraCubicBezierToken(
      'motion.easing.emphasizedDecelerate',
      description: 'Easing for elements entering the screen.');
  static const easingEmphasizedAccelerate = AuroraCubicBezierToken(
      'motion.easing.emphasizedAccelerate',
      description: 'Easing for elements leaving the screen.');

  static const tokens = <AuroraToken<Object>>[
    brandFamily,
    plainFamily,
    displayLarge,
    displayMedium,
    displaySmall,
    headlineLarge,
    headlineMedium,
    headlineSmall,
    titleLarge,
    titleMedium,
    titleSmall,
    bodyLarge,
    bodyMedium,
    bodySmall,
    labelLarge,
    labelMedium,
    labelSmall,
    extraSmallShape,
    smallShape,
    mediumShape,
    largeShape,
    extraLargeShape,
    shortDuration,
    mediumDuration,
    longDuration,
    extraLongDuration,
    easingStandard,
    easingEmphasizedDecelerate,
    easingEmphasizedAccelerate,
  ];
}

/// Explicit starter texture values. App extensions are still required.
abstract final class AuroraTextureStarter {
  /// Material 3 baseline values for every texture foundation token.
  static final Map<AuroraToken<Object>, Object> material = Map.unmodifiable({
    AuroraTextureFoundation.brandFamily: AuroraFontFamily(['Roboto']),
    AuroraTextureFoundation.plainFamily: AuroraFontFamily(['Roboto']),
    AuroraTextureFoundation.displayLarge: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(57.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(-0.25),
        lineHeight: AuroraLiteral(64.0 / 57.0)),
    AuroraTextureFoundation.displayMedium: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(45.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(52.0 / 45.0)),
    AuroraTextureFoundation.displaySmall: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(36.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(44.0 / 36.0)),
    AuroraTextureFoundation.headlineLarge: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(32.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(40.0 / 32.0)),
    AuroraTextureFoundation.headlineMedium: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(28.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(36.0 / 28.0)),
    AuroraTextureFoundation.headlineSmall: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.brandFamily),
        fontSize: AuroraDimension.dp(24.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(32.0 / 24.0)),
    AuroraTextureFoundation.titleLarge: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(22.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.0),
        lineHeight: AuroraLiteral(28.0 / 22.0)),
    AuroraTextureFoundation.titleMedium: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(16.0),
        fontWeight: AuroraFontWeight(500),
        letterSpacing: AuroraDimension.dp(0.15),
        lineHeight: AuroraLiteral(24.0 / 16.0)),
    AuroraTextureFoundation.titleSmall: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(14.0),
        fontWeight: AuroraFontWeight(500),
        letterSpacing: AuroraDimension.dp(0.1),
        lineHeight: AuroraLiteral(20.0 / 14.0)),
    AuroraTextureFoundation.bodyLarge: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(16.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.5),
        lineHeight: AuroraLiteral(24.0 / 16.0)),
    AuroraTextureFoundation.bodyMedium: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(14.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.25),
        lineHeight: AuroraLiteral(20.0 / 14.0)),
    AuroraTextureFoundation.bodySmall: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(12.0),
        fontWeight: AuroraFontWeight(400),
        letterSpacing: AuroraDimension.dp(0.4),
        lineHeight: AuroraLiteral(16.0 / 12.0)),
    AuroraTextureFoundation.labelLarge: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(14.0),
        fontWeight: AuroraFontWeight(500),
        letterSpacing: AuroraDimension.dp(0.1),
        lineHeight: AuroraLiteral(20.0 / 14.0)),
    AuroraTextureFoundation.labelMedium: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(12.0),
        fontWeight: AuroraFontWeight(500),
        letterSpacing: AuroraDimension.dp(0.5),
        lineHeight: AuroraLiteral(16.0 / 12.0)),
    AuroraTextureFoundation.labelSmall: const AuroraTypography(
        fontFamily: AuroraAlias(AuroraTextureFoundation.plainFamily),
        fontSize: AuroraDimension.dp(11.0),
        fontWeight: AuroraFontWeight(500),
        letterSpacing: AuroraDimension.dp(0.5),
        lineHeight: AuroraLiteral(16.0 / 11.0)),
    AuroraTextureFoundation.extraSmallShape: const AuroraDimension.dp(4.0),
    AuroraTextureFoundation.smallShape: const AuroraDimension.dp(8.0),
    AuroraTextureFoundation.mediumShape: const AuroraDimension.dp(12.0),
    AuroraTextureFoundation.largeShape: const AuroraDimension.dp(16.0),
    AuroraTextureFoundation.extraLargeShape: const AuroraDimension.dp(28.0),
    AuroraTextureFoundation.shortDuration: const Duration(milliseconds: 100),
    AuroraTextureFoundation.mediumDuration: const Duration(milliseconds: 300),
    AuroraTextureFoundation.longDuration: const Duration(milliseconds: 500),
    AuroraTextureFoundation.extraLongDuration:
        const Duration(milliseconds: 800),
    AuroraTextureFoundation.easingStandard:
        const AuroraCubicBezier(0.2, 0.0, 0.0, 1.0),
    AuroraTextureFoundation.easingEmphasizedDecelerate:
        const AuroraCubicBezier(0.05, 0.7, 0.1, 1.0),
    AuroraTextureFoundation.easingEmphasizedAccelerate:
        const AuroraCubicBezier(0.3, 0.0, 0.8, 0.15),
  });

  /// A complete style: the Material starter values plus [values], which
  /// override foundation tokens and supply app extensions.
  static AuroraTexture texture({
    required AuroraTextureContract contract,
    required String id,
    required String name,
    Map<AuroraToken<Object>, Object> values = const {},
  }) =>
      AuroraTexture(
          contract: contract,
          id: id,
          name: name,
          values: {...material, ...values});
}
