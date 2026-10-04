import 'package:aurora/aurora.dart';
import 'package:flutter/material.dart';
import 'material.dart';

/// Typed reads and Flutter conversions for the active texture, bound to the
/// active theme variant so texture colours (border and shadow aliases to theme
/// colour tokens) follow the theme and appearance.
///
/// Get one from `Aurora.textureOf(context)`, which rebuilds the caller when the
/// theme, appearance or texture changes.
final class AuroraTextureTokens {
  AuroraTextureTokens(this.texture, this.variant, {this.rootFontSize = 16}) {
    texture.validateColors(variant.contract);
  }

  final AuroraTexture texture;
  final AuroraThemeVariant variant;

  /// Logical pixels per `rem`.
  final double rootFontSize;

  /// The resolved core value of [token].
  T read<T>(AuroraToken<T> token) => texture.read(token);

  /// A dimension in logical pixels. `dp` and `px` map one to one; `rem` is
  /// multiplied by [rootFontSize].
  double dimension(AuroraDimensionToken token) => toLogical(read(token));

  double toLogical(AuroraDimension value) => switch (value.unit) {
        AuroraDimensionUnit.dp || AuroraDimensionUnit.px => value.value,
        AuroraDimensionUnit.rem => value.value * rootFontSize,
      };

  Radius radius(AuroraDimensionToken token) =>
      Radius.circular(dimension(token));

  BorderRadius borderRadius(AuroraDimensionToken token) =>
      BorderRadius.all(radius(token));

  double number(AuroraNumberToken token) => read(token);
  bool flag(AuroraBooleanToken token) => read(token);
  String choice(AuroraEnumToken token) => read(token);

  /// An enum token mapped to a Dart enum by name.
  E option<E extends Enum>(AuroraEnumToken token, List<E> values) =>
      texture.readEnum(token, values);

  Duration duration(AuroraDurationToken token) => read(token);

  Cubic curve(AuroraCubicBezierToken token) {
    final value = read(token);
    return Cubic(value.x1, value.y1, value.x2, value.y2);
  }

  FontWeight fontWeight(AuroraFontWeightToken token) =>
      nearestFontWeight(read(token));

  /// A colour that may alias a theme colour token, resolved for the variant.
  Color color(AuroraRef<AuroraColor> color) =>
      variant.resolveColor(color).flutterColor;

  TextStyle textStyle(AuroraTypographyToken token) => toTextStyle(read(token));

  TextStyle toTextStyle(AuroraTypography value) {
    final weight = value.fontWeight.value;
    return TextStyle(
      fontFamily: value.fontFamily.primary,
      fontFamilyFallback: value.fontFamily.fallbacks.isEmpty
          ? null
          : value.fontFamily.fallbacks,
      fontSize: toLogical(value.fontSize),
      fontWeight: nearestFontWeight(value.fontWeight),
      fontVariations:
          weight % 100 == 0 ? null : [FontVariation.weight(weight.toDouble())],
      letterSpacing: toLogical(value.letterSpacing),
      height: value.lineHeight,
    );
  }

  /// The stroke style, which Flutter cannot draw on borders by itself. Use
  /// [AuroraStrokeStyle.keyword] or [dashPattern] to paint dashes yourself.
  AuroraStrokeStyle strokeStyle(AuroraStrokeStyleToken token) => read(token);

  /// Dash and gap lengths in logical pixels for [stroke] at [width]: null for
  /// solid strokes, empty for `none`. Keywords use conventional lengths
  /// (dashed: 3w on, 3w off; dotted: w on, 2w off); other keywords are drawn
  /// solid.
  List<double>? dashPattern(AuroraStrokeStyle stroke, {required double width}) {
    final dashes = stroke.dashArray;
    if (dashes != null) return [for (final dash in dashes) toLogical(dash)];
    return switch (stroke.keyword!) {
      AuroraStrokeKeyword.none => const [],
      AuroraStrokeKeyword.dashed => [3 * width, 3 * width],
      AuroraStrokeKeyword.dotted => [width, 2 * width],
      _ => null,
    };
  }

