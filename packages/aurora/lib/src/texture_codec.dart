// Shared JSON value codec for texture DTCG documents and texture recipes.
// Not exported from the barrel.
import 'color.dart';
import 'dtcg.dart';
import 'foundation.dart';
import 'ref.dart';
import 'texture.dart';
import 'token.dart';
import 'values.dart';

final _reference =
    RegExp(r'^\{([a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*)\}$');

const _fontWeightNames = {
  'thin': 100,
  'hairline': 100,
  'extra-light': 200,
  'ultra-light': 200,
  'light': 300,
  'normal': 400,
  'regular': 400,
  'book': 400,
  'medium': 500,
  'semi-bold': 600,
  'demi-bold': 600,
  'bold': 700,
  'extra-bold': 800,
  'ultra-bold': 800,
  'black': 900,
  'heavy': 900,
  'extra-black': 950,
  'ultra-black': 950,
};

/// [recipe] codecs write `dp` units literally. DTCG codecs write `px` and the
/// caller records dp with a token-level `$extensions["dev.aurora"]` marker,
/// passed back as [pxIsDp] when decoding.
final class TextureCodec {
  TextureCodec(this._contract, {required this.recipe});
  final AuroraTextureContract? _contract;
  AuroraTextureContract get contract =>
      _contract ?? (throw StateError('Decoding needs a texture contract'));
  final bool recipe;

  // ---------------------------------------------------------------- encode

  Object encode(Object authored) => switch (authored) {
        AuroraAlias(:final target) => '{${target.path}}',
        AuroraDimension() => _dimension(authored),
        double() => authored,
        AuroraFontFamily(:final names) =>
          names.length == 1 ? names.single : names,
        AuroraFontWeight(:final value) => value,
        Duration() => <String, Object?>{
            'value': authored.inMicroseconds / 1000,
            'unit': 'ms'
          },
        AuroraCubicBezier(:final x1, :final y1, :final x2, :final y2) => [
            x1,
            y1,
            x2,
            y2
          ],
        AuroraStrokeStyle() => _stroke(authored),
        AuroraBorder() => <String, Object?>{
            'color': _color(authored.color),
            'width': _ref(authored.widthRef),
            'style': _ref(authored.styleRef),
          },
        AuroraShadow(:final layers) => [
            for (final layer in layers)
              <String, Object?>{
                'color': _color(layer.color),
                'offsetX': _ref(layer.offsetXRef),
                'offsetY': _ref(layer.offsetYRef),
                'blur': _ref(layer.blurRef),
                'spread': _ref(layer.spreadRef),
                if (layer.inset) 'inset': true,
              }
          ],
        AuroraTypography() => <String, Object?>{
            'fontFamily': _ref(authored.fontFamilyRef),
            'fontSize': _ref(authored.fontSizeRef),
            'fontWeight': _ref(authored.fontWeightRef),
            'letterSpacing': _ref(authored.letterSpacingRef),
            'lineHeight': _ref(authored.lineHeightRef),
          },
        bool() || String() => authored,
        _ => throw ArgumentError('Cannot encode texture value $authored'),
      };

  Object _ref(AuroraRef<Object?> ref) =>
      encode(ref is AuroraLiteral ? ref.value as Object : ref);

  Object _color(AuroraRef<AuroraColor> color) => switch (color) {
        AuroraAlias(:final target) => '{${target.path}}',
        AuroraLiteral<AuroraColor>(:final value) =>
          AuroraDtcg.encodeColorValue(value),
        AuroraColor() => AuroraDtcg.encodeColorValue(color),
        _ => throw ArgumentError('Cannot encode colour $color'),
      };

  Map<String, Object?> _dimension(AuroraDimension value) => {
        'value': value.value,
        'unit': value.unit == AuroraDimensionUnit.dp && !recipe
            ? 'px'
            : value.unit.name,
      };

  /// DTCG has no `none` stroke; Aurora writes an invisible zero-length dash
  /// pattern, which other tools also draw as no line.
  Object _stroke(AuroraStrokeStyle value) {
    if (value.isNone) {
      return recipe
          ? 'none'
          : {
              'dashArray': [
                {'value': 0, 'unit': 'px'}
              ],
              'lineCap': 'butt'
            };
    }
    if (value.keyword case final keyword?) return keyword.wireName;
    return {
      'dashArray': [for (final dash in value.dashArrayRefs!) _ref(dash)],
      'lineCap': value.lineCap!.name,
    };
  }

  /// Whether [authored] holds a literal dp dimension anywhere.
  static bool usesDp(Object authored) {
    bool dp(AuroraRef<Object?> ref) =>
        ref is AuroraDimension && ref.unit == AuroraDimensionUnit.dp ||
        ref is AuroraStrokeStyle && usesDp(ref);
    return switch (authored) {
      AuroraDimension() => dp(authored),
      AuroraStrokeStyle(:final dashArrayRefs) =>
        dashArrayRefs?.any(dp) ?? false,
      AuroraBorder() => dp(authored.widthRef) || dp(authored.styleRef),
      AuroraShadow(:final layers) => layers.any((l) =>
          dp(l.offsetXRef) ||
          dp(l.offsetYRef) ||
          dp(l.blurRef) ||
          dp(l.spreadRef)),
      AuroraTypography() =>
        dp(authored.fontSizeRef) || dp(authored.letterSpacingRef),
      _ => false,
    };
  }

