import 'color.dart';
import 'contract.dart';
import 'foundation.dart';
import 'ref.dart';
import 'texture_foundation.dart';
import 'theme.dart';
import 'values.dart';

final _pathPattern =
    RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*$');

/// Texture foundation plus app-owned additions. Every declared token is required.
///
/// Textures hold non-colour values (type, shape, motion, lines, density, chrome
/// and component defaults). Colours belong to theme contracts, so a texture
/// contract never declares colour tokens; borders and shadows refer to theme
/// colour tokens with [AuroraAlias] instead.
final class AuroraTextureContract {
  factory AuroraTextureContract({
    required String id,
    int version = 1,
    Iterable<AuroraToken<Object>> extensions = const [],
  }) {
    if (id.trim().isEmpty || version < 1) {
      throw ArgumentError(
          'Texture contract needs a nonempty id and a positive version');
    }
    final tokens = <String, AuroraToken<Object>>{};
    for (final token in [...AuroraTextureFoundation.tokens, ...extensions]) {
      final foundation = AuroraTextureFoundation.tokens.contains(token);
      if (!_pathPattern.hasMatch(token.path) ||
          token.description.trim().isEmpty) {
        throw ArgumentError(
            'Token ${token.path} needs a valid dotted path and description');
      }
      if (token is AuroraColorToken) {
        throw ArgumentError('Colour tokens belong to theme contracts; '
            'alias theme colours from texture values instead: ${token.path}');
      }
      if (tokens.containsKey(token.path)) {
        throw ArgumentError('Duplicate or redefined token: ${token.path}');
      }
      if (!foundation &&
          AuroraTextureFoundation.namespaces
              .any((root) => token.path.startsWith('$root.'))) {
        throw ArgumentError(
            'The ${token.path.split('.').first} namespace belongs to Aurora: '
            '${token.path}');
      }
      if (tokens.keys.any((path) =>
          path.startsWith('${token.path}.') ||
          token.path.startsWith('$path.'))) {
        throw ArgumentError('Token/group path collision: ${token.path}');
      }
      if (token is AuroraEnumToken &&
          (token.values.isEmpty ||
              token.values.any((value) => value.trim().isEmpty) ||
              token.values.toSet().length != token.values.length)) {
        throw ArgumentError(
            'Enum token ${token.path} needs unique nonempty values');
      }
      tokens[token.path] = token;
    }
    return AuroraTextureContract._(id, version, Map.unmodifiable(tokens));
  }

  AuroraTextureContract._(this.id, this.version, this.tokens);
  final String id;
  final int version;
  final Map<String, AuroraToken<Object>> tokens;

  bool contains(AuroraToken<Object?> token) =>
      identical(tokens[token.path], token);
}

/// A named, complete, validated set of texture values. A texture has one value
/// set shared by every appearance; its colours alias theme colour tokens and
/// therefore follow the active theme variant.
final class AuroraTexture {
  /// Validates every value against its token type, resolves aliases, and
  /// reports all problems in one [AuroraValidationException].
  ///
  /// Values are the token's value type, an [AuroraLiteral] of it, or an
  /// [AuroraAlias] to another token of the same type in this contract.
  factory AuroraTexture({
    required AuroraTextureContract contract,
    required String id,
    required String name,
    required Map<AuroraToken<Object>, Object> values,
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Texture id and name cannot be empty');
    }
    final resolver = _TextureResolver(contract, values);
    final resolved = resolver.run();
    if (resolver.issues.isNotEmpty) {
      throw AuroraValidationException(resolver.issues);
    }
    return AuroraTexture._(
      contract,
      id,
      name,
      Map.unmodifiable(resolver.authored),
      Map.unmodifiable(resolved),
      Set.unmodifiable(resolver.colorReferences),
    );
  }

  AuroraTexture._(this.contract, this.id, this.name, this._authored,
      this._resolved, this.colorReferences);

  final AuroraTextureContract contract;
  final String id;
  final String name;
  final Map<String, Object> _authored;
  final Map<String, Object> _resolved;

  /// Paths of every theme colour token this texture's values refer to.
  final Set<String> colorReferences;

  /// The resolved value of [token]. Composite colours may still be aliases to
  /// theme colour tokens; resolve those with [AuroraTextureColors.resolveColor].
  T read<T>(AuroraToken<T> token) {
    if (!contract.contains(token)) {
      throw ArgumentError(
          'Token ${token.path} is not in this texture contract');
    }
    return _resolved[token.path] as T;
  }

