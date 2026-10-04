import 'contract.dart';
import 'texture.dart';
import 'texture_codec.dart';

/// DTCG 2025.10 profile for textures: one document holds one complete texture.
///
/// Every DTCG token type Aurora supports is written with its standard `$type`.
/// Booleans and enums, which DTCG lacks, have no `$type` and are marked with
/// `$extensions["dev.aurora"]` (`{"type": "boolean"}` or
/// `{"type": "enum", "values": [...]}`). Dimensions in dp are written as `px`
/// with `{"unit": "dp"}` in the same extension. Aliases are kept as
/// `{path}` references. References to theme colour tokens (for example
/// `{colors.outline}`) are resolved against the active theme, not this
/// document. Texture identity lives outside the document.
abstract final class AuroraTextureDtcg {
  static const extensionKey = 'dev.aurora';

  static Map<String, Object?> encode(AuroraTexture texture) {
    final codec = TextureCodec(texture.contract, recipe: false);
    final document = <String, Object?>{};
    for (final token in texture.contract.tokens.values) {
      var group = document;
      final parts = token.path.split('.');
      for (final part in parts.take(parts.length - 1)) {
        group = group.putIfAbsent(part, () => <String, Object?>{})
            as Map<String, Object?>;
      }
      final authored = texture.authored(token);
      final extension = <String, Object?>{
        if (token is AuroraBooleanToken) 'type': 'boolean',
        if (token is AuroraEnumToken) ...{
          'type': 'enum',
          'values': token.values
        },
        if (TextureCodec.usesDp(authored)) 'unit': 'dp',
      };
      group[parts.last] = <String, Object?>{
        if (token is! AuroraBooleanToken && token is! AuroraEnumToken)
          r'$type': token.type,
        r'$description': token.description,
        r'$value': codec.encode(authored),
        if (extension.isNotEmpty) r'$extensions': {extensionKey: extension},
      };
    }
    return document;
  }

  static AuroraTexture decode(
    Map<String, Object?> document, {
    required AuroraTextureContract contract,
    required String id,
    required String name,
  }) {
    final raw = <String,
        ({Object? value, Object? type, Map<String, Object?> aurora})>{};
    void visit(Map<String, Object?> node, String path, Object? inheritedType) {
      for (final key in node.keys.where((key) => key.startsWith(r'$'))) {
        if (!{
          r'$type',
          r'$value',
          r'$description',
          r'$extensions',
          r'$deprecated'
        }.contains(key)) {
          throw FormatException('Unsupported DTCG property $key at $path');
        }
      }
      if (node.containsKey(r'$type') && node[r'$type'] is! String) {
        throw FormatException('Invalid token type at $path');
      }
      if (node.containsKey(r'$description') &&
          node[r'$description'] is! String) {
        throw FormatException('Invalid description at $path');
      }
      final extensions = node[r'$extensions'];
      if (extensions != null && extensions is! Map<String, Object?>) {
        throw FormatException('Invalid extensions metadata at $path');
      }
      final aurora = (extensions as Map<String, Object?>?)?[extensionKey];
      if (aurora != null && aurora is! Map<String, Object?>) {
        throw FormatException('Invalid $extensionKey metadata at $path');
      }
      final type = node[r'$type'] ?? inheritedType;
      if (node.containsKey(r'$value')) {
        if (path.isEmpty || node.keys.any((key) => !key.startsWith(r'$'))) {
          throw FormatException('Invalid token/group structure at $path');
        }
        raw[path] = (
          value: node[r'$value'],
          type: type,
          aurora: (aurora as Map<String, Object?>?) ?? const {},
        );
        return;
      }
      for (final entry
          in node.entries.where((entry) => !entry.key.startsWith(r'$'))) {
        if (entry.key.contains('.') || entry.value is! Map<String, Object?>) {
          throw FormatException(
              'Expected a named group or token at $path.${entry.key}');
        }
        visit(entry.value as Map<String, Object?>,
            path.isEmpty ? entry.key : '$path.${entry.key}', type);
      }
    }

    visit(document, '', null);
    final issues = <String>[
      for (final path in contract.tokens.keys)
        if (!raw.containsKey(path)) 'Missing required token $path',
      for (final path in raw.keys)
        if (!contract.tokens.containsKey(path)) 'Undeclared token $path',
    ];
    if (issues.isNotEmpty) throw AuroraValidationException(issues);

    final codec = TextureCodec(contract, recipe: false);
    final values = <AuroraToken<Object>, Object>{};
    for (final token in contract.tokens.values) {
      final entry = raw[token.path]!;
      final aurora = entry.aurora;
      final unknown =
          aurora.keys.where((key) => !{'type', 'values', 'unit'}.contains(key));
      if (unknown.isNotEmpty) {
        throw FormatException(
            'Unsupported $extensionKey fields at ${token.path}: ${unknown.join(', ')}');
      }
      final isAlias =
          entry.value is String && (entry.value as String).startsWith('{');
      if (token is AuroraBooleanToken || token is AuroraEnumToken) {
        if (entry.type != null || aurora['type'] != token.type) {
          throw FormatException('${token.path} must be marked with '
              '$extensionKey type ${token.type} and no \$type');
        }
        if (token is AuroraEnumToken) {
          final declared = aurora['values'];
          if (declared is! List ||
              declared.length != token.values.length ||
              !token.values.every(declared.contains)) {
            throw FormatException(
                '${token.path} records allowed values that differ from the contract');
          }
        }
      } else if (entry.type != token.type && !(isAlias && entry.type == null)) {
        throw FormatException(
            '${token.path} must have type ${token.type}, not ${entry.type}');
      }
      if (aurora.containsKey('unit') && aurora['unit'] != 'dp') {
        throw FormatException(
            'Unsupported $extensionKey unit at ${token.path}');
      }
      values[token] = codec.decode(token, entry.value, token.path,
          pxIsDp: aurora['unit'] == 'dp');
    }
    return AuroraTexture(
        contract: contract, id: id, name: name, values: values);
  }
}
