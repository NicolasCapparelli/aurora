import 'color.dart';
import 'ref.dart';

/// Units for [AuroraDimension]. `dp` and `px` are both logical pixels in
/// Flutter; `rem` is relative to the root font size.
enum AuroraDimensionUnit { dp, px, rem }

/// An immutable length with an explicit unit.
final class AuroraDimension extends AuroraRef<AuroraDimension> {
  const AuroraDimension(this.value, this.unit);
  const AuroraDimension.dp(this.value) : unit = AuroraDimensionUnit.dp;
  const AuroraDimension.px(this.value) : unit = AuroraDimensionUnit.px;
  const AuroraDimension.rem(this.value) : unit = AuroraDimensionUnit.rem;
  final double value;
  final AuroraDimensionUnit unit;

  @override
  bool operator ==(Object other) =>
      other is AuroraDimension && other.value == value && other.unit == unit;
  @override
  int get hashCode => Object.hash(value, unit);
  @override
  String toString() => '$value${unit.name}';
}

/// An ordered, nonempty list of font family names, most preferred first.
final class AuroraFontFamily extends AuroraRef<AuroraFontFamily> {
  AuroraFontFamily(Iterable<String> names) : names = List.unmodifiable(names);
  AuroraFontFamily.single(String name) : this([name]);
  final List<String> names;

  /// The most preferred family; the remaining names are fallbacks.
  String get primary => names.first;
  List<String> get fallbacks => names.skip(1).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      other is AuroraFontFamily && _listEquals(other.names, names);
  @override
  int get hashCode => Object.hashAll(names);
  @override
  String toString() => names.join(', ');
}

/// A numeric font weight in [1, 1000].
final class AuroraFontWeight extends AuroraRef<AuroraFontWeight> {
  const AuroraFontWeight(this.value);
  static const thin = AuroraFontWeight(100);
  static const extraLight = AuroraFontWeight(200);
  static const light = AuroraFontWeight(300);
  static const regular = AuroraFontWeight(400);
  static const medium = AuroraFontWeight(500);
  static const semiBold = AuroraFontWeight(600);
  static const bold = AuroraFontWeight(700);
  static const extraBold = AuroraFontWeight(800);
  static const black = AuroraFontWeight(900);
  final int value;

  @override
  bool operator ==(Object other) =>
      other is AuroraFontWeight && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => '$value';
}

/// An easing curve from (0, 0) to (1, 1) with control points (x1, y1) and
/// (x2, y2). The x coordinates must be in [0, 1].
final class AuroraCubicBezier extends AuroraRef<AuroraCubicBezier> {
  const AuroraCubicBezier(this.x1, this.y1, this.x2, this.y2);
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  bool operator ==(Object other) =>
      other is AuroraCubicBezier &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;
  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);
  @override
  String toString() => 'cubic-bezier($x1, $y1, $x2, $y2)';
}

/// DTCG stroke style keywords, plus Aurora's `none`.
enum AuroraStrokeKeyword {
  solid('solid'),
  dashed('dashed'),
  dotted('dotted'),
  doubleLine('double'),
  groove('groove'),
  ridge('ridge'),
  outset('outset'),
  inset('inset'),
  none('none');

  const AuroraStrokeKeyword(this.wireName);

  /// The portable name used in DTCG and recipes.
  final String wireName;

  static AuroraStrokeKeyword? tryParse(String name) {
    for (final value in values) {
      if (value.wireName == name) return value;
    }
    return null;
  }
}

/// Line ends for a dash pattern.
enum AuroraLineCap { round, butt, square }

/// How a line is drawn: a keyword such as [solid], or a dash pattern.
final class AuroraStrokeStyle extends AuroraRef<AuroraStrokeStyle> {
  const AuroraStrokeStyle.keyword(AuroraStrokeKeyword this.keyword)
      : _dashArray = null,
        lineCap = null;

  /// A custom dash pattern: alternating dash and gap lengths.
  AuroraStrokeStyle.dashes({
    required Iterable<AuroraRef<AuroraDimension>> dashArray,
    required AuroraLineCap this.lineCap,
  })  : keyword = null,
        _dashArray = List.unmodifiable(dashArray);

  static const solid = AuroraStrokeStyle.keyword(AuroraStrokeKeyword.solid);
  static const dashed = AuroraStrokeStyle.keyword(AuroraStrokeKeyword.dashed);
  static const dotted = AuroraStrokeStyle.keyword(AuroraStrokeKeyword.dotted);
  static const none = AuroraStrokeStyle.keyword(AuroraStrokeKeyword.none);

  /// Set for keyword textures; null for dash patterns.
  final AuroraStrokeKeyword? keyword;

  /// Set for dash patterns; null for keyword textures.
  final AuroraLineCap? lineCap;
  final List<AuroraRef<AuroraDimension>>? _dashArray;

  /// Authored dash entries, which may be aliases. Null for keyword textures.
  List<AuroraRef<AuroraDimension>>? get dashArrayRefs => _dashArray;

  /// Resolved dash lengths. Null for keyword textures.
  List<AuroraDimension>? get dashArray => _dashArray
      ?.map((ref) => resolvedRef(ref, 'dashArray'))
      .toList(growable: false);

  bool get isNone => keyword == AuroraStrokeKeyword.none;

  @override
  bool operator ==(Object other) =>
      other is AuroraStrokeStyle &&
      other.keyword == keyword &&
      other.lineCap == lineCap &&
      _listEquals(other._dashArray, _dashArray);
  @override
  int get hashCode => Object.hash(
      keyword, lineCap, _dashArray == null ? null : Object.hashAll(_dashArray));
  @override
  String toString() => keyword?.wireName ?? 'dashes($_dashArray, $lineCap)';
}