  /// The value as authored, keeping aliases, for export.
  Object authored(AuroraToken<Object?> token) {
    if (!contract.contains(token)) {
      throw ArgumentError(
          'Token ${token.path} is not in this texture contract');
    }
    return _authored[token.path]!;
  }

  /// [read] for an enum token, mapped to a Dart enum by name.
  E readEnum<E extends Enum>(AuroraEnumToken token, List<E> values) {
    final name = read(token);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw ArgumentError('${token.path} value $name has no matching enum value');
  }

  /// Fails unless every colour this texture refers to is a colour token of
  /// [themeContract]. Runtimes and Flutter scopes call this when pairing
  /// textures with themes.
  void validateColors(AuroraContract themeContract) {
    final missing = colorReferences
        .where((path) => !themeContract.tokens.containsKey(path))
        .map((path) =>
            'Texture $id refers to $path, which theme contract ${themeContract.id} '
            'does not declare')
        .toList();
    if (missing.isNotEmpty) throw AuroraValidationException(missing);
  }
}

/// Resolve a texture colour (a literal or a theme colour alias) against a
/// concrete theme variant.
extension AuroraTextureColors on AuroraThemeVariant {
  AuroraColor resolveColor(AuroraRef<AuroraColor> color) => switch (color) {
        AuroraColor() => color,
        AuroraLiteral<AuroraColor>(:final value) => value,
        AuroraAlias<AuroraColor>(:final target) => read(contract
                .tokens[target.path] ??
            (throw ArgumentError(
                'Theme contract ${contract.id} has no colour ${target.path}'))),
        _ => throw ArgumentError('Unsupported colour reference $color'),
      };
}

/// DTCG writes dp as px with a token-level marker, so one token cannot hold
/// both units.
bool _mixesPixelUnits(Object value) {
  final units = <AuroraDimensionUnit>{};
  void add(AuroraRef<Object?> ref) {
    if (ref is AuroraDimension) units.add(ref.unit);
    if (ref is AuroraStrokeStyle) ref.dashArrayRefs?.forEach(add);
  }

  switch (value) {
    case AuroraStrokeStyle():
      add(value);
    case AuroraBorder():
      add(value.widthRef);
      add(value.styleRef);
    case AuroraShadow():
      for (final layer in value.layers) {
        add(layer.offsetXRef);
        add(layer.offsetYRef);
        add(layer.blurRef);
        add(layer.spreadRef);
      }
    case AuroraTypography():
      add(value.fontSizeRef);
      add(value.letterSpacingRef);
  }
  return units.contains(AuroraDimensionUnit.dp) &&
      units.contains(AuroraDimensionUnit.px);
}

final class _TextureResolver {
  _TextureResolver(this.contract, Map<AuroraToken<Object>, Object> values) {
    for (final entry in values.entries) {
      final token = entry.key;
      if (!contract.contains(token)) {
        issues.add('Undeclared token ${token.path}');
        continue;
      }
      var value = entry.value;
      if (value is AuroraLiteral) value = value.value as Object;
      if (token is AuroraNumberToken && value is num) value = value.toDouble();
      authored[token.path] = value;
    }
    for (final token in contract.tokens.values) {
      if (!authored.containsKey(token.path)) {
        issues.add('Missing required token ${token.path}');
      }
    }
  }

  final AuroraTextureContract contract;
  final authored = <String, Object>{};
  final issues = <String>[];
  final colorReferences = <String>{};
  final _resolved = <String, Object?>{};
  final _visiting = <String>{};

