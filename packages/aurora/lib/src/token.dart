import 'color.dart';
import 'values.dart';

/// A typed, documented field in an Aurora contract. Declare tokens once as
/// constants, then reuse those declarations for values and reads.
///
/// Colour tokens belong to theme contracts. Every other type belongs to texture
/// contracts.
sealed class AuroraToken<T> {
  const AuroraToken(this.path, {required this.description});
  final String path;
  final String description;

  /// The DTCG `$type`, or Aurora's extension type for `boolean` and `enum`.
  String get type;

  @override
  String toString() => path;
}

/// A typed color field. Declare app tokens once, then reuse those declarations.
final class AuroraColorToken extends AuroraToken<AuroraColor> {
  const AuroraColorToken(super.path, {required super.description});
  @override
  String get type => 'color';
}

/// A length, such as a corner radius, border width or padding.
final class AuroraDimensionToken extends AuroraToken<AuroraDimension> {
  const AuroraDimensionToken(super.path, {required super.description});
  @override
  String get type => 'dimension';
}

/// A unitless finite number, such as an elevation level or opacity.
final class AuroraNumberToken extends AuroraToken<double> {
  const AuroraNumberToken(super.path, {required super.description});
  @override
  String get type => 'number';
}

/// An ordered list of font family names, most preferred first.
final class AuroraFontFamilyToken extends AuroraToken<AuroraFontFamily> {
  const AuroraFontFamilyToken(super.path, {required super.description});
  @override
  String get type => 'fontFamily';
}

/// A numeric font weight in [1, 1000].
final class AuroraFontWeightToken extends AuroraToken<AuroraFontWeight> {
  const AuroraFontWeightToken(super.path, {required super.description});
  @override
  String get type => 'fontWeight';
}

/// A nonnegative length of time, such as an animation duration.
final class AuroraDurationToken extends AuroraToken<Duration> {
  const AuroraDurationToken(super.path, {required super.description});
  @override
  String get type => 'duration';
}

/// An easing curve, defined by two cubic Bézier control points.
final class AuroraCubicBezierToken extends AuroraToken<AuroraCubicBezier> {
  const AuroraCubicBezierToken(super.path, {required super.description});
  @override
  String get type => 'cubicBezier';
}

/// How a line is drawn: solid, dashed, dotted, none, or a dash pattern.
final class AuroraStrokeStyleToken extends AuroraToken<AuroraStrokeStyle> {
  const AuroraStrokeStyleToken(super.path, {required super.description});
  @override
  String get type => 'strokeStyle';
}

/// A border: colour, width and stroke style.
final class AuroraBorderToken extends AuroraToken<AuroraBorder> {
  const AuroraBorderToken(super.path, {required super.description});
  @override
  String get type => 'border';
}

/// One or more shadow layers.
final class AuroraShadowToken extends AuroraToken<AuroraShadow> {
  const AuroraShadowToken(super.path, {required super.description});
  @override
  String get type => 'shadow';
}

/// A text style: family, size, weight, letter spacing and line height.
final class AuroraTypographyToken extends AuroraToken<AuroraTypography> {
  const AuroraTypographyToken(super.path, {required super.description});
  @override
  String get type => 'typography';
}

/// An on/off switch. Encoded as an Aurora DTCG extension.
final class AuroraBooleanToken extends AuroraToken<bool> {
  const AuroraBooleanToken(super.path, {required super.description});
  @override
  String get type => 'boolean';
}

/// One of a fixed set of string [values], such as a default component layout.
/// A value outside the set is a validation error. Encoded as an Aurora DTCG
/// extension that records the allowed set.
final class AuroraEnumToken extends AuroraToken<String> {
  const AuroraEnumToken(super.path,
      {required super.description, required this.values});
  final List<String> values;
  @override
  String get type => 'enum';
}