  // ---------------------------------------------------------------- decode

  /// Decodes a `$value` for [token] into an authored texture value, keeping
  /// aliases. Malformed input throws [FormatException]; ranges and alias
  /// resolution are validated later by [AuroraTexture].
  Object decode(AuroraToken<Object?> token, Object? raw, String at,
      {bool pxIsDp = false}) {
    if (raw is String && _reference.hasMatch(raw)) {
      final target = _target(raw, at);
      if (target.runtimeType != token.runtimeType) {
        throw FormatException(
            '$at must alias a ${token.type} token, not ${target.path}');
      }
      return AuroraAlias<Object?>(target);
    }
    final dp = pxIsDp;
    return switch (token) {
      AuroraColorToken() =>
        throw FormatException('$at: colour tokens belong to theme contracts'),
      AuroraDimensionToken() => _decodeDimension(raw, at, dp),
      AuroraNumberToken() => _number(raw, at),
      AuroraFontFamilyToken() => _decodeFamily(raw, at),
      AuroraFontWeightToken() => _decodeWeight(raw, at),
      AuroraDurationToken() => _decodeDuration(raw, at),
      AuroraCubicBezierToken() => _decodeBezier(raw, at),
      AuroraStrokeStyleToken() => _decodeStroke(raw, at, dp),
      AuroraBorderToken() => _decodeBorder(raw, at, dp),
      AuroraShadowToken() => _decodeShadow(raw, at, dp),
      AuroraTypographyToken() => _decodeTypography(raw, at, dp),
      AuroraBooleanToken() =>
        raw is bool ? raw : throw FormatException('$at must be a boolean'),
      AuroraEnumToken() =>
        raw is String ? raw : throw FormatException('$at must be a string'),
    };
  }

  AuroraToken<Object?> _target(String raw, String at) {
    final path = _reference.firstMatch(raw)!.group(1)!;
    return contract.tokens[path] ??
        (throw FormatException('$at aliases unknown token $path'));
  }

  AuroraRef<X> _field<X>(Object? raw, String at, X Function(Object?) decode) {
    if (raw is String && _reference.hasMatch(raw)) {
      final target = _target(raw, at);
      if (target is! AuroraToken<X>) {
        throw FormatException('$at aliases ${target.path}, a ${target.type}');
      }
      return AuroraAlias<X>(target);
    }
    final value = decode(raw);
    return value is AuroraRef<X> ? value as AuroraRef<X> : AuroraLiteral(value);
  }

  AuroraRef<AuroraDimension> _dimensionField(Object? raw, String at, bool dp) =>
      _field(raw, at, (raw) => _decodeDimension(raw, at, dp));

  AuroraRef<AuroraColor> _colorField(Object? raw, String at) {
    if (raw is String && _reference.hasMatch(raw)) {
      final path = _reference.firstMatch(raw)!.group(1)!;
      if (contract.tokens.containsKey(path)) {
        throw FormatException('$at must refer to a theme colour, not $path');
      }
      final foundation =
          AuroraFoundation.tokens.where((token) => token.path == path);
      return AuroraAlias(foundation.isNotEmpty
          ? foundation.first
          : AuroraColorToken(path, description: 'Theme colour $path.'));
    }
    return AuroraDtcg.decodeColorValue(raw, at);
  }