  /// A Flutter border side. Flutter draws every visible texture solid; check
  /// [strokeStyle] or the border's `style` to paint dashes. A `none` style or
  /// zero width gives [BorderSide.none].
  BorderSide borderSide(AuroraBorderToken token) => toBorderSide(read(token));

  BorderSide toBorderSide(AuroraBorder value) {
    final width = toLogical(value.width);
    if (value.style.isNone || width == 0) return BorderSide.none;
    return BorderSide(color: color(value.color), width: width);
  }

  Border border(AuroraBorderToken token) =>
      Border.fromBorderSide(borderSide(token));

  List<BoxShadow> shadows(AuroraShadowToken token) => [
        for (final layer in read(token).layers)
          if (!layer.inset)
            BoxShadow(
              color: color(layer.color),
              offset:
                  Offset(toLogical(layer.offsetX), toLogical(layer.offsetY)),
              blurRadius: toLogical(layer.blur),
              spreadRadius: toLogical(layer.spread),
            ),
      ];

  /// Material text theme from the texture foundation's type scale.
  TextTheme textTheme() => TextTheme(
        displayLarge: textStyle(AuroraTextureFoundation.displayLarge),
        displayMedium: textStyle(AuroraTextureFoundation.displayMedium),
        displaySmall: textStyle(AuroraTextureFoundation.displaySmall),
        headlineLarge: textStyle(AuroraTextureFoundation.headlineLarge),
        headlineMedium: textStyle(AuroraTextureFoundation.headlineMedium),
        headlineSmall: textStyle(AuroraTextureFoundation.headlineSmall),
        titleLarge: textStyle(AuroraTextureFoundation.titleLarge),
        titleMedium: textStyle(AuroraTextureFoundation.titleMedium),
        titleSmall: textStyle(AuroraTextureFoundation.titleSmall),
        bodyLarge: textStyle(AuroraTextureFoundation.bodyLarge),
        bodyMedium: textStyle(AuroraTextureFoundation.bodyMedium),
        bodySmall: textStyle(AuroraTextureFoundation.bodySmall),
        labelLarge: textStyle(AuroraTextureFoundation.labelLarge),
        labelMedium: textStyle(AuroraTextureFoundation.labelMedium),
        labelSmall: textStyle(AuroraTextureFoundation.labelSmall),
      );

  /// Applies the texture foundation to [theme]: the type scale (keeping the
  /// theme's text colours) and the corner shapes of cards (medium), chips
  /// (small), popup menus (extraSmall), and dialogs and bottom sheets
  /// (extraLarge). App extension tokens are the app's to apply.
  ThemeData applyTo(ThemeData theme) {
    final styled = textTheme();
    RoundedRectangleBorder rounded(AuroraDimensionToken token) =>
        RoundedRectangleBorder(borderRadius: borderRadius(token));
    return theme.copyWith(
      textTheme: theme.textTheme.merge(styled),
      primaryTextTheme: theme.primaryTextTheme.merge(styled),
      cardTheme: theme.cardTheme
          .copyWith(shape: rounded(AuroraTextureFoundation.mediumShape)),
      chipTheme: theme.chipTheme
          .copyWith(shape: rounded(AuroraTextureFoundation.smallShape)),
      popupMenuTheme: theme.popupMenuTheme
          .copyWith(shape: rounded(AuroraTextureFoundation.extraSmallShape)),
      dialogTheme: theme.dialogTheme
          .copyWith(shape: rounded(AuroraTextureFoundation.extraLargeShape)),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: radius(AuroraTextureFoundation.extraLargeShape)))),
    );
  }
}

/// The Flutter weight nearest to [weight] (w100 to w900).
FontWeight nearestFontWeight(AuroraFontWeight weight) {
  final index = ((weight.value / 100).round() - 1).clamp(0, 8);
  return FontWeight.values[index];
}
