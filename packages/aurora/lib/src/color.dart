/// An immutable sRGB color stored as an unsigned 32-bit ARGB value.
final class AuroraColor {
  factory AuroraColor(int argb) {
    if (argb < 0 || argb > 0xffffffff) {
      throw ArgumentError.value(argb, 'argb', 'Expected a 32-bit ARGB value');
    }
    return AuroraColor._(argb);
  }

  const AuroraColor._(this.argb);

  /// Parses #RRGGBB or #RRGGBBAA (CSS order, not ARGB).
  factory AuroraColor.hex(String hex) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
      throw FormatException('Expected #RRGGBB or #RRGGBBAA', hex);
    }
    final rgb = int.parse(hex.substring(1, 7), radix: 16);
    final alpha =
        hex.length == 9 ? int.parse(hex.substring(7), radix: 16) : 255;
    return AuroraColor((alpha << 24) | rgb);
  }

  final int argb;
  int get alpha => (argb >> 24) & 255;
  int get red => (argb >> 16) & 255;
  int get green => (argb >> 8) & 255;
  int get blue => argb & 255;

  String get hex => '#${[
        red,
        green,
        blue,
        alpha
      ].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

  @override
  bool operator ==(Object other) => other is AuroraColor && other.argb == argb;
  @override
  int get hashCode => argb.hashCode;
  @override
  String toString() => hex;
}
