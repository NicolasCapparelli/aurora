import 'dart:math' as math;
import 'color.dart';
import 'contract.dart';
import 'foundation.dart';
import 'theme.dart';

/// Explicit foreground/background usage to evaluate, not a whole-app audit.
final class AuroraContrastPair {
  factory AuroraContrastPair({
    required AuroraColorToken foreground,
    required AuroraColorToken background,
    double minimumRatio = 4.5,
  }) {
    if (!minimumRatio.isFinite || minimumRatio < 1 || minimumRatio > 21) {
      throw ArgumentError.value(
          minimumRatio, 'minimumRatio', 'Expected [1, 21]');
    }
    return AuroraContrastPair._(foreground, background, minimumRatio);
  }
  const AuroraContrastPair._(
      this.foreground, this.background, this.minimumRatio);
  final AuroraColorToken foreground;
  final AuroraColorToken background;
  final double minimumRatio;
}

enum AuroraContrastStatus { pass, fail, unknown }

final class AuroraContrastCheck {
  const AuroraContrastCheck(
      {required this.appearance, required this.pair, required this.ratio});
  final AuroraAppearance appearance;
  final AuroraContrastPair pair;

  /// Null means the background is translucent and its backing color is unknown.
  final double? ratio;
  AuroraContrastStatus get status => ratio == null
      ? AuroraContrastStatus.unknown
      : ratio! >= pair.minimumRatio
          ? AuroraContrastStatus.pass
          : AuroraContrastStatus.fail;
  Map<String, Object?> toJson() => {
        'appearance': appearance.name,
        'foreground': pair.foreground.path,
        'background': pair.background.path,
        'minimumRatio': pair.minimumRatio,
        'ratio': ratio,
        'status': status.name,
        if (ratio == null) 'reason': 'transparentBackground',
      };
}

/// sRGB relative-luminance contrast. Foreground alpha is composited over an
/// opaque background; translucent backgrounds require a backing color and are
/// reported as unknown. No colors are changed by diagnostics.
abstract final class AuroraContrast {
  static double? ratio(AuroraColor foreground, AuroraColor background) {
    if (background.alpha != 255) return null;
    final alpha = foreground.alpha / 255;
    double linear(double channel) => channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    double luminance(double red, double green, double blue) =>
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue);
    final backgroundLuminance = luminance(
        background.red / 255, background.green / 255, background.blue / 255);
    double composite(int front, int back) =>
        (front * alpha + back * (1 - alpha)) / 255;
    final foregroundLuminance = luminance(
        composite(foreground.red, background.red),
        composite(foreground.green, background.green),
        composite(foreground.blue, background.blue));
    return (math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
        (math.min(foregroundLuminance, backgroundLuminance) + 0.05);
  }

  static List<AuroraContrastCheck> check(
    AuroraThemeVariant variant, {
    Iterable<AuroraContrastPair> additionalPairs = const [],
  }) =>
      List.unmodifiable([
        for (final pair in [...foundationPairs, ...additionalPairs])
          AuroraContrastCheck(
              appearance: variant.appearance,
              pair: pair,
              ratio: ratio(variant.read(pair.foreground),
                  variant.read(pair.background))),
      ]);

  static final List<AuroraContrastPair> foundationPairs = List.unmodifiable([
    for (final family in [
      'primary',
      'secondary',
      'tertiary',
      'error',
      'success',
      'warning',
      'info'
    ]) ...[
      _pair('on${_capital(family)}', family),
      _pair('on${_capital(family)}Container', '${family}Container'),
    ],
    for (final family in ['primary', 'secondary', 'tertiary'])
      for (final background in ['${family}Fixed', '${family}FixedDim']) ...[
        _pair('on${_capital(family)}Fixed', background),
        _pair('on${_capital(family)}FixedVariant', background),
      ],
    for (final surface in [
      'surface',
      'surfaceDim',
      'surfaceBright',
      'surfaceContainerLowest',
      'surfaceContainerLow',
      'surfaceContainer',
      'surfaceContainerHigh',
      'surfaceContainerHighest'
    ]) ...[
      _pair('onSurface', surface),
      _pair('onSurfaceVariant', surface),
    ],
    _pair('onInverseSurface', 'inverseSurface'),
    _pair('inversePrimary', 'inverseSurface'),
    _pair('outline', 'surface', minimumRatio: 3),
  ]);

  static String _capital(String name) =>
      '${name[0].toUpperCase()}${name.substring(1)}';
  static AuroraContrastPair _pair(String foreground, String background,
      {double minimumRatio = 4.5}) {
    final tokens = {
      for (final token in AuroraFoundation.tokens) token.path: token
    };
    return AuroraContrastPair(
        foreground: tokens['colors.$foreground']!,
        background: tokens['colors.$background']!,
        minimumRatio: minimumRatio);
  }
}