  Map<String, Object> run() {
    for (final token in contract.tokens.values) {
      if (authored.containsKey(token.path)) _resolve(token);
    }
    return {
      for (final entry in _resolved.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Object? _resolve(AuroraToken<Object?> token) {
    if (_resolved.containsKey(token.path)) return _resolved[token.path];
    if (!_visiting.add(token.path)) {
      issues.add('Cyclic token alias at ${token.path}');
      return null;
    }
    final value = authored[token.path];
    Object? result;
    if (value == null) {
      result = null;
    } else if (value is AuroraAlias) {
      result = _aliasTarget(token, value.target, token.path);
    } else {
      result = _literal(token, value);
      if (result != null && _mixesPixelUnits(value)) {
        issues
            .add('${token.path} mixes dp and px; use one pixel unit per token');
        result = null;
      }
    }
    if (result != null && token is AuroraEnumToken) {
      if (!token.values.contains(result)) {
        issues.add('${token.path} must be one of ${token.values.join(', ')}');
        result = null;
      }
    }
    _visiting.remove(token.path);
    return _resolved[token.path] = result;
  }

  Object? _aliasTarget(
      AuroraToken<Object?> expected, AuroraToken<Object?> target, String at) {
    if (!contract.contains(target)) {
      issues.add('$at aliases undeclared token ${target.path}');
      return null;
    }
    if (target.runtimeType != expected.runtimeType) {
      issues.add('$at must alias a ${expected.type} token, '
          'not ${target.type} ${target.path}');
      return null;
    }
    return _resolve(target);
  }

  Object? _literal(AuroraToken<Object?> token, Object value) {
    final at = token.path;
    switch (token) {
      case AuroraColorToken():
        issues.add('$at: colour tokens belong to theme contracts');
        return null;
      case AuroraDimensionToken():
        return value is AuroraDimension
            ? _dimension(value, at)
            : _wrongType(at, 'an AuroraDimension');
      case AuroraNumberToken():
        if (value is! double) return _wrongType(at, 'a number');
        return _finite(value, at);
      case AuroraFontFamilyToken():
        return value is AuroraFontFamily
            ? _family(value, at)
            : _wrongType(at, 'an AuroraFontFamily');
      case AuroraFontWeightToken():
        return value is AuroraFontWeight
            ? _weight(value, at)
            : _wrongType(at, 'an AuroraFontWeight');
      case AuroraDurationToken():
        if (value is! Duration) return _wrongType(at, 'a Duration');
        if (value.isNegative) {
          issues.add('$at must not be negative');
          return null;
        }
        return value;
      case AuroraCubicBezierToken():
        return value is AuroraCubicBezier
            ? _bezier(value, at)
            : _wrongType(at, 'an AuroraCubicBezier');
      case AuroraStrokeStyleToken():
        return value is AuroraStrokeStyle
            ? _stroke(value, at)
            : _wrongType(at, 'an AuroraStrokeStyle');
      case AuroraBorderToken():
        return value is AuroraBorder
            ? _border(value, at)
            : _wrongType(at, 'an AuroraBorder');
      case AuroraShadowToken():
        return value is AuroraShadow
            ? _shadow(value, at)
            : _wrongType(at, 'an AuroraShadow');
      case AuroraTypographyToken():
        return value is AuroraTypography
            ? _typography(value, at)
            : _wrongType(at, 'an AuroraTypography');
      case AuroraBooleanToken():
        return value is bool ? value : _wrongType(at, 'a bool');
      case AuroraEnumToken():
        return value is String ? value : _wrongType(at, 'a String');
    }
  }

  Null _wrongType(String at, String expected) {
    issues.add('$at must be $expected');
    return null;
  }

  double? _finite(double value, String at) {
    if (value.isFinite) return value;
    issues.add('$at must be finite');
    return null;
  }

  /// Resolves a composite field: a literal, or an alias to a contract token.
  X? _field<X extends Object>(AuroraRef<X> ref, String at,
      AuroraToken<Object?> kind, X? Function(X value, String at) check) {
    if (ref is AuroraAlias<X>) {
      return _aliasTarget(kind, ref.target, at) as X?;
    }
    final value = ref is AuroraLiteral<X> ? ref.value : ref as X;
    return check(value, at);
  }

  AuroraDimension? _dimensionField(AuroraRef<AuroraDimension> ref, String at,
          {bool nonNegative = false}) =>
      _field(ref, at, const AuroraDimensionToken('_', description: '_'),
          (value, at) {
        final dimension = _dimension(value, at);
        if (dimension != null && nonNegative && dimension.value < 0) {
          issues.add('$at must not be negative');
          return null;
        }
        return dimension;
      });

  AuroraDimension? _dimension(AuroraDimension value, String at) {
    if (value.value.isFinite) return value;
    issues.add('$at must be finite');
    return null;
  }

  AuroraFontFamily? _family(AuroraFontFamily value, String at) {
    if (value.names.isEmpty || value.names.any((n) => n.trim().isEmpty)) {
      issues.add('$at needs at least one nonempty font family name');
      return null;
    }
    return value;
  }

  AuroraFontWeight? _weight(AuroraFontWeight value, String at) {
    if (value.value < 1 || value.value > 1000) {
      issues.add('$at must be a font weight in [1, 1000]');
      return null;
    }
    return value;
  }

  AuroraCubicBezier? _bezier(AuroraCubicBezier value, String at) {
    final points = [value.x1, value.y1, value.x2, value.y2];
    if (points.any((p) => !p.isFinite) ||
        value.x1 < 0 ||
        value.x1 > 1 ||
        value.x2 < 0 ||
        value.x2 > 1) {
      issues.add('$at needs finite control points with x in [0, 1]');
      return null;
    }
    return value;
  }

  AuroraStrokeStyle? _stroke(AuroraStrokeStyle value, String at) {
    final dashes = value.dashArrayRefs;
    if (dashes == null) return value;
    if (dashes.isEmpty) {
      issues.add('$at needs at least one dash length');
      return null;
    }
    if (dashes.every((dash) => dash is AuroraDimension && dash.value == 0)) {
      issues.add('$at draws nothing; use AuroraStrokeStyle.none');
      return null;
    }
    final resolved = [
      for (var i = 0; i < dashes.length; i++)
        _dimensionField(dashes[i], '$at.dashArray[$i]', nonNegative: true),
    ];
    if (resolved.contains(null)) return null;
    return AuroraStrokeStyle.dashes(
        dashArray: resolved.cast<AuroraDimension>(), lineCap: value.lineCap!);
  }

  AuroraRef<AuroraColor>? _color(AuroraRef<AuroraColor> ref, String at) {
    switch (ref) {
      case AuroraColor():
        return ref;
      case AuroraLiteral<AuroraColor>(:final value):
        return value;
      case AuroraAlias<AuroraColor>(:final target):
        if (target is! AuroraColorToken) {
          issues.add('$at must alias a theme colour token');
          return null;
        }
        if (target.path.startsWith('colors.') &&
            !AuroraFoundation.tokens.any((t) => t.path == target.path)) {
          issues.add('$at refers to unknown foundation colour ${target.path}');
          return null;
        }
        colorReferences.add(target.path);
        return ref;
      default:
        issues.add('$at must be a colour or a theme colour alias');
        return null;
    }
  }

  AuroraBorder? _border(AuroraBorder value, String at) {
    final color = _color(value.color, '$at.color');
    final width =
        _dimensionField(value.widthRef, '$at.width', nonNegative: true);
    final style = _field(value.styleRef, '$at.style',
        const AuroraStrokeStyleToken('_', description: '_'), _stroke);
    if (color == null || width == null || style == null) return null;
    return AuroraBorder(color: color, width: width, style: style);
  }

  AuroraShadow? _shadow(AuroraShadow value, String at) {
    final layers = <AuroraShadowLayer>[];
    var valid = true;
    for (var i = 0; i < value.layers.length; i++) {
      final layer = value.layers[i];
      final where = '$at[$i]';
      final color = _color(layer.color, '$where.color');
      final x = _dimensionField(layer.offsetXRef, '$where.offsetX');
      final y = _dimensionField(layer.offsetYRef, '$where.offsetY');
      final blur =
          _dimensionField(layer.blurRef, '$where.blur', nonNegative: true);
      final spread = _dimensionField(layer.spreadRef, '$where.spread');
      if (color == null ||
          x == null ||
          y == null ||
          blur == null ||
          spread == null) {
        valid = false;
        continue;
      }
      layers.add(AuroraShadowLayer(
          color: color,
          offsetX: x,
          offsetY: y,
          blur: blur,
          spread: spread,
          inset: layer.inset));
    }
    return valid ? AuroraShadow(layers) : null;
  }

  AuroraTypography? _typography(AuroraTypography value, String at) {
    final family = _field(value.fontFamilyRef, '$at.fontFamily',
        const AuroraFontFamilyToken('_', description: '_'), _family);
    final size = _field(value.fontSizeRef, '$at.fontSize',
        const AuroraDimensionToken('_', description: '_'), (value, at) {
      final size = _dimension(value, at);
      if (size != null && size.value <= 0) {
        issues.add('$at must be positive');
        return null;
      }
      return size;
    });
    final weight = _field(value.fontWeightRef, '$at.fontWeight',
        const AuroraFontWeightToken('_', description: '_'), _weight);
    final spacing =
        _dimensionField(value.letterSpacingRef, '$at.letterSpacing');
    final height = _field<double>(value.lineHeightRef, '$at.lineHeight',
        const AuroraNumberToken('_', description: '_'), (value, at) {
      if (!value.isFinite || value <= 0) {
        issues.add('$at must be a positive finite number');
        return null;
      }
      return value;
    });
    if (family == null ||
        size == null ||
        weight == null ||
        spacing == null ||
        height == null) {
      return null;
    }
    return AuroraTypography(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        lineHeight: AuroraLiteral(height));
  }
}
