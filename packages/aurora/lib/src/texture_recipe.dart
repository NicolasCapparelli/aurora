import 'texture.dart';
import 'texture_codec.dart';
import 'texture_foundation.dart';
import 'token.dart';

/// Portable texture recipe v1: a JSON description of one texture. See
/// `spec/texture-recipe-v1.md`. Theme recipes are unchanged.
abstract final class AuroraTextureRecipe {
  static const _types = {
    'dimension',
    'number',
    'fontFamily',
    'fontWeight',
    'duration',
    'cubicBezier',
    'strokeStyle',
    'border',
    'shadow',
    'typography',
    'boolean',
    'enum',
  };

  /// Decodes a texture. Pass the app's [contract] so several recipes share one
  /// contract instance (required by runtimes); the recipe's `contract` must
  /// then describe exactly that contract. Without it, the recipe's contract
  /// is built fresh.
  static AuroraTexture decode(Map<String, dynamic> input,
      {AuroraTextureContract? contract}) {
    _fields(
        input,
        {'schemaVersion', 'kind', 'id', 'name', 'base', 'contract', 'values'},
        'texture recipe');
    if (input['schemaVersion'] != 1) {
      throw const FormatException('Expected texture recipe schemaVersion 1');
    }
    if (input['kind'] != 'texture') {
      throw const FormatException('Expected texture recipe kind "texture"');
    }
    final declared = decodeContract(_map(
        input['contract'] ?? {'id': 'aurora-texture-foundation'}, 'contract'));
    if (contract != null && !_sameShape(contract, declared)) {
      throw FormatException(
          'Recipe contract does not match texture contract ${contract.id}');
    }
    final target = contract ?? declared;
    final base = input['base'] ?? 'material';
    if (base != 'material' && base != 'none') {
      throw const FormatException('base must be "material" or "none"');
    }
    final codec = TextureCodec(target, recipe: true);
    final values = <AuroraToken<Object>, Object>{
      if (base == 'material') ...AuroraTextureStarter.material,
    };
    for (final entry in _map(input['values'] ?? {}, 'values').entries) {
      final token = target.tokens[entry.key] ??
          (throw FormatException('Undeclared token ${entry.key}'));
      values[token] = codec.decode(token, entry.value, entry.key);
    }
    return AuroraTexture(
        contract: target,
        id: _text(input['id'], 'id'),
        name: _text(input['name'], 'name'),
        values: values);
  }

  /// The recipe JSON for a texture value, such as a value read from a texture.
  /// Dimensions keep their unit, including `dp`.
  static Object encodeValue(Object value) =>
      TextureCodec(null, recipe: true).encode(value);

  /// Decodes a recipe `contract` object into a texture contract.
  static AuroraTextureContract decodeContract(Map<String, dynamic> definition) {
    _fields(definition, {'id', 'version', 'extensions'}, 'contract');
    final version = definition['version'] ?? 1;
    if (version is! int) {
      throw const FormatException('Contract version must be an integer');
    }
    final extensions = <AuroraToken<Object>>[];
    for (final item in _list(definition['extensions'] ?? [], 'extensions')) {
      final token = _map(item, 'extension');
      final type = _text(token['type'], 'extension type');
      _fields(
          token,
          {'path', 'description', 'type', if (type == 'enum') 'values'},
          'extension');
      if (!_types.contains(type)) {
        throw FormatException('Unsupported texture token type $type');
      }
      final path = _text(token['path'], 'path');
      final description = _text(token['description'], 'description');
      extensions.add(switch (type) {
        'dimension' => AuroraDimensionToken(path, description: description),
        'number' => AuroraNumberToken(path, description: description),
        'fontFamily' => AuroraFontFamilyToken(path, description: description),
        'fontWeight' => AuroraFontWeightToken(path, description: description),
        'duration' => AuroraDurationToken(path, description: description),
        'cubicBezier' => AuroraCubicBezierToken(path, description: description),
        'strokeStyle' => AuroraStrokeStyleToken(path, description: description),
        'border' => AuroraBorderToken(path, description: description),
        'shadow' => AuroraShadowToken(path, description: description),
        'typography' => AuroraTypographyToken(path, description: description),
        'boolean' => AuroraBooleanToken(path, description: description),
        _ => AuroraEnumToken(path, description: description, values: [
            for (final value in _list(token['values'], 'values'))
              _text(value, 'enum value')
          ]),
      });
    }
    return AuroraTextureContract(
        id: _text(definition['id'], 'contract.id'),
        version: version,
        extensions: extensions);
  }

  static bool _sameShape(AuroraTextureContract a, AuroraTextureContract b) {
    if (a.id != b.id || a.version != b.version) return false;
    if (a.tokens.length != b.tokens.length) return false;
    for (final token in a.tokens.values) {
      final other = b.tokens[token.path];
      if (other == null || other.runtimeType != token.runtimeType) return false;
      if (token is AuroraEnumToken &&
          (token.values.join('\n') !=
              (other as AuroraEnumToken).values.join('\n'))) {
        return false;
      }
    }
    return true;
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$field must be an object');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be an array');
    return value;
  }

  static String _text(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a nonempty string');
    }
    return value.trim();
  }

  static void _fields(
      Map<String, dynamic> value, Set<String> allowed, String field) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown $field fields: ${unknown.join(', ')}');
    }
  }
}