/// A border. Its [color] is usually an alias to a theme colour token, such as
/// `AuroraAlias(AuroraFoundation.outline)`, so it follows light and dark.
final class AuroraBorder extends AuroraRef<AuroraBorder> {
  const AuroraBorder({
    required this.color,
    required AuroraRef<AuroraDimension> width,
    required AuroraRef<AuroraStrokeStyle> style,
  })  : widthRef = width,
        styleRef = style;

  /// A literal colour or an alias to a theme colour token.
  final AuroraRef<AuroraColor> color;
  final AuroraRef<AuroraDimension> widthRef;
  final AuroraRef<AuroraStrokeStyle> styleRef;

  AuroraDimension get width => resolvedRef(widthRef, 'width');
  AuroraStrokeStyle get style => resolvedRef(styleRef, 'style');

  @override
  bool operator ==(Object other) =>
      other is AuroraBorder &&
      other.color == color &&
      other.widthRef == widthRef &&
      other.styleRef == styleRef;
  @override
  int get hashCode => Object.hash(color, widthRef, styleRef);
}

/// One shadow layer. Its [color] may alias a theme colour token.
final class AuroraShadowLayer {
  const AuroraShadowLayer({
    required this.color,
    required AuroraRef<AuroraDimension> offsetX,
    required AuroraRef<AuroraDimension> offsetY,
    required AuroraRef<AuroraDimension> blur,
    required AuroraRef<AuroraDimension> spread,
    this.inset = false,
  })  : offsetXRef = offsetX,
        offsetYRef = offsetY,
        blurRef = blur,
        spreadRef = spread;

  final AuroraRef<AuroraColor> color;
  final AuroraRef<AuroraDimension> offsetXRef;
  final AuroraRef<AuroraDimension> offsetYRef;
  final AuroraRef<AuroraDimension> blurRef;
  final AuroraRef<AuroraDimension> spreadRef;
  final bool inset;

  AuroraDimension get offsetX => resolvedRef(offsetXRef, 'offsetX');
  AuroraDimension get offsetY => resolvedRef(offsetYRef, 'offsetY');
  AuroraDimension get blur => resolvedRef(blurRef, 'blur');
  AuroraDimension get spread => resolvedRef(spreadRef, 'spread');

  @override
  bool operator ==(Object other) =>
      other is AuroraShadowLayer &&
      other.color == color &&
      other.offsetXRef == offsetXRef &&
      other.offsetYRef == offsetYRef &&
      other.blurRef == blurRef &&
      other.spreadRef == spreadRef &&
      other.inset == inset;
  @override
  int get hashCode =>
      Object.hash(color, offsetXRef, offsetYRef, blurRef, spreadRef, inset);
}

/// One or more shadow layers, drawn in order. An empty list means no shadow.
final class AuroraShadow extends AuroraRef<AuroraShadow> {
  AuroraShadow(Iterable<AuroraShadowLayer> layers)
      : layers = List.unmodifiable(layers);
  static final none = AuroraShadow(const []);
  final List<AuroraShadowLayer> layers;

  @override
  bool operator ==(Object other) =>
      other is AuroraShadow && _listEquals(other.layers, layers);
  @override
  int get hashCode => Object.hashAll(layers);
}

/// A text style. Any field may alias a token of that field's type, such as a
/// shared font family token.
final class AuroraTypography extends AuroraRef<AuroraTypography> {
  const AuroraTypography({
    required AuroraRef<AuroraFontFamily> fontFamily,
    required AuroraRef<AuroraDimension> fontSize,
    required AuroraRef<AuroraFontWeight> fontWeight,
    required AuroraRef<AuroraDimension> letterSpacing,
    required AuroraRef<double> lineHeight,
  })  : fontFamilyRef = fontFamily,
        fontSizeRef = fontSize,
        fontWeightRef = fontWeight,
        letterSpacingRef = letterSpacing,
        lineHeightRef = lineHeight;

  final AuroraRef<AuroraFontFamily> fontFamilyRef;
  final AuroraRef<AuroraDimension> fontSizeRef;
  final AuroraRef<AuroraFontWeight> fontWeightRef;
  final AuroraRef<AuroraDimension> letterSpacingRef;

  /// A multiplier of the font size.
  final AuroraRef<double> lineHeightRef;

  AuroraFontFamily get fontFamily => resolvedRef(fontFamilyRef, 'fontFamily');
  AuroraDimension get fontSize => resolvedRef(fontSizeRef, 'fontSize');
  AuroraFontWeight get fontWeight => resolvedRef(fontWeightRef, 'fontWeight');
  AuroraDimension get letterSpacing =>
      resolvedRef(letterSpacingRef, 'letterSpacing');
  double get lineHeight => resolvedRef(lineHeightRef, 'lineHeight');

  @override
  bool operator ==(Object other) =>
      other is AuroraTypography &&
      other.fontFamilyRef == fontFamilyRef &&
      other.fontSizeRef == fontSizeRef &&
      other.fontWeightRef == fontWeightRef &&
      other.letterSpacingRef == letterSpacingRef &&
      other.lineHeightRef == lineHeightRef;
  @override
  int get hashCode => Object.hash(fontFamilyRef, fontSizeRef, fontWeightRef,
      letterSpacingRef, lineHeightRef);
}

/// The literal value of [ref]. Values read from a texture are always resolved;
/// authored values may still hold aliases, which throw here.
T resolvedRef<T>(AuroraRef<T> ref, String field) => switch (ref) {
      AuroraLiteral<T>(:final value) => value,
      AuroraAlias<T>(:final target) =>
        throw StateError('$field is an unresolved alias to ${target.path}; '
            'read resolved values from a texture'),
      _ => ref as T,
    };

bool _listEquals(List<Object?>? a, List<Object?>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