  Map<String, Object?> _object(Object? raw, String at, Set<String> required,
      [Set<String> optional = const {}]) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('$at must be an object');
    }
    final unknown =
        raw.keys.where((k) => !required.contains(k) && !optional.contains(k));
    if (unknown.isNotEmpty) {
      throw FormatException('$at has unsupported fields ${unknown.join(', ')}');
    }
    final missing = required.where((k) => !raw.containsKey(k));
    if (missing.isNotEmpty) {
      throw FormatException('$at is missing ${missing.join(', ')}');
    }
    return raw;
  }

  double _number(Object? raw, String at) {
    if (raw is! num || !raw.isFinite) {
      throw FormatException('$at must be a finite number');
    }
    return raw.toDouble();
  }

  AuroraDimension _decodeDimension(Object? raw, String at, bool pxIsDp) {
    final map = _object(raw, at, {'value', 'unit'});
    final value = _number(map['value'], '$at.value');
    return switch (map['unit']) {
      'px' => AuroraDimension(
          value, pxIsDp ? AuroraDimensionUnit.dp : AuroraDimensionUnit.px),
      'rem' => AuroraDimension.rem(value),
      'dp' when recipe => AuroraDimension.dp(value),
      _ => throw FormatException(
          '$at.unit must be ${recipe ? 'dp, px or rem' : 'px or rem'}'),
    };
  }

  AuroraFontFamily _decodeFamily(Object? raw, String at) {
    if (raw is String) return AuroraFontFamily([raw]);
    if (raw is List && raw.every((name) => name is String)) {
      return AuroraFontFamily(raw.cast<String>());
    }
    throw FormatException('$at must be a font family name or list of names');
  }

  AuroraFontWeight _decodeWeight(Object? raw, String at) {
    if (raw is String) {
      final value = _fontWeightNames[raw];
      if (value == null) throw FormatException('$at: unknown font weight $raw');
      return AuroraFontWeight(value);
    }
    if (raw is num && raw.isFinite && raw == raw.roundToDouble()) {
      return AuroraFontWeight(raw.toInt());
    }
    throw FormatException('$at must be an integer font weight or keyword');
  }

  Duration _decodeDuration(Object? raw, String at) {
    final map = _object(raw, at, {'value', 'unit'});
    final value = _number(map['value'], '$at.value');
    final micros = switch (map['unit']) {
      'ms' => value * 1000,
      's' => value * 1000000,
      _ => throw FormatException('$at.unit must be ms or s'),
    };
    return Duration(microseconds: micros.round());
  }

  AuroraCubicBezier _decodeBezier(Object? raw, String at) {
    if (raw is! List || raw.length != 4) {
      throw FormatException('$at must be an array of four numbers');
    }
    final p = [for (var i = 0; i < 4; i++) _number(raw[i], '$at[$i]')];
    return AuroraCubicBezier(p[0], p[1], p[2], p[3]);
  }

  AuroraStrokeStyle _decodeStroke(Object? raw, String at, bool dp) {
    if (raw is String) {
      final keyword = AuroraStrokeKeyword.tryParse(raw);
      if (keyword == null || (keyword == AuroraStrokeKeyword.none && !recipe)) {
        throw FormatException('$at: unsupported stroke style $raw');
      }
      return AuroraStrokeStyle.keyword(keyword);
    }
    final map = _object(raw, at, {'dashArray', 'lineCap'});
    final dashes = map['dashArray'];
    if (dashes is! List || dashes.isEmpty) {
      throw FormatException('$at.dashArray must be a nonempty array');
    }
    final cap = AuroraLineCap.values
        .where((value) => value.name == map['lineCap'])
        .firstOrNull;
    if (cap == null) {
      throw FormatException('$at.lineCap must be round, butt or square');
    }
    final refs = [
      for (var i = 0; i < dashes.length; i++)
        _dimensionField(dashes[i], '$at.dashArray[$i]', dp)
    ];
    if (refs.every((ref) => ref is AuroraDimension && ref.value == 0)) {
      return AuroraStrokeStyle.none;
    }
    return AuroraStrokeStyle.dashes(dashArray: refs, lineCap: cap);
  }

  AuroraBorder _decodeBorder(Object? raw, String at, bool dp) {
    final map = _object(raw, at, {'color', 'width', 'style'});
    return AuroraBorder(
      color: _colorField(map['color'], '$at.color'),
      width: _dimensionField(map['width'], '$at.width', dp),
      style: _field(map['style'], '$at.style',
          (raw) => _decodeStroke(raw, '$at.style', dp)),
    );
  }

  AuroraShadow _decodeShadow(Object? raw, String at, bool dp) {
    final layers = raw is List ? raw : [raw];
    return AuroraShadow([
      for (var i = 0; i < layers.length; i++)
        () {
          final where = raw is List ? '$at[$i]' : at;
          final map = _object(layers[i], where,
              {'color', 'offsetX', 'offsetY', 'blur', 'spread'}, {'inset'});
          final inset = map['inset'] ?? false;
          if (inset is! bool)
            throw FormatException('$where.inset must be bool');
          return AuroraShadowLayer(
            color: _colorField(map['color'], '$where.color'),
            offsetX: _dimensionField(map['offsetX'], '$where.offsetX', dp),
            offsetY: _dimensionField(map['offsetY'], '$where.offsetY', dp),
            blur: _dimensionField(map['blur'], '$where.blur', dp),
            spread: _dimensionField(map['spread'], '$where.spread', dp),
            inset: inset,
          );
        }(),
    ]);
  }

  AuroraTypography _decodeTypography(Object? raw, String at, bool dp) {
    final map = _object(raw, at, {
      'fontFamily',
      'fontSize',
      'fontWeight',
      'letterSpacing',
      'lineHeight'
    });
    return AuroraTypography(
      fontFamily: _field(map['fontFamily'], '$at.fontFamily',
          (raw) => _decodeFamily(raw, '$at.fontFamily')),
      fontSize: _dimensionField(map['fontSize'], '$at.fontSize', dp),
      fontWeight: _field(map['fontWeight'], '$at.fontWeight',
          (raw) => _decodeWeight(raw, '$at.fontWeight')),
      letterSpacing:
          _dimensionField(map['letterSpacing'], '$at.letterSpacing', dp),
      lineHeight: _field<double>(map['lineHeight'], '$at.lineHeight',
          (raw) => _number(raw, '$at.lineHeight')),
    );
  }
}
